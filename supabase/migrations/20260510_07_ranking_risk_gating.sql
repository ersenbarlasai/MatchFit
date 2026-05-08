-- ==============================================================================
-- MATCHFIT RANKING RISK GATING
-- @RankingEngine & @FraudDetection Integration
-- ==============================================================================

-- 1. UPDATE RANKING VIEW WITH FRAUD RISK GATING
-- Canonical Rule: @RankingEngine reads fraud risk signals to adjust ranking and leagues.
CREATE OR REPLACE VIEW public.vw_leaderboard AS
SELECT 
    p.id AS user_id,
    p.full_name,
    p.avatar_url,
    p.city,
    p.trust_score,
    COALESCE(x.xp_amount, 0) AS xp_amount,
    COALESCE(x.current_level, 1) AS level,
    -- Rank Score Calculation
    (
        COALESCE(x.xp_amount, 0) 
        * 
        -- STEP 2: Trust Multiplier (Existing logic)
        CASE 
            WHEN p.trust_score >= 80 THEN 1.2
            WHEN p.trust_score >= 60 THEN 1.1
            WHEN p.trust_score >= 40 THEN 1.0
            ELSE 0.7
        END
        *
        -- STEP 3: Activity Factor (Existing logic)
        CASE 
            WHEN x.last_activity_date >= CURRENT_DATE - INTERVAL '1 day' THEN 1.1
            WHEN x.last_activity_date >= CURRENT_DATE - INTERVAL '3 days' THEN 1.0
            WHEN x.last_activity_date >= CURRENT_DATE - INTERVAL '7 days' THEN 0.9
            ELSE 0.75
        END
        *
        -- STEP 4: Fraud Risk Adjustment (Integrated from @FraudDetection)
        -- Logic:
        -- - Blocked/High Risk: Multiplier 0.0 (Score zeroed)
        -- - Suspicious: Multiplier 0.5 (50% penalty)
        -- - Legacy Fallback: profiles.abuse_status (0.4 to 0.95)
        CASE
            WHEN r.risk_level = 'blocked' THEN 0.0
            WHEN r.risk_level = 'high_risk' THEN 0.0
            WHEN r.risk_level = 'suspicious' THEN 0.5
            WHEN p.abuse_status = 'confirmed_abuse' THEN 0.4
            WHEN p.abuse_status = 'suspicious' THEN 0.7
            WHEN p.abuse_status = 'low_variation' THEN 0.95
            ELSE 1.0
        END
    ) AS rank_score,
    -- League Determination (STEP 5)
    -- Rule: Users with high fraud risk cannot be promoted and are restricted to 'Bronze'.
    CASE 
        WHEN COALESCE(r.risk_level, 'clear') IN ('blocked', 'high_risk') THEN 'Bronze'
        WHEN COALESCE(x.xp_amount, 0) >= 15000 THEN 'Elite'
        WHEN COALESCE(x.xp_amount, 0) >= 7000 THEN 'Platinum'
        WHEN COALESCE(x.xp_amount, 0) >= 3000 THEN 'Gold'
        WHEN COALESCE(x.xp_amount, 0) >= 1000 THEN 'Silver'
        ELSE 'Bronze'
    END AS league
FROM public.profiles p
LEFT JOIN public.user_xp x ON p.id = x.user_id
LEFT JOIN public.risk_scores r ON p.id = r.user_id
WHERE p.full_name IS NOT NULL
  AND (r.risk_level IS NULL OR r.risk_level != 'blocked'); -- Blocked users are hidden from leaderboards

-- 2. REFRESH DEPENDENT FUNCTIONS (Ensuring schema consistency)
-- The RPCs (get_global_leaderboard, get_city_leaderboard, etc.) already reference vw_leaderboard
-- and will reflect changes immediately.

-- 3. LEAGUE PROMOTION BLOCKING (Optional: Sync user_leagues table if it exists)
-- If we want to persist the league state in user_leagues table:
CREATE OR REPLACE FUNCTION public.sync_user_leagues_state()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_leagues (user_id, league_name, rank_score, last_updated)
    SELECT user_id, league, rank_score, now()
    FROM public.vw_leaderboard
    ON CONFLICT (user_id) DO UPDATE
    SET 
        league_name = EXCLUDED.league_name,
        rank_score = EXCLUDED.rank_score,
        last_updated = EXCLUDED.last_updated;
END;
$$;
