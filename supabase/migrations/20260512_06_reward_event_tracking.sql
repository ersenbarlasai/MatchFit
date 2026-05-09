-- Reward Interaction Event Tracking
-- Date: 2026-05-12
-- Description: Logs impression, view, click and redeem_start events for rewards.

-- ── 1. Table ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.reward_interaction_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reward_id UUID REFERENCES public.reward_catalog(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    source TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    idempotency_key TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_rie_reward_id ON public.reward_interaction_events (reward_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rie_partner_id ON public.reward_interaction_events (partner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rie_user_id ON public.reward_interaction_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rie_event_type ON public.reward_interaction_events (event_type, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_rie_idempotency ON public.reward_interaction_events (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- RLS
ALTER TABLE public.reward_interaction_events ENABLE ROW LEVEL SECURITY;

-- No client reads or writes; all via RPC
CREATE POLICY "no_client_write_reward_events" ON public.reward_interaction_events
    AS RESTRICTIVE FOR ALL USING (false);


-- ── 2. Log Event RPC ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.log_reward_interaction_event(
    p_reward_id UUID,
    p_event_type TEXT,
    p_source TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_event_id UUID;
    v_partner_id UUID;
    v_allowed_types TEXT[] := ARRAY['impression', 'view', 'click', 'redeem_start'];
BEGIN
    -- Auth check
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Event type whitelist
    IF NOT (p_event_type = ANY(v_allowed_types)) THEN
        RAISE EXCEPTION 'Invalid event_type: %. Allowed: impression, view, click, redeem_start', p_event_type;
    END IF;

    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_event_id
        FROM public.reward_interaction_events
        WHERE idempotency_key = p_idempotency_key;
        
        IF v_event_id IS NOT NULL THEN
            RETURN v_event_id;
        END IF;
    END IF;

    -- Validate reward exists and get partner_id
    SELECT partner_id INTO v_partner_id
    FROM public.reward_catalog
    WHERE id = p_reward_id;

    IF v_partner_id IS NULL THEN
        RAISE EXCEPTION 'Reward not found: %', p_reward_id;
    END IF;

    -- Insert event
    INSERT INTO public.reward_interaction_events (
        user_id, reward_id, partner_id, event_type, source, metadata, idempotency_key
    ) VALUES (
        auth.uid(), p_reward_id, v_partner_id, p_event_type, p_source, p_metadata, p_idempotency_key
    )
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$;


-- ── 3. Update Admin KPI Summary ───────────────────────────────────────────────
-- Replace the existing function to include interaction metrics.

CREATE OR REPLACE FUNCTION public.get_partner_admin_kpi_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_partners INTEGER;
    v_active_partners INTEGER;
    v_total_rewards INTEGER;
    v_active_rewards INTEGER;
    v_low_stock_rewards INTEGER;
    v_total_redemptions INTEGER;
    v_approved_redemptions INTEGER;
    v_rejected_redemptions INTEGER;
    v_total_points_spent INTEGER;
    v_total_impressions BIGINT;
    v_total_views BIGINT;
    v_total_clicks BIGINT;
    v_average_ctr NUMERIC;
    v_top_rewards JSONB;
BEGIN
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'active')
    INTO v_total_partners, v_active_partners
    FROM public.partners;

    SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'active')
    INTO v_total_rewards, v_active_rewards
    FROM public.reward_catalog;

    SELECT COUNT(*)
    INTO v_low_stock_rewards
    FROM public.reward_inventory
    WHERE is_unlimited = false AND stock_remaining <= 5;

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status IN ('approved', 'completed')),
        COUNT(*) FILTER (WHERE status IN ('rejected', 'failed')),
        COALESCE(SUM(cost_points) FILTER (WHERE status IN ('approved', 'completed')), 0)
    INTO 
        v_total_redemptions,
        v_approved_redemptions,
        v_rejected_redemptions,
        v_total_points_spent
    FROM public.redemption_attempts;

    -- Interaction metrics
    SELECT
        COUNT(*) FILTER (WHERE event_type = 'impression'),
        COUNT(*) FILTER (WHERE event_type = 'view'),
        COUNT(*) FILTER (WHERE event_type = 'click')
    INTO v_total_impressions, v_total_views, v_total_clicks
    FROM public.reward_interaction_events;

    -- CTR = clicks / impressions
    v_average_ctr := ROUND(
        (v_total_clicks::NUMERIC / NULLIF(v_total_impressions, 0)) * 100, 2
    );

    -- Top Rewards with interaction metrics
    SELECT COALESCE(jsonb_agg(row_to_json(tr)), '[]'::jsonb)
    INTO v_top_rewards
    FROM (
        SELECT 
            rc.id AS reward_id,
            rc.name AS reward_name,
            p.name AS partner_name,
            rc.status,
            ri.stock_remaining,
            COUNT(ra.id) AS redemption_count,
            COUNT(DISTINCT rie_imp.id) AS impression_count,
            COUNT(DISTINCT rie_view.id) AS view_count,
            COUNT(DISTINCT rie_click.id) AS click_count,
            ROUND(
                (COUNT(DISTINCT ra.id)::NUMERIC / NULLIF(COUNT(DISTINCT rie_view.id), 0)) * 100,
                2
            ) AS conversion_rate
        FROM public.reward_catalog rc
        JOIN public.partners p ON rc.partner_id = p.id
        LEFT JOIN public.reward_inventory ri ON rc.id = ri.reward_id
        LEFT JOIN public.redemption_attempts ra ON rc.id = ra.reward_id AND ra.status IN ('approved', 'completed')
        LEFT JOIN public.reward_interaction_events rie_imp ON rc.id = rie_imp.reward_id AND rie_imp.event_type = 'impression'
        LEFT JOIN public.reward_interaction_events rie_view ON rc.id = rie_view.reward_id AND rie_view.event_type = 'view'
        LEFT JOIN public.reward_interaction_events rie_click ON rc.id = rie_click.reward_id AND rie_click.event_type = 'click'
        GROUP BY rc.id, rc.name, p.name, rc.status, ri.stock_remaining
        ORDER BY redemption_count DESC, view_count DESC
        LIMIT 10
    ) tr;

    RETURN jsonb_build_object(
        'total_partners', v_total_partners,
        'active_partners', v_active_partners,
        'total_rewards', v_total_rewards,
        'active_rewards', v_active_rewards,
        'low_stock_rewards', v_low_stock_rewards,
        'total_redemptions', v_total_redemptions,
        'approved_redemptions', v_approved_redemptions,
        'rejected_redemptions', v_rejected_redemptions,
        'total_points_spent', v_total_points_spent,
        'total_impressions', v_total_impressions,
        'total_views', v_total_views,
        'total_clicks', v_total_clicks,
        'average_ctr', COALESCE(v_average_ctr, 0),
        'top_rewards', v_top_rewards
    );
END;
$$;
