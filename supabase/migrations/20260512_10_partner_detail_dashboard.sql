-- Partner Detail Dashboard RPC
-- Date: 2026-05-12
-- Description: Provides a comprehensive KPI and activity summary for a specific partner.

CREATE OR REPLACE FUNCTION public.get_partner_detail_kpi(p_partner_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_partner RECORD;
    v_kpi JSONB;
    v_campaigns JSONB;
    v_rewards JSONB;
    v_recent_redemptions JSONB;
    v_total_views BIGINT;
    v_total_clicks BIGINT;
BEGIN
    -- Auth check
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    -- Get partner info
    SELECT id, name, tier, status, category, city, logo_url, contact_email
    INTO v_partner
    FROM public.partners
    WHERE id = p_partner_id;

    IF v_partner.id IS NULL THEN
        RAISE EXCEPTION 'Partner bulunamadı: %', p_partner_id;
    END IF;

    -- Interaction stats
    SELECT 
        COUNT(*) FILTER (WHERE event_type = 'view'),
        COUNT(*) FILTER (WHERE event_type = 'click')
    INTO v_total_views, v_total_clicks
    FROM public.reward_interaction_events
    WHERE partner_id = p_partner_id;

    -- KPI Summary
    SELECT jsonb_build_object(
        'total_rewards', COUNT(rc.id),
        'active_rewards', COUNT(rc.id) FILTER (WHERE rc.status = 'active'),
        'total_campaigns', (SELECT COUNT(*) FROM public.partner_campaigns WHERE partner_id = p_partner_id),
        'active_campaigns', (SELECT COUNT(*) FROM public.partner_campaigns WHERE partner_id = p_partner_id AND status = 'active'),
        'low_stock_rewards', (SELECT COUNT(*) FROM public.reward_inventory ri JOIN public.reward_catalog r ON ri.reward_id = r.id WHERE r.partner_id = p_partner_id AND NOT ri.is_unlimited AND ri.stock_remaining <= 5),
        'total_redemptions', COUNT(ra.id),
        'approved_redemptions', COUNT(ra.id) FILTER (WHERE ra.status IN ('approved', 'completed')),
        'rejected_redemptions', COUNT(ra.id) FILTER (WHERE ra.status = 'rejected'),
        'total_points_spent', COALESCE(SUM(ra.cost_points) FILTER (WHERE ra.status IN ('approved', 'completed')), 0),
        'total_views', v_total_views,
        'total_clicks', v_total_clicks,
        'ctr', CASE WHEN v_total_views > 0 THEN ROUND((v_total_clicks::NUMERIC / v_total_views::NUMERIC) * 100, 2) ELSE 0 END
    ) INTO v_kpi
    FROM public.reward_catalog rc
    LEFT JOIN public.redemption_attempts ra ON rc.id = ra.reward_id
    WHERE rc.partner_id = p_partner_id;

    -- Campaigns list
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_campaigns
    FROM (
        SELECT 
            pc.id, pc.name, pc.status, pc.starts_at, pc.ends_at,
            COUNT(DISTINCT rc.id) as reward_count,
            COUNT(DISTINCT ra.id) as redemption_count
        FROM public.partner_campaigns pc
        LEFT JOIN public.reward_catalog rc ON pc.id = rc.campaign_id
        LEFT JOIN public.redemption_attempts ra ON rc.id = ra.reward_id
        WHERE pc.partner_id = p_partner_id
        GROUP BY pc.id
        ORDER BY pc.created_at DESC
    ) sub;

    -- Rewards list
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_rewards
    FROM (
        SELECT 
            rc.id, rc.name, rc.status, rc.cost_points, 
            ri.stock_remaining, ri.is_unlimited,
            rc.campaign_id, pc.name as campaign_name,
            COUNT(DISTINCT ra.id) as redemption_count,
            (SELECT COUNT(*) FROM public.reward_interaction_events WHERE reward_id = rc.id AND event_type = 'view') as view_count,
            (SELECT COUNT(*) FROM public.reward_interaction_events WHERE reward_id = rc.id AND event_type = 'click') as click_count
        FROM public.reward_catalog rc
        LEFT JOIN public.reward_inventory ri ON rc.id = ri.reward_id
        LEFT JOIN public.partner_campaigns pc ON rc.campaign_id = pc.id
        LEFT JOIN public.redemption_attempts ra ON rc.id = ra.reward_id
        WHERE rc.partner_id = p_partner_id
        GROUP BY rc.id, ri.stock_remaining, ri.is_unlimited, pc.name
        ORDER BY rc.created_at DESC
    ) sub;

    -- Recent Redemptions
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_recent_redemptions
    FROM (
        SELECT 
            ra.id, rc.name as reward_name, ra.user_id, ra.status, ra.cost_points, ra.created_at
        FROM public.redemption_attempts ra
        JOIN public.reward_catalog rc ON ra.reward_id = rc.id
        WHERE rc.partner_id = p_partner_id
        ORDER BY ra.created_at DESC
        LIMIT 10
    ) sub;

    RETURN jsonb_build_object(
        'partner', to_jsonb(v_partner),
        'kpi', v_kpi,
        'campaigns', v_campaigns,
        'rewards', v_rewards,
        'recent_redemptions', v_recent_redemptions
    );
END;
$$;
