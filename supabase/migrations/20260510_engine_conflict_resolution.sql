-- ==============================================================================
-- MATCHFIT ENGINE CONFLICT RESOLUTION MIGRATION
-- P0 & P1 Implementation
-- ==============================================================================

-- 1. ADD IDEMPOTENCY KEYS
ALTER TABLE public.xp_events ADD COLUMN IF NOT EXISTS idempotency_key TEXT UNIQUE;
ALTER TABLE public.mf_point_ledger ADD COLUMN IF NOT EXISTS idempotency_key TEXT UNIQUE;

-- 2. STREAK BACKFILL
-- Move data from profiles.streak_count to user_xp.current_streak where needed.
INSERT INTO public.user_xp (user_id, current_streak, xp_amount, current_level)
SELECT id, COALESCE(streak_count, 0), 0, 1
FROM public.profiles
ON CONFLICT (user_id) DO UPDATE 
SET current_streak = GREATEST(public.user_xp.current_streak, EXCLUDED.current_streak);

COMMENT ON COLUMN public.profiles.streak_count IS 'DEPRECATED: Use user_xp.current_streak instead. Do not drop yet.';

-- 3. FIX RLS ON LOG TABLES (Close Client Inserts)
-- moderation_logs
DROP POLICY IF EXISTS "Users can insert own logs" ON public.moderation_logs;
CREATE POLICY "Agent only insert" ON public.moderation_logs FOR INSERT WITH CHECK (false); -- Backend/RPC only

-- coach_verification_logs
DROP POLICY IF EXISTS "Coaches can insert their own logs" ON public.coach_verification_logs;
CREATE POLICY "Agent only insert" ON public.coach_verification_logs FOR INSERT WITH CHECK (false); -- Backend/RPC only

-- fraud_signals (If exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'fraud_signals') THEN
        DROP POLICY IF EXISTS "Users can insert own fraud signals" ON public.fraud_signals;
        CREATE POLICY "Agent only insert" ON public.fraud_signals FOR INSERT WITH CHECK (false);
    END IF;
END $$;

-- 4. ECONOMY ENGINE UPDATE (Idempotency & Daily Cap enforcement)
CREATE OR REPLACE FUNCTION public.add_mf_points(
    p_user_id UUID, 
    p_amount INTEGER, 
    p_source TEXT, 
    p_description TEXT DEFAULT '',
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_balance INTEGER;
    v_new_balance INTEGER;
    v_total_earned INTEGER;
    v_daily_earned INTEGER;
    v_daily_cap INTEGER := 100;
    v_actual_amount INTEGER := p_amount;
BEGIN
    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.mf_point_ledger WHERE idempotency_key = p_idempotency_key) THEN
            RETURN; -- Already processed
        END IF;
    END IF;

    -- Get daily cap from orchestrator_config if exists
    SELECT COALESCE(daily_mf_cap, 100) INTO v_daily_cap FROM public.orchestrator_config WHERE id = 1;

    -- Calculate daily earned for cap enforcement (only positive amounts)
    IF p_amount > 0 THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_daily_earned
        FROM public.mf_point_ledger
        WHERE user_id = p_user_id AND created_at >= CURRENT_DATE AND amount > 0;
        
        IF (v_daily_earned + p_amount) > v_daily_cap THEN
            v_actual_amount := GREATEST(0, v_daily_cap - v_daily_earned);
        END IF;
    END IF;
    
    IF v_actual_amount <= 0 AND p_amount > 0 THEN
        RETURN; -- Cap reached, do not process zero amount ledger for earnings
    END IF;

    -- Get current balance
    SELECT balance, total_earned
    INTO v_current_balance, v_total_earned
    FROM public.user_mf_balance
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        v_current_balance := 0;
        v_total_earned := 0;
        INSERT INTO public.user_mf_balance (user_id, balance, total_earned)
        VALUES (p_user_id, 0, 0);
    END IF;

    v_new_balance := v_current_balance + v_actual_amount;
    
    IF v_new_balance < 0 THEN
        RAISE EXCEPTION 'Yetersiz MF Points bakiyesi.';
    END IF;

    IF v_actual_amount > 0 THEN
        v_total_earned := v_total_earned + v_actual_amount;
    END IF;

    -- Record ledger
    INSERT INTO public.mf_point_ledger (user_id, amount, balance_after, source, description, idempotency_key)
    VALUES (p_user_id, v_actual_amount, v_new_balance, p_source, p_description, p_idempotency_key);

    -- Update balance
    UPDATE public.user_mf_balance
    SET balance = v_new_balance,
        total_earned = v_total_earned,
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_user_id;
END;
$$;

-- 5. XP ENGINE UPDATE (Idempotency)
CREATE OR REPLACE FUNCTION public.add_user_xp(
    p_user_id UUID, 
    p_amount INTEGER, 
    p_source TEXT,
    p_quality_tier TEXT DEFAULT 'B',
    p_event_quality TEXT DEFAULT 'normal',
    p_is_first_event BOOLEAN DEFAULT false,
    p_new_person_count INTEGER DEFAULT 0,
    p_is_new_branch BOOLEAN DEFAULT false,
    p_friend_invite_count INTEGER DEFAULT 0,
    p_is_weekend BOOLEAN DEFAULT false,
    p_is_no_show BOOLEAN DEFAULT false,
    p_abuse_status TEXT DEFAULT 'clean',
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_xp INTEGER;
    v_new_xp INTEGER;
    v_new_level INTEGER;
    v_last_activity DATE;
    v_current_streak INTEGER;
    v_today DATE := CURRENT_DATE;
    
    v_final_amount NUMERIC := p_amount;
    v_daily_earned INTEGER := 0;
    v_events_today INTEGER := 0;
    
    v_streak_multiplier NUMERIC := 1.0;
    v_quality_multiplier NUMERIC := 1.0;
    v_tier_multiplier NUMERIC := 1.0;
    v_diminishing_multiplier NUMERIC := 1.0;
    v_soft_cap_multiplier NUMERIC := 1.0;
    v_orch_xp_mult NUMERIC := 1.0;
    
    v_bonus_xp INTEGER := 0;
    v_details JSONB;
BEGIN
    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.xp_events WHERE idempotency_key = p_idempotency_key) THEN
            RETURN; -- Already processed
        END IF;
    END IF;

    SELECT xp_multiplier INTO v_orch_xp_mult FROM public.orchestrator_config WHERE id = 1;

    SELECT xp_amount, current_streak, last_activity_date
    INTO v_current_xp, v_current_streak, v_last_activity
    FROM public.user_xp
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        v_current_xp := 0;
        v_current_streak := 0;
        v_last_activity := v_today - INTERVAL '2 days';
    END IF;

    IF p_is_no_show THEN
        v_current_streak := 0; 
        v_final_amount := 0;
        v_bonus_xp := 0;
    ELSIF p_abuse_status IN ('suspicious', 'confirmed_abuse') THEN
        v_final_amount := 0; 
        v_bonus_xp := 0;
    ELSE
        IF v_last_activity = v_today - INTERVAL '1 day' THEN
            v_current_streak := v_current_streak + 1;
        ELSIF v_last_activity < v_today - INTERVAL '1 day' THEN
            v_current_streak := 1;
        END IF;

        IF v_current_streak >= 30 THEN v_streak_multiplier := 1.25;
        ELSIF v_current_streak >= 10 THEN v_streak_multiplier := 1.12;
        ELSIF v_current_streak >= 5 THEN v_streak_multiplier := 1.07;
        ELSIF v_current_streak >= 2 THEN v_streak_multiplier := 1.03;
        END IF;

        IF p_event_quality = 'perfect' THEN v_quality_multiplier := 1.4;
        ELSIF p_event_quality = 'good' THEN v_quality_multiplier := 1.2;
        ELSIF p_event_quality = 'bad' THEN v_quality_multiplier := 0.7;
        END IF;

        IF p_quality_tier = 'S' THEN v_tier_multiplier := 1.4;
        ELSIF p_quality_tier = 'A' THEN v_tier_multiplier := 1.2;
        ELSIF p_quality_tier = 'C' THEN v_tier_multiplier := 0.7;
        END IF;

        IF p_is_first_event THEN v_bonus_xp := v_bonus_xp + 20; END IF;
        IF p_is_new_branch THEN v_bonus_xp := v_bonus_xp + 10; END IF;
        IF p_is_weekend THEN v_bonus_xp := v_bonus_xp + 5; END IF;
        v_bonus_xp := v_bonus_xp + (p_new_person_count * 8);
        v_bonus_xp := v_bonus_xp + (p_friend_invite_count * 15);

        IF p_source IN ('event_completed', 'event_creation') THEN
            SELECT COUNT(*) INTO v_events_today 
            FROM public.xp_events 
            WHERE user_id = p_user_id 
              AND created_at >= CURRENT_DATE 
              AND source IN ('event_completed', 'event_creation');

            IF v_events_today = 0 THEN v_diminishing_multiplier := 1.0;
            ELSIF v_events_today = 1 THEN v_diminishing_multiplier := 0.90;
            ELSIF v_events_today = 2 THEN v_diminishing_multiplier := 0.75;
            ELSE v_diminishing_multiplier := 0.60;
            END IF;
            
            SELECT COALESCE(SUM(xp_earned), 0) INTO v_daily_earned
            FROM public.xp_events
            WHERE user_id = p_user_id AND created_at >= CURRENT_DATE;

            IF v_daily_earned >= 120 THEN
                v_soft_cap_multiplier := 0.5;
            END IF;
        END IF;

        -- Applied all internal multipliers + external orchestrator multiplier
        v_final_amount := ROUND((v_final_amount * v_quality_multiplier * v_tier_multiplier * v_streak_multiplier * v_diminishing_multiplier * v_soft_cap_multiplier * COALESCE(v_orch_xp_mult, 1.0)) + (v_bonus_xp * v_soft_cap_multiplier));
    END IF;

    v_details := jsonb_build_object(
        'base_amount', p_amount,
        'bonus_xp', v_bonus_xp,
        'streak', v_current_streak,
        'streak_multiplier', v_streak_multiplier,
        'quality_multiplier', v_quality_multiplier,
        'tier_multiplier', v_tier_multiplier,
        'diminishing_multiplier', v_diminishing_multiplier,
        'soft_cap_multiplier', v_soft_cap_multiplier,
        'orch_xp_mult', v_orch_xp_mult,
        'is_no_show', p_is_no_show,
        'abuse_status', p_abuse_status
    );

    INSERT INTO public.xp_events (user_id, xp_earned, source, details, idempotency_key)
    VALUES (p_user_id, v_final_amount::INTEGER, p_source, v_details, p_idempotency_key);

    v_new_xp := v_current_xp + v_final_amount::INTEGER;
    v_new_level := (v_new_xp / 1000) + 1;

    IF NOT EXISTS (SELECT 1 FROM public.user_xp WHERE user_id = p_user_id) THEN
        INSERT INTO public.user_xp (user_id, xp_amount, current_level, current_streak, last_activity_date, weekly_xp)
        VALUES (p_user_id, v_new_xp, v_new_level, v_current_streak, v_today, v_final_amount::INTEGER);
    ELSE
        UPDATE public.user_xp
        SET xp_amount = v_new_xp,
            current_level = v_new_level,
            current_streak = v_current_streak,
            last_activity_date = v_today,
            weekly_xp = COALESCE(weekly_xp, 0) + v_final_amount::INTEGER,
            updated_at = timezone('utc'::text, now())
        WHERE user_id = p_user_id;
    END IF;
END;
$$;

-- 6. TRUST EVENTS DISPATCHER (@Referee utility)
CREATE OR REPLACE FUNCTION public.log_trust_event(
    p_user_id UUID,
    p_event_type TEXT,
    p_category TEXT,
    p_delta INTEGER,
    p_note TEXT DEFAULT ''
) RETURNS void 
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.trust_events (user_id, event_type, category, delta, note)
    VALUES (p_user_id, p_event_type, p_category, p_delta, p_note);

    -- Apply changes to sub-scores instead of raw trust_score directly
    IF p_category = 'reliability' THEN
        UPDATE public.profiles SET reliability_score = GREATEST(0, LEAST(100, COALESCE(reliability_score, 0) + p_delta)) WHERE id = p_user_id;
    ELSIF p_category = 'social' THEN
        UPDATE public.profiles SET social_score = GREATEST(0, LEAST(100, COALESCE(social_score, 0) + p_delta)) WHERE id = p_user_id;
    ELSIF p_category = 'activity' THEN
        UPDATE public.profiles SET activity_score = GREATEST(0, LEAST(100, COALESCE(activity_score, 0) + p_delta)) WHERE id = p_user_id;
    END IF;

    -- Trigger the canonical recalculation from trust_system_2.sql
    PERFORM public.recalculate_trust_score(p_user_id);
END;
$$;

-- 7. REFACTOR UNIFIED PROGRESSION (IDEMPOTENT COORDINATOR)
CREATE OR REPLACE FUNCTION public.process_unified_event_outcome(
    p_user_id UUID,
    p_event_id UUID,
    p_role TEXT,                 
    p_has_joined BOOLEAN,        
    p_has_checked_in BOOLEAN,    
    p_is_completed BOOLEAN,      
    p_quality_rating NUMERIC,    
    p_abuse_status TEXT DEFAULT 'normal' 
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_base_xp INTEGER := 0;
    v_base_mf INTEGER := 0;
    v_trust_delta INTEGER := 0;
    v_idemp_key TEXT := p_event_id::TEXT || '_' || p_user_id::TEXT || '_' || p_role;
BEGIN
    -- STEP 1: XP ENGINE (Delegation)
    IF p_role = 'host' THEN
        v_base_xp := 45; 
        v_base_mf := 10;
    ELSE
        v_base_xp := 40; 
        v_base_mf := 10;
    END IF;

    -- Call @XPEngine
    PERFORM public.add_user_xp(
        p_user_id, 
        v_base_xp, 
        'event_completed', 
        'B', 
        CASE WHEN p_quality_rating >= 1.2 THEN 'good' WHEN p_quality_rating <= 0.8 THEN 'bad' ELSE 'normal' END,
        false, 0, false, 0, false, 
        (p_has_joined AND NOT p_has_checked_in), 
        p_abuse_status,
        v_idemp_key
    );

    -- STEP 2: TRUST ENGINE (Delegation via Referee)
    IF p_has_joined AND NOT p_has_checked_in THEN
        v_trust_delta := -10;
        PERFORM public.log_trust_event(p_user_id, 'no_show', 'reliability', v_trust_delta, 'Event no-show via unified progression');
    ELSE
        IF p_has_checked_in THEN v_trust_delta := v_trust_delta + 2; END IF;
        IF p_is_completed THEN v_trust_delta := v_trust_delta + 2; END IF;
        IF p_quality_rating >= 1.2 THEN v_trust_delta := v_trust_delta + 3; END IF;
        
        IF v_trust_delta > 0 THEN
            PERFORM public.log_trust_event(p_user_id, 'event_completed', 'reliability', v_trust_delta, 'Successful participation');
        END IF;
    END IF;

    -- STEP 3: ECONOMY ENGINE (Delegation)
    IF p_is_completed AND p_has_checked_in AND NOT p_abuse_status IN ('suspicious', 'confirmed_abuse') THEN
        PERFORM public.add_mf_points(
            p_user_id, 
            v_base_mf, 
            'event_completed', 
            'Unified Event Reward',
            v_idemp_key
        );
    END IF;

    RETURN jsonb_build_object(
        'status', 'processed',
        'event_id', p_event_id,
        'base_xp_sent', v_base_xp,
        'base_mf_sent', v_base_mf,
        'trust_delta_sent', v_trust_delta
    );
END;
$$;
