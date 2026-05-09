-- Partner Catalog Hotfixes
-- Date: 2026-05-12
-- Description: Resolves RPC ambiguity for get_active_rewards and adds missing get_my_redemption_history.

-- 1. Resolve get_active_rewards ambiguity
-- The error "Could not choose the best candidate function" happens when multiple signatures exist.
-- We explicitly drop all potential overloads to ensure a clean state.
DROP FUNCTION IF EXISTS public.get_active_rewards(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.get_active_rewards(TEXT, UUID);
DROP FUNCTION IF EXISTS public.get_active_rewards(p_city TEXT, p_sport_tag TEXT);
DROP FUNCTION IF EXISTS public.get_active_rewards(p_city TEXT, p_sport_id UUID);

-- Re-create the canonical version (from campaign builder migration logic)
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
        AND rc.valid_from <= now()
        AND (rc.valid_until IS NULL OR rc.valid_until >= now())
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
        AND (p_sport_tag IS NULL OR p_sport_tag = ANY(rc.sport_tags) OR (pc.id IS NOT NULL AND p_sport_tag = ANY(pc.sport_tags)))
    ORDER BY rc.created_at DESC;
END;
$$;

-- 2. Add missing get_my_redemption_history
CREATE OR REPLACE FUNCTION public.get_my_redemption_history()
RETURNS TABLE (
    id UUID,
    reward_id UUID,
    reward_name TEXT,
    partner_name TEXT,
    cost_points INTEGER,
    status TEXT,
    created_at TIMESTAMPTZ,
    metadata JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ra.id,
        ra.reward_id,
        rc.name AS reward_name,
        p.name AS partner_name,
        ra.cost_points,
        ra.status,
        ra.created_at,
        ra.metadata
    FROM public.redemption_attempts ra
    LEFT JOIN public.reward_catalog rc ON ra.reward_id = rc.id
    LEFT JOIN public.partners p ON ra.partner_id = p.id
    WHERE ra.user_id = auth.uid()
    ORDER BY ra.created_at DESC;
END;
$$;
