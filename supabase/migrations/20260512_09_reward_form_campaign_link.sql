-- Reward Form Campaign Link
-- Date: 2026-05-12
-- Description: Updates upsert_reward_catalog_admin to support p_campaign_id.

-- ── 1. Update RPC ──────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.upsert_reward_catalog_admin(
    p_reward_id UUID DEFAULT NULL,
    p_partner_id UUID DEFAULT NULL,
    p_name TEXT DEFAULT NULL,
    p_short_description TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_sport_tags TEXT[] DEFAULT NULL,
    p_eligibility_tier TEXT DEFAULT NULL,
    p_trust_minimum INTEGER DEFAULT NULL,
    p_cost_points INTEGER DEFAULT NULL,
    p_is_free BOOLEAN DEFAULT NULL,
    p_discount_percent NUMERIC DEFAULT NULL,
    p_transaction_url TEXT DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_valid_from TIMESTAMPTZ DEFAULT NULL,
    p_valid_until TIMESTAMPTZ DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_boost_active BOOLEAN DEFAULT NULL,
    p_boost_multiplier NUMERIC DEFAULT NULL,
    p_show_remaining_stock BOOLEAN DEFAULT NULL,
    p_show_expiry_countdown BOOLEAN DEFAULT NULL,
    p_city_exclusive_label TEXT DEFAULT NULL,
    p_limited_badge BOOLEAN DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_campaign_id UUID DEFAULT NULL -- New parameter
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result_id UUID;
    v_campaign_partner_id UUID;
    v_final_partner_id UUID;
BEGIN
    -- Auth check
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    -- Resolve partner_id if update
    IF p_reward_id IS NOT NULL THEN
        SELECT partner_id INTO v_final_partner_id FROM public.reward_catalog WHERE id = p_reward_id;
    ELSE
        v_final_partner_id := p_partner_id;
    END IF;

    IF v_final_partner_id IS NULL THEN
        RAISE EXCEPTION 'partner_id cannot be resolved.';
    END IF;

    -- Validate campaign if provided
    IF p_campaign_id IS NOT NULL THEN
        SELECT partner_id INTO v_campaign_partner_id FROM public.partner_campaigns WHERE id = p_campaign_id;
        IF v_campaign_partner_id IS NULL THEN
            RAISE EXCEPTION 'Geçersiz campaign_id: %', p_campaign_id;
        END IF;

        IF v_campaign_partner_id != v_final_partner_id THEN
            RAISE EXCEPTION 'Ödül ve Kampanya aynı partner''a ait olmalıdır.';
        END IF;
    END IF;

    IF p_reward_id IS NULL THEN
        -- Insert
        INSERT INTO public.reward_catalog (
            partner_id, name, short_description, description, category, sport_tags,
            eligibility_tier, trust_minimum, cost_points, is_free, discount_percent,
            transaction_url, image_url, valid_from, valid_until, city, boost_active,
            boost_multiplier, show_remaining_stock, show_expiry_countdown,
            city_exclusive_label, limited_badge, status, metadata, campaign_id
        ) VALUES (
            p_partner_id, p_name, p_short_description, p_description, p_category, p_sport_tags,
            p_eligibility_tier, p_trust_minimum, p_cost_points, p_is_free, p_discount_percent,
            p_transaction_url, p_image_url, COALESCE(p_valid_from, now()), p_valid_until, p_city, p_boost_active,
            p_boost_multiplier, p_show_remaining_stock, p_show_expiry_countdown,
            p_city_exclusive_label, p_limited_badge, COALESCE(p_status, 'pending'), p_metadata, p_campaign_id
        ) RETURNING id INTO v_result_id;
    ELSE
        -- Update
        UPDATE public.reward_catalog SET
            name = COALESCE(p_name, name),
            short_description = COALESCE(p_short_description, short_description),
            description = COALESCE(p_description, description),
            category = COALESCE(p_category, category),
            sport_tags = COALESCE(p_sport_tags, sport_tags),
            eligibility_tier = COALESCE(p_eligibility_tier, eligibility_tier),
            trust_minimum = COALESCE(p_trust_minimum, trust_minimum),
            cost_points = COALESCE(p_cost_points, cost_points),
            is_free = COALESCE(p_is_free, is_free),
            discount_percent = COALESCE(p_discount_percent, discount_percent),
            transaction_url = COALESCE(p_transaction_url, transaction_url),
            image_url = COALESCE(p_image_url, image_url),
            valid_from = COALESCE(p_valid_from, valid_from),
            valid_until = COALESCE(p_valid_until, valid_until),
            city = COALESCE(p_city, city),
            boost_active = COALESCE(p_boost_active, boost_active),
            boost_multiplier = COALESCE(p_boost_multiplier, boost_multiplier),
            show_remaining_stock = COALESCE(p_show_remaining_stock, show_remaining_stock),
            show_expiry_countdown = COALESCE(p_show_expiry_countdown, show_expiry_countdown),
            city_exclusive_label = COALESCE(p_city_exclusive_label, city_exclusive_label),
            limited_badge = COALESCE(p_limited_badge, limited_badge),
            status = COALESCE(p_status, status),
            metadata = p_metadata,
            campaign_id = p_campaign_id, -- Directly set (can be null)
            updated_at = now()
        WHERE id = p_reward_id
        RETURNING id INTO v_result_id;
    END IF;

    RETURN v_result_id;
END;
$$;


-- ── 2. Update get_reward_admin_list to include campaign info ───────────────

CREATE OR REPLACE FUNCTION public.get_reward_admin_list()
RETURNS TABLE (
    id UUID,
    name TEXT,
    partner_id UUID,
    partner_name TEXT,
    status TEXT,
    cost_points INTEGER,
    is_free BOOLEAN,
    stock_total INTEGER,
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
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    RETURN QUERY
    SELECT 
        r.id, r.name, r.partner_id, p.name as partner_name, r.status, r.cost_points, r.is_free,
        i.stock_total, i.stock_remaining, i.is_unlimited,
        r.campaign_id, pc.name as campaign_name
    FROM public.reward_catalog r
    JOIN public.partners p ON r.partner_id = p.id
    LEFT JOIN public.reward_inventory i ON r.id = i.reward_id
    LEFT JOIN public.partner_campaigns pc ON r.campaign_id = pc.id
    ORDER BY r.created_at DESC;
END;
$$;
