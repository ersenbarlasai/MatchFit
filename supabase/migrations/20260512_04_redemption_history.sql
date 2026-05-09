-- Redemption History
-- Date: 2026-05-12
-- Description: RPC for users to fetch their own reward redemptions.

CREATE OR REPLACE FUNCTION public.get_my_redemption_history()
RETURNS TABLE (
    redemption_id UUID,
    reward_id UUID,
    reward_name TEXT,
    reward_image_url TEXT,
    partner_id UUID,
    partner_name TEXT,
    partner_logo_url TEXT,
    cost_points INTEGER,
    status TEXT,
    rejection_reason TEXT,
    risk_level TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        ra.id AS redemption_id,
        rc.id AS reward_id,
        rc.name AS reward_name,
        rc.image_url AS reward_image_url,
        p.id AS partner_id,
        p.name AS partner_name,
        p.logo_url AS partner_logo_url,
        ra.cost_points,
        ra.status,
        ra.rejection_reason,
        ra.risk_level,
        ra.metadata,
        ra.created_at
    FROM public.redemption_attempts ra
    LEFT JOIN public.reward_catalog rc ON ra.reward_id = rc.id
    LEFT JOIN public.partners p ON ra.partner_id = p.id
    WHERE ra.user_id = auth.uid()
    ORDER BY ra.created_at DESC;
END;
$$;
