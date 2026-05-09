-- Partner Admin KPI Dashboard
-- Date: 2026-05-12
-- Description: RPC for admin dashboard to view partner and reward KPIs.

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
    v_top_rewards JSONB;
BEGIN
    -- Auth check
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    -- Basic Partner Metrics
    SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'active')
    INTO v_total_partners, v_active_partners
    FROM public.partners;

    -- Basic Reward Metrics
    SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'active')
    INTO v_total_rewards, v_active_rewards
    FROM public.reward_catalog;

    -- Low Stock Metric
    SELECT COUNT(*)
    INTO v_low_stock_rewards
    FROM public.reward_inventory
    WHERE is_unlimited = false AND stock_remaining <= 5;

    -- Redemption Metrics
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

    -- Top Rewards (by approved redemptions)
    SELECT COALESCE(jsonb_agg(row_to_json(tr)), '[]'::jsonb)
    INTO v_top_rewards
    FROM (
        SELECT 
            rc.id AS reward_id,
            rc.name AS reward_name,
            p.name AS partner_name,
            COUNT(ra.id) AS redemption_count,
            ri.stock_remaining,
            rc.status
        FROM public.reward_catalog rc
        JOIN public.partners p ON rc.partner_id = p.id
        LEFT JOIN public.reward_inventory ri ON rc.id = ri.reward_id
        LEFT JOIN public.redemption_attempts ra ON rc.id = ra.reward_id AND ra.status IN ('approved', 'completed')
        GROUP BY rc.id, rc.name, p.name, ri.stock_remaining, rc.status
        ORDER BY redemption_count DESC
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
        'top_rewards', v_top_rewards
    );
END;
$$;
