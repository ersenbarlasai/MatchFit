-- ==============================================================================
-- MATCHFIT REWARD PERSONALIZATION FOUNDATION
-- @RewardPersonalization Agent System
-- ==============================================================================

-- 1. REWARD RECOMMENDATIONS (Personalized Scoring & Ranking)
CREATE TABLE IF NOT EXISTS public.reward_recommendations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_id UUID REFERENCES public.reward_catalog(id) ON DELETE CASCADE,
  score NUMERIC NOT NULL DEFAULT 0,
  rank INTEGER,
  reason_codes TEXT[] DEFAULT '{}',
  context JSONB DEFAULT '{}'::jsonb,
  generated_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  idempotency_key TEXT,
  UNIQUE(idempotency_key)
);

-- 2. REWARD IMPRESSION EVENTS (Engagement Tracking)
CREATE TABLE IF NOT EXISTS public.reward_impression_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_id UUID REFERENCES public.reward_catalog(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- impression, click, dismiss
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  idempotency_key TEXT,
  UNIQUE(idempotency_key)
);

-- 3. RLS POLICIES
ALTER TABLE public.reward_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_impression_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own recommendations" ON public.reward_recommendations
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "Users can view their own impression events" ON public.reward_impression_events
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 4. RPC CONTRACTS

-- generate_reward_recommendations (Personalized Scoring Engine)
CREATE OR REPLACE FUNCTION public.generate_reward_recommendations(
    p_user_id UUID, 
    p_city TEXT DEFAULT NULL, 
    p_sport_id UUID DEFAULT NULL, 
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_balance INTEGER;
    v_user_city TEXT;
    v_trust_score INTEGER;
    v_risk_level TEXT;
    v_count INTEGER := 0;
BEGIN
    -- 1. Idempotency Check (Batch level check)
    -- Note: Since recommendations are many-to-one user, we append reward_id for the UNIQUE constraint below.
    
    -- 2. Fetch User Context from @EconomyEngine, @ContextAgent (Profiles), and @FraudDetection
    SELECT balance INTO v_user_balance FROM public.user_mf_balance WHERE user_id = p_user_id;
    SELECT city, trust_score INTO v_user_city, v_trust_score FROM public.profiles WHERE id = p_user_id;
    SELECT risk_level INTO v_risk_level FROM public.risk_scores WHERE user_id = p_user_id;
    
    v_user_balance := COALESCE(v_user_balance, 0);
    v_user_city := COALESCE(p_city, v_user_city);
    v_risk_level := COALESCE(v_risk_level, 'clear');

    -- 3. Clean up old recommendations for this user to avoid staleness (Optional, based on p_idempotency_key)
    IF p_idempotency_key IS NULL THEN
        DELETE FROM public.reward_recommendations WHERE user_id = p_user_id;
    END IF;

    -- 4. Scoring Logic & Batch Insert
    WITH active_rewards AS (
        SELECT 
            r.id as reward_id,
            r.cost_points,
            r.city as reward_city,
            r.sport_id as reward_sport_id,
            i.stock_remaining,
            (
                -- Canonical Scoring Rules:
                (CASE WHEN v_user_balance >= r.cost_points THEN 40 ELSE 0 END) + -- Affordable
                (CASE WHEN v_user_city = r.city THEN 20 ELSE 0 END) + -- Local Match
                (CASE WHEN p_sport_id = r.sport_id THEN 20 ELSE 0 END) + -- Sport Match
                (CASE WHEN i.stock_remaining < 5 AND i.stock_remaining > 0 THEN 5 ELSE 0 END) - -- Urgency
                (CASE WHEN v_risk_level = 'suspicious' THEN 30 ELSE 0 END) - -- Fraud Risk Penalty
                (CASE WHEN v_trust_score < 40 THEN 20 ELSE 0 END) -- Trust Penalty
            ) as calculated_score,
            ARRAY[
                CASE WHEN v_user_balance >= r.cost_points THEN 'affordable' ELSE 'expensive' END,
                CASE WHEN v_user_city = r.city THEN 'local' ELSE NULL END,
                CASE WHEN p_sport_id = r.sport_id THEN 'sport_match' ELSE NULL END,
                CASE WHEN i.stock_remaining < 5 AND i.stock_remaining > 0 THEN 'low_stock' ELSE NULL END
            ] as reason_codes
        FROM public.reward_catalog r
        LEFT JOIN public.reward_inventory i ON r.id = i.reward_id
        WHERE r.status = 'active'
          AND (r.ends_at IS NULL OR r.ends_at > now())
          AND (i.stock_remaining IS NULL OR i.stock_remaining > 0)
          AND (v_risk_level NOT IN ('blocked', 'high_risk'))
    )
    INSERT INTO public.reward_recommendations (user_id, reward_id, score, rank, reason_codes, context, idempotency_key)
    SELECT 
        p_user_id,
        reward_id,
        calculated_score,
        ROW_NUMBER() OVER (ORDER BY calculated_score DESC, reward_id),
        array_remove(reason_codes, NULL),
        jsonb_build_object('user_balance', v_user_balance, 'user_city', v_user_city, 'risk_level', v_risk_level),
        CASE WHEN p_idempotency_key IS NOT NULL THEN p_idempotency_key || ':' || reward_id ELSE NULL END
    FROM active_rewards
    WHERE calculated_score > 0
    ON CONFLICT (idempotency_key) DO NOTHING;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RETURN jsonb_build_object('status', 'success', 'recommendations_count', v_count);
END;
$$;

-- get_reward_recommendations (Fetch for UI)
CREATE OR REPLACE FUNCTION public.get_reward_recommendations(p_user_id UUID)
RETURNS TABLE (
    reward_id UUID,
    score NUMERIC,
    rank INTEGER,
    reason_codes TEXT[],
    partner_name TEXT,
    title TEXT,
    cost_points INTEGER
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        rec.reward_id,
        rec.score,
        rec.rank,
        rec.reason_codes,
        p.name as partner_name,
        rc.title,
        rc.cost_points
    FROM public.reward_recommendations rec
    JOIN public.reward_catalog rc ON rec.reward_id = rc.id
    JOIN public.partners p ON rc.partner_id = p.id
    WHERE rec.user_id = p_user_id
    ORDER BY rec.rank ASC;
$$;

-- log_reward_recommendation_event (Engagement Tracker)
CREATE OR REPLACE FUNCTION public.log_reward_recommendation_event(
    p_reward_id UUID,
    p_event_type TEXT, -- impression, click, dismiss
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_event_id UUID;
BEGIN
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_event_id FROM public.reward_impression_events WHERE idempotency_key = p_idempotency_key;
        IF v_event_id IS NOT NULL THEN
            RETURN v_event_id;
        END IF;
    END IF;

    INSERT INTO public.reward_impression_events (user_id, reward_id, event_type, metadata, idempotency_key)
    VALUES (auth.uid(), p_reward_id, p_event_type, p_metadata, p_idempotency_key)
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$;

-- 5. GRANTS
GRANT EXECUTE ON FUNCTION public.generate_reward_recommendations(UUID, TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reward_recommendations(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reward_recommendation_event(UUID, TEXT, JSONB, TEXT) TO authenticated;
