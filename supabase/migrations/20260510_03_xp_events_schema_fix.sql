-- ==============================================================================
-- MATCHFIT ENGINE CONFLICT RESOLUTION - P1 FOLLOW-UP 2
-- XP Events Schema Drift Fix
-- ==============================================================================

-- 1. ADD MISSING COLUMNS DUE TO SCHEMA DRIFT
ALTER TABLE public.xp_events ADD COLUMN IF NOT EXISTS details JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.xp_events ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE public.xp_events ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'unknown';
ALTER TABLE public.xp_events ADD COLUMN IF NOT EXISTS xp_earned INTEGER DEFAULT 0;
ALTER TABLE public.xp_events ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- 2. ADD PARTIAL UNIQUE INDEX FOR IDEMPOTENCY KEY
-- This handles idempotency gracefully while ignoring NULLs
CREATE UNIQUE INDEX IF NOT EXISTS xp_events_idempotency_key_idx 
ON public.xp_events(idempotency_key) 
WHERE idempotency_key IS NOT NULL;

-- 3. ENSURE ADD_USER_XP FUNCTION MATCHES SCHEMA
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
