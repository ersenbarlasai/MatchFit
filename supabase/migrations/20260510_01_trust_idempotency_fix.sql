-- ==============================================================================
-- MATCHFIT ENGINE CONFLICT RESOLUTION - P1 FOLLOW-UP
-- Trust Events Idempotency Fix
-- ==============================================================================

-- 1. ADD IDEMPOTENCY KEY TO TRUST EVENTS
ALTER TABLE public.trust_events ADD COLUMN IF NOT EXISTS idempotency_key TEXT UNIQUE;

-- 2. UPDATE TRUST DISPATCHER TO SUPPORT IDEMPOTENCY
CREATE OR REPLACE FUNCTION public.log_trust_event(
    p_user_id UUID,
    p_event_type TEXT,
    p_category TEXT,
    p_delta INTEGER,
    p_note TEXT DEFAULT '',
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS jsonb 
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.trust_events WHERE idempotency_key = p_idempotency_key) THEN
            RETURN jsonb_build_object('status', 'skipped', 'reason', 'duplicate_idempotency_key');
        END IF;
    END IF;

    INSERT INTO public.trust_events (user_id, event_type, category, delta, note, idempotency_key)
    VALUES (p_user_id, p_event_type, p_category, p_delta, p_note, p_idempotency_key);

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

    RETURN jsonb_build_object('status', 'success', 'delta', p_delta);
END;
$$;

-- 3. REFACTOR UNIFIED PROGRESSION WITH ISOLATED IDEMPOTENCY KEYS
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
    
    -- Specific Canonical Keys for isolation
    v_idemp_key_xp TEXT := 'event_outcome:' || p_event_id::TEXT || ':' || p_user_id::TEXT || ':xp';
    v_idemp_key_mf TEXT := 'event_outcome:' || p_event_id::TEXT || ':' || p_user_id::TEXT || ':mf';
    v_idemp_key_trust TEXT := 'event_outcome:' || p_event_id::TEXT || ':' || p_user_id::TEXT || ':trust';
BEGIN
    -- STEP 1: XP ENGINE (Delegation)
    IF p_role = 'host' THEN
        v_base_xp := 45; 
        v_base_mf := 10;
    ELSE
        v_base_xp := 40; 
        v_base_mf := 10;
    END IF;

    PERFORM public.add_user_xp(
        p_user_id, 
        v_base_xp, 
        'event_completed', 
        'B', 
        CASE WHEN p_quality_rating >= 1.2 THEN 'good' WHEN p_quality_rating <= 0.8 THEN 'bad' ELSE 'normal' END,
        false, 0, false, 0, false, 
        (p_has_joined AND NOT p_has_checked_in), 
        p_abuse_status,
        v_idemp_key_xp
    );

    -- STEP 2: TRUST ENGINE (Delegation via Referee)
    IF p_has_joined AND NOT p_has_checked_in THEN
        v_trust_delta := -10;
        PERFORM public.log_trust_event(p_user_id, 'no_show', 'reliability', v_trust_delta, 'Event no-show via unified progression', v_idemp_key_trust);
    ELSE
        IF p_has_checked_in THEN v_trust_delta := v_trust_delta + 2; END IF;
        IF p_is_completed THEN v_trust_delta := v_trust_delta + 2; END IF;
        IF p_quality_rating >= 1.2 THEN v_trust_delta := v_trust_delta + 3; END IF;
        
        IF v_trust_delta > 0 THEN
            PERFORM public.log_trust_event(p_user_id, 'event_completed', 'reliability', v_trust_delta, 'Successful participation', v_idemp_key_trust);
        END IF;
    END IF;

    -- STEP 3: ECONOMY ENGINE (Delegation)
    IF p_is_completed AND p_has_checked_in AND NOT p_abuse_status IN ('suspicious', 'confirmed_abuse') THEN
        PERFORM public.add_mf_points(
            p_user_id, 
            v_base_mf, 
            'event_completed', 
            'Unified Event Reward',
            v_idemp_key_mf
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
