-- Partner & Reward Admin Management
-- Date: 2026-05-12
-- Description: RPCs for admin management of partners and reward catalog items.

-- 1. Helper Function: Check if user is admin
CREATE OR REPLACE FUNCTION public.is_user_admin() RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    IF COALESCE(auth.role(), '') = 'service_role' THEN
        RETURN TRUE;
    END IF;

    SELECT LOWER(TRIM(COALESCE(role, ''))) INTO v_role
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_role IN ('admin', 'system_admin') THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Upsert Partner (Admin)
CREATE OR REPLACE FUNCTION public.upsert_partner_admin(
    p_partner_id UUID DEFAULT NULL,
    p_name TEXT DEFAULT NULL,
    p_slug TEXT DEFAULT NULL,
    p_logo_url TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_tier TEXT DEFAULT 'basic',
    p_status TEXT DEFAULT 'pending',
    p_city TEXT DEFAULT NULL,
    p_contact_email TEXT DEFAULT NULL,
    p_contact_name TEXT DEFAULT NULL,
    p_billing_model TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS UUID AS $$
DECLARE
    v_result_id UUID;
BEGIN
    -- Auth check
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    IF p_partner_id IS NULL THEN
        -- Insert
        INSERT INTO public.partners (
            name, slug, logo_url, category, tier, status, city,
            contact_email, contact_name, billing_model, metadata
        ) VALUES (
            p_name, p_slug, p_logo_url, p_category, p_tier, p_status, p_city,
            p_contact_email, p_contact_name, p_billing_model, p_metadata
        ) RETURNING id INTO v_result_id;
    ELSE
        -- Update
        UPDATE public.partners SET
            name = COALESCE(p_name, name),
            slug = COALESCE(p_slug, slug),
            logo_url = COALESCE(p_logo_url, logo_url),
            category = COALESCE(p_category, category),
            tier = COALESCE(p_tier, tier),
            status = COALESCE(p_status, status),
            city = COALESCE(p_city, city),
            contact_email = COALESCE(p_contact_email, contact_email),
            contact_name = COALESCE(p_contact_name, contact_name),
            billing_model = COALESCE(p_billing_model, billing_model),
            metadata = p_metadata,
            updated_at = now()
        WHERE id = p_partner_id
        RETURNING id INTO v_result_id;
    END IF;

    RETURN v_result_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Upsert Reward Catalog (Admin)
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
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS UUID AS $$
DECLARE
    v_result_id UUID;
BEGIN
    -- Auth check
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    IF p_partner_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.partners WHERE id = p_partner_id) THEN
        RAISE EXCEPTION 'Geçersiz partner_id';
    END IF;

    IF p_reward_id IS NULL THEN
        -- Insert
        IF p_partner_id IS NULL THEN
            RAISE EXCEPTION 'Yeni ödül oluşturulurken partner_id zorunludur.';
        END IF;

        INSERT INTO public.reward_catalog (
            partner_id, name, short_description, description, category, sport_tags,
            eligibility_tier, trust_minimum, cost_points, is_free, discount_percent,
            transaction_url, image_url, valid_from, valid_until, city, boost_active,
            boost_multiplier, show_remaining_stock, show_expiry_countdown,
            city_exclusive_label, limited_badge, status, metadata
        ) VALUES (
            p_partner_id, p_name, p_short_description, p_description, p_category, p_sport_tags,
            p_eligibility_tier, p_trust_minimum, p_cost_points, p_is_free, p_discount_percent,
            p_transaction_url, p_image_url, COALESCE(p_valid_from, now()), p_valid_until, p_city, p_boost_active,
            p_boost_multiplier, p_show_remaining_stock, p_show_expiry_countdown,
            p_city_exclusive_label, p_limited_badge, COALESCE(p_status, 'pending'), p_metadata
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
            updated_at = now()
        WHERE id = p_reward_id
        RETURNING id INTO v_result_id;
    END IF;

    RETURN v_result_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Update Reward Inventory (Admin)
CREATE OR REPLACE FUNCTION public.update_reward_inventory_admin(
    p_reward_id UUID,
    p_stock_total INTEGER,
    p_stock_remaining INTEGER,
    p_is_unlimited BOOLEAN DEFAULT FALSE
) RETURNS VOID AS $$
BEGIN
    -- Auth check
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.reward_catalog WHERE id = p_reward_id) THEN
        RAISE EXCEPTION 'Geçersiz reward_id';
    END IF;

    -- Upsert strategy
    IF EXISTS (SELECT 1 FROM public.reward_inventory WHERE reward_id = p_reward_id) THEN
        UPDATE public.reward_inventory SET
            stock_total = p_stock_total,
            stock_remaining = LEAST(p_stock_remaining, p_stock_total),
            is_unlimited = p_is_unlimited,
            updated_at = now()
        WHERE reward_id = p_reward_id;
    ELSE
        INSERT INTO public.reward_inventory (reward_id, stock_total, stock_remaining, is_unlimited)
        VALUES (p_reward_id, p_stock_total, LEAST(p_stock_remaining, p_stock_total), p_is_unlimited);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. Get Partner Admin List
CREATE OR REPLACE FUNCTION public.get_partner_admin_list()
RETURNS TABLE (
    id UUID,
    name TEXT,
    slug TEXT,
    category TEXT,
    tier TEXT,
    status TEXT,
    city TEXT,
    active_rewards_count BIGINT
) AS $$
BEGIN
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    RETURN QUERY
    SELECT 
        p.id, p.name, p.slug, p.category, p.tier, p.status, p.city,
        (SELECT COUNT(*) FROM public.reward_catalog r WHERE r.partner_id = p.id AND r.status = 'active') as active_rewards_count
    FROM public.partners p
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. Get Reward Admin List
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
    is_unlimited BOOLEAN
) AS $$
BEGIN
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    RETURN QUERY
    SELECT 
        r.id, r.name, r.partner_id, p.name as partner_name, r.status, r.cost_points, r.is_free,
        i.stock_total, i.stock_remaining, i.is_unlimited
    FROM public.reward_catalog r
    JOIN public.partners p ON r.partner_id = p.id
    LEFT JOIN public.reward_inventory i ON r.id = i.reward_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
