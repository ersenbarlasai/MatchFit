-- Reward Personalization MVP
-- Date: 2026-05-12
-- Description: RPC for scoring and ranking rewards based on user profile, balance, trust, and preferences.

-- 1. Schema Hardening (Ensuring risk_scores exists for MVP stability if not already present)
CREATE TABLE IF NOT EXISTS public.risk_scores (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    risk_level TEXT DEFAULT 'clear', -- 'clear', 'suspicious', 'high_risk', 'blocked'
    last_signal_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. RPC: Get Personalized Rewards
DROP FUNCTION IF EXISTS public.get_personalized_rewards(INTEGER);

CREATE OR REPLACE FUNCTION public.get_personalized_rewards(
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    reward_id UUID,
    partner_id UUID,
    partner_name TEXT,
    partner_logo_url TEXT,
    name TEXT,
    short_description TEXT,
    image_url TEXT,
    cost_points INTEGER,
    is_free BOOLEAN,
    city TEXT,
    sport_tags TEXT[],
    stock_remaining INTEGER,
    is_unlimited BOOLEAN,
    boost_active BOOLEAN,
    score NUMERIC,
    score_reasons JSONB
) AS $$
#variable_conflict use_column
DECLARE
    v_user_id UUID := auth.uid();
    v_user_city TEXT;
    v_user_trust INTEGER;
    v_user_balance INTEGER;
    v_user_risk TEXT;
    v_user_sports TEXT[];
BEGIN
    -- 1. Auth Gate
    IF v_user_id IS NULL THEN
        RETURN;
    END IF;

    -- 2. Fetch User Context
    SELECT p.city, p.trust_score INTO v_user_city, v_user_trust FROM public.profiles p WHERE p.id = v_user_id;
    SELECT b.balance INTO v_user_balance FROM public.user_mf_balance b WHERE b.user_id = v_user_id;
    SELECT rs.risk_level INTO v_user_risk FROM public.risk_scores rs WHERE rs.user_id = v_user_id;
    
    SELECT ARRAY_AGG(us.sport_id) INTO v_user_sports 
    FROM public.user_sports_preferences us 
    WHERE us.user_id = v_user_id;

    -- 3. Defaults for safety
    v_user_trust := COALESCE(v_user_trust, 0);
    v_user_balance := COALESCE(v_user_balance, 0);
    v_user_risk := COALESCE(v_user_risk, 'clear');
    v_user_sports := COALESCE(v_user_sports, '{}'::TEXT[]);

    -- 4. Ranking Query
    RETURN QUERY
    WITH scored_rewards AS (
        SELECT 
            r.id as r_id,
            r.partner_id as p_id,
            p.name as p_name,
            p.logo_url as p_logo,
            r.name as r_name,
            r.short_description as r_desc,
            r.image_url as r_img,
            r.cost_points as r_cost,
            r.is_free as r_free,
            r.city as r_city,
            r.sport_tags as r_sports,
            i.stock_remaining as r_stock,
            i.is_unlimited as r_unlimited,
            r.boost_active as r_boost,
            -- Scoring Logic
            (
                -- Affordability Score
                CASE 
                    WHEN r.is_free THEN 30
                    WHEN r.cost_points <= v_user_balance THEN 35
                    WHEN r.cost_points <= v_user_balance * 1.25 THEN 15
                    ELSE 0
                END +
                -- City Score
                CASE
                    WHEN r.city IS NULL THEN 5
                    WHEN r.city = v_user_city THEN 20
                    ELSE 0
                END +
                -- Sport Score
                CASE
                    WHEN r.sport_tags && v_user_sports THEN 25
                    WHEN array_length(r.sport_tags, 1) > 1 THEN 10
                    ELSE 0
                END +
                -- Trust Score
                CASE
                    WHEN v_user_trust >= 70 THEN 10
                    ELSE 0
                END +
                -- Stock Urgency
                CASE
                    WHEN i.is_unlimited THEN 3
                    WHEN i.stock_remaining BETWEEN 1 AND 5 THEN 8
                    ELSE 0
                END +
                -- Boost
                CASE
                    WHEN r.boost_active THEN 15 * COALESCE(r.boost_multiplier, 1.0)
                    ELSE 0
                END -
                -- Risk Penalty
                CASE
                    WHEN v_user_risk = 'suspicious' THEN 20
                    ELSE 0
                END
            )::NUMERIC as total_score,
            -- Score Reasons
            jsonb_build_object(
                'affordability', CASE WHEN r.is_free THEN 'free' WHEN r.cost_points <= v_user_balance THEN 'affordable' ELSE 'premium' END,
                'city_match', CASE WHEN r.city = v_user_city THEN true ELSE false END,
                'sports_match', r.sport_tags && v_user_sports,
                'trust_bonus', v_user_trust >= 70,
                'boosted', r.boost_active
            ) as reasons
        FROM public.reward_catalog r
        JOIN public.partners p ON r.partner_id = p.id
        JOIN public.reward_inventory i ON r.id = i.reward_id
        WHERE r.status = 'active'
          AND p.status = 'active'
          AND r.valid_from <= now()
          AND (r.valid_until IS NULL OR r.valid_until >= now())
          AND (i.is_unlimited = TRUE OR i.stock_remaining > 0)
          -- Hard Gating
          AND v_user_trust >= COALESCE(r.trust_minimum, 0)
          AND v_user_risk NOT IN ('high_risk', 'blocked')
    )
    SELECT 
        r_id, p_id, p_name, p_logo, r_name, r_desc, r_img, r_cost, r_free,
        r_city, r_sports, r_stock, r_unlimited, r_boost, total_score, reasons
    FROM scored_rewards
    ORDER BY total_score DESC, r_boost DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
