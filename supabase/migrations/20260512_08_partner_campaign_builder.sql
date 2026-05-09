-- Partner Campaign Builder MVP
-- Date: 2026-05-12
-- Description: Partner campaigns table, reward integration, and RPC-driven workflow.

-- ── 1. Tables & Schema Drift ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.partner_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID REFERENCES public.partners(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    campaign_type TEXT DEFAULT 'standard',
    status TEXT DEFAULT 'draft',
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    budget_amount NUMERIC,
    billing_model TEXT,
    target_city TEXT,
    sport_tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pc_partner_id ON public.partner_campaigns (partner_id);
CREATE INDEX IF NOT EXISTS idx_pc_status ON public.partner_campaigns (status);
CREATE INDEX IF NOT EXISTS idx_pc_dates ON public.partner_campaigns (starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_pc_sport_tags ON public.partner_campaigns USING GIN (sport_tags);

-- RLS
ALTER TABLE public.partner_campaigns ENABLE ROW LEVEL SECURITY;

-- No client reads or writes; all via RPC
CREATE POLICY "no_client_access_campaigns" ON public.partner_campaigns
    AS RESTRICTIVE FOR ALL USING (false);

-- Update reward_catalog to support campaigns
ALTER TABLE public.reward_catalog 
ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES public.partner_campaigns(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_rc_campaign_id ON public.reward_catalog (campaign_id);


-- ── 2. RPC: Upsert Campaign ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.upsert_partner_campaign_admin(
    p_campaign_id UUID DEFAULT NULL,
    p_partner_id UUID DEFAULT NULL,
    p_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_campaign_type TEXT DEFAULT 'standard',
    p_status TEXT DEFAULT 'draft',
    p_starts_at TIMESTAMPTZ DEFAULT NULL,
    p_ends_at TIMESTAMPTZ DEFAULT NULL,
    p_budget_amount NUMERIC DEFAULT NULL,
    p_billing_model TEXT DEFAULT NULL,
    p_target_city TEXT DEFAULT NULL,
    p_sport_tags TEXT[] DEFAULT '{}',
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_campaign_id UUID;
    v_allowed_types TEXT[] := ARRAY['standard', 'launch', 'seasonal', 'reactivation', 'city_exclusive', 'performance'];
    v_allowed_statuses TEXT[] := ARRAY['draft', 'active', 'paused', 'completed', 'archived'];
BEGIN
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    IF p_campaign_type IS NOT NULL AND NOT (p_campaign_type = ANY(v_allowed_types)) THEN
        RAISE EXCEPTION 'Invalid campaign_type: %', p_campaign_type;
    END IF;

    IF p_status IS NOT NULL AND NOT (p_status = ANY(v_allowed_statuses)) THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    IF p_campaign_id IS NULL THEN
        -- Insert
        IF p_partner_id IS NULL OR p_name IS NULL THEN
            RAISE EXCEPTION 'partner_id and name are required for new campaigns.';
        END IF;

        INSERT INTO public.partner_campaigns (
            partner_id, name, description, campaign_type, status,
            starts_at, ends_at, budget_amount, billing_model,
            target_city, sport_tags, metadata, created_by
        ) VALUES (
            p_partner_id, p_name, p_description, p_campaign_type, p_status,
            p_starts_at, p_ends_at, p_budget_amount, p_billing_model,
            p_target_city, p_sport_tags, p_metadata, auth.uid()
        )
        RETURNING id INTO v_campaign_id;
    ELSE
        -- Update
        UPDATE public.partner_campaigns SET
            name = COALESCE(p_name, name),
            description = COALESCE(p_description, description),
            campaign_type = COALESCE(p_campaign_type, campaign_type),
            status = COALESCE(p_status, status),
            starts_at = p_starts_at,
            ends_at = p_ends_at,
            budget_amount = p_budget_amount,
            billing_model = p_billing_model,
            target_city = p_target_city,
            sport_tags = COALESCE(p_sport_tags, sport_tags),
            metadata = COALESCE(p_metadata, metadata),
            updated_at = now()
        WHERE id = p_campaign_id
        RETURNING id INTO v_campaign_id;

        IF v_campaign_id IS NULL THEN
            RAISE EXCEPTION 'Campaign not found: %', p_campaign_id;
        END IF;
    END IF;

    RETURN v_campaign_id;
END;
$$;


-- ── 3. RPC: List Campaigns ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_partner_campaign_admin_list(
    p_partner_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    partner_id UUID,
    partner_name TEXT,
    name TEXT,
    campaign_type TEXT,
    status TEXT,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    reward_count BIGINT,
    active_reward_count BIGINT,
    redemption_count BIGINT,
    total_points_spent NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    RETURN QUERY
    SELECT 
        pc.id,
        pc.partner_id,
        p.name as partner_name,
        pc.name,
        pc.campaign_type,
        pc.status,
        pc.starts_at,
        pc.ends_at,
        COUNT(DISTINCT rc.id) as reward_count,
        COUNT(DISTINCT rc.id) FILTER (WHERE rc.status = 'active') as active_reward_count,
        COUNT(DISTINCT ra.id) as redemption_count,
        COALESCE(SUM(ra.cost_points) FILTER (WHERE ra.status IN ('approved', 'completed')), 0)::NUMERIC as total_points_spent
    FROM public.partner_campaigns pc
    JOIN public.partners p ON pc.partner_id = p.id
    LEFT JOIN public.reward_catalog rc ON pc.id = rc.campaign_id
    LEFT JOIN public.redemption_attempts ra ON rc.id = ra.reward_id
    WHERE p_partner_id IS NULL OR pc.partner_id = p_partner_id
    GROUP BY pc.id, p.name
    ORDER BY pc.created_at DESC;
END;
$$;


-- ── 4. RPC: Attach Reward to Campaign ────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.attach_reward_to_campaign_admin(
    p_reward_id UUID,
    p_campaign_id UUID DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reward_partner_id UUID;
    v_campaign_partner_id UUID;
BEGIN
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    -- Validate reward
    SELECT partner_id INTO v_reward_partner_id FROM public.reward_catalog WHERE id = p_reward_id;
    IF v_reward_partner_id IS NULL THEN
        RAISE EXCEPTION 'Reward not found: %', p_reward_id;
    END IF;

    -- Validate campaign if provided
    IF p_campaign_id IS NOT NULL THEN
        SELECT partner_id INTO v_campaign_partner_id FROM public.partner_campaigns WHERE id = p_campaign_id;
        IF v_campaign_partner_id IS NULL THEN
            RAISE EXCEPTION 'Campaign not found: %', p_campaign_id;
        END IF;

        IF v_reward_partner_id != v_campaign_partner_id THEN
            RAISE EXCEPTION 'Reward and Campaign must belong to the same partner.';
        END IF;
    END IF;

    UPDATE public.reward_catalog 
    SET campaign_id = p_campaign_id 
    WHERE id = p_reward_id;
END;
$$;


-- ── 5. Update get_active_rewards with Campaign Gating ───────────────────────

DROP FUNCTION IF EXISTS public.get_active_rewards(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.get_active_rewards(
    p_city TEXT DEFAULT NULL,
    p_sport_tag TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    partner_id UUID,
    partner_name TEXT,
    name TEXT,
    description TEXT,
    short_description TEXT,
    image_url TEXT,
    cost_points INTEGER,
    is_free BOOLEAN,
    status TEXT,
    stock_remaining INTEGER,
    is_unlimited BOOLEAN,
    campaign_id UUID,
    campaign_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rc.id,
        rc.partner_id,
        p.name AS partner_name,
        rc.name,
        rc.description,
        rc.short_description,
        rc.image_url,
        rc.cost_points,
        rc.is_free,
        rc.status,
        ri.stock_remaining,
        ri.is_unlimited,
        rc.campaign_id,
        pc.name AS campaign_name
    FROM public.reward_catalog rc
    JOIN public.partners p ON rc.partner_id = p.id
    LEFT JOIN public.reward_inventory ri ON rc.id = ri.reward_id
    LEFT JOIN public.partner_campaigns pc ON rc.campaign_id = pc.id
    WHERE 
        rc.status = 'active'
        AND p.status = 'active'
        -- Campaign Gating
        AND (
            rc.campaign_id IS NULL 
            OR (
                pc.status = 'active'
                AND (pc.starts_at IS NULL OR pc.starts_at <= now())
                AND (pc.ends_at IS NULL OR pc.ends_at >= now())
            )
        )
        -- Filters
        AND (p_city IS NULL OR p.city = p_city OR pc.target_city = p_city)
        AND (p_sport_tag IS NULL OR p_sport_tag = ANY(rc.tags) OR p_sport_tag = ANY(pc.sport_tags))
    ORDER BY rc.created_at DESC;
END;
$$;
