-- ==============================================================================
-- MATCHFIT - UNIFIED PROGRESSION ENGINE
-- @Referee (Owner) orchestrates the outcome, calling @XPEngine and @EconomyEngine
-- ==============================================================================

-- 1. MASTER EVENT SCORE & ORCHESTRATION FUNCTION
CREATE OR REPLACE FUNCTION public.process_unified_event_outcome(
    p_user_id UUID,
    p_event_id UUID,
    p_role TEXT,                 -- 'host' or 'participant'
    p_has_joined BOOLEAN,        -- Katıldı mı?
    p_has_checked_in BOOLEAN,    -- Check-in yaptı mı?
    p_is_completed BOOLEAN,      -- Maç gerçekten oynandı/tamamlandı mı?
    p_quality_rating NUMERIC,    -- 0.7 (kötü) ile 1.4 (mükemmel) arası (feedback vs. ile hesaplanır)
    p_abuse_status TEXT DEFAULT 'normal' -- 'normal', 'suspicious', 'abuse'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- Master Score Components
    v_participation NUMERIC := 0.0;
    v_quality NUMERIC := p_quality_rating;
    v_integrity NUMERIC := 1.0;
    v_consistency NUMERIC := 1.0;
    v_event_score NUMERIC := 0.0;
    
    -- Sub-System Results
    v_xp_earned INTEGER := 0;
    v_trust_delta INTEGER := 0;
    v_mf_earned INTEGER := 0;
    
    -- Intermediate variables
    v_base_xp INTEGER := 0;
    v_base_mf INTEGER := 0;
    v_anti_abuse_xp NUMERIC := 1.0;
    
    -- Orchestrator Config Variables
    v_orch_xp_mult NUMERIC := 1.0;
    v_orch_mf_mult NUMERIC := 1.0;
    v_orch_abuse_sens NUMERIC := 1.0;
    v_orch_daily_cap INTEGER := 100;
    
    v_current_trust INTEGER := 100;
    v_streak INTEGER := 0;
    
    v_trust_behavior INTEGER := 0;
    v_trust_penalty INTEGER := 0;
    
    v_economy_factor NUMERIC := 1.0;
    v_daily_mf INTEGER := 0;
BEGIN
    ---------------------------------------------------------------------------
    -- STEP 1: FETCH CONTEXT (Profiles, XP, Economy, Orchestrator Config)
    ---------------------------------------------------------------------------
    SELECT COALESCE(trust_score, 100) INTO v_current_trust
    FROM public.profiles WHERE id = p_user_id;
    
    SELECT COALESCE(current_streak, 0) INTO v_streak
    FROM public.user_xp WHERE user_id = p_user_id;

    SELECT xp_multiplier, mf_multiplier, abuse_sensitivity, daily_mf_cap
    INTO v_orch_xp_mult, v_orch_mf_mult, v_orch_abuse_sens, v_orch_daily_cap
    FROM public.orchestrator_config WHERE id = 1;

    ---------------------------------------------------------------------------
    -- STEP 2: CALCULATE EVENT SCORE COMPONENTS
    ---------------------------------------------------------------------------
    -- Participation (Hepsi tamsa 1, yoksa 0)
    IF p_has_joined AND p_has_checked_in AND p_is_completed THEN
        v_participation := 1.0;
    ELSE
        v_participation := 0.0;
    END IF;

    -- Integrity (Geçmiş davranış & Trust Score)
    IF v_current_trust >= 80 THEN v_integrity := 1.2;
    ELSIF v_current_trust >= 50 THEN v_integrity := 1.0;
    ELSIF v_current_trust >= 20 THEN v_integrity := 0.7;
    ELSE v_integrity := 0.5;
    END IF;

    -- Consistency (Streak Bonus)
    IF v_streak >= 30 THEN v_consistency := 1.25;
    ELSIF v_streak >= 10 THEN v_consistency := 1.12;
    ELSIF v_streak >= 5 THEN v_consistency := 1.07;
    ELSIF v_streak >= 2 THEN v_consistency := 1.03;
    ELSE v_consistency := 1.0;
    END IF;

    -- MASTER EVENT SCORE
    v_event_score := v_participation * v_quality * v_integrity * v_consistency;

    ---------------------------------------------------------------------------
    -- STEP 3: XP ENGINE (İlerleme)
    ---------------------------------------------------------------------------
    IF p_role = 'host' THEN
        v_base_xp := 20 + 10 + 15; -- Create + Checkin + Complete = 45 Base
    ELSE
        v_base_xp := 15 + 10 + 15; -- Join + Checkin + Complete = 40 Base
    END IF;

    IF p_abuse_status = 'abuse' THEN v_anti_abuse_xp := GREATEST(0.1, 0.4 / v_orch_abuse_sens);
    ELSIF p_abuse_status = 'suspicious' THEN v_anti_abuse_xp := GREATEST(0.4, 0.7 / v_orch_abuse_sens);
    ELSE v_anti_abuse_xp := 1.0;
    END IF;

    -- Apply Orchestrator's Global XP Multiplier
    v_xp_earned := ROUND(v_base_xp * v_event_score * v_anti_abuse_xp * v_orch_xp_mult);
    
    -- Call @XPEngine (Mevcut add_user_xp fonksiyonunu çağırmak yerine direkt burada veya 
    -- o fonksiyona paslanabilir. Biz direkt entegre yapıyoruz).
    IF v_xp_earned > 0 THEN
        PERFORM public.add_user_xp(
            p_user_id, 
            v_xp_earned, 
            'event_completed', 
            'B', -- default tier
            CASE WHEN v_quality >= 1.2 THEN 'good' WHEN v_quality <= 0.8 THEN 'bad' ELSE 'normal' END,
            false, 0, false, 0, false, 
            (p_has_joined AND NOT p_has_checked_in), -- is_no_show
            p_abuse_status
        );
    END IF;

    ---------------------------------------------------------------------------
    -- STEP 4: TRUST ENGINE (Davranış) - Bağımsız Çalışır
    ---------------------------------------------------------------------------
    IF p_has_checked_in THEN v_trust_behavior := v_trust_behavior + 2; END IF;
    IF p_is_completed THEN v_trust_behavior := v_trust_behavior + 2; END IF;
    IF v_quality >= 1.2 THEN v_trust_behavior := v_trust_behavior + 3; END IF; -- Positive feedback proxy

    -- Penalty
    IF p_has_joined AND NOT p_has_checked_in THEN
        v_trust_penalty := 10; -- no-show
    END IF;
    IF p_abuse_status = 'abuse' THEN
        v_trust_penalty := v_trust_penalty + 15;
    END IF;

    v_trust_delta := v_trust_behavior - v_trust_penalty;

    -- Update Profiles
    UPDATE public.profiles 
    SET trust_score = GREATEST(0, LEAST(100, COALESCE(trust_score, 100) + v_trust_delta))
    WHERE id = p_user_id;
    
    -- Insert Trust Event
    IF v_trust_delta != 0 THEN
        INSERT INTO public.trust_events (user_id, event_type, category, delta, note)
        VALUES (p_user_id, 'unified_outcome', 'reliability', v_trust_delta, 'EventScore based delta');
    END IF;

    ---------------------------------------------------------------------------
    -- STEP 5: ECONOMY ENGINE (MF Points)
    ---------------------------------------------------------------------------
    IF p_role = 'host' THEN v_base_mf := 5 + 2 + 3; -- create, checkin, feedback
    ELSE v_base_mf := 5 + 2 + 3; END IF;

    -- Günlük Cap Kontrolü (Orchestrator Config'ten alınır)
    SELECT COALESCE(SUM(amount), 0) INTO v_daily_mf
    FROM public.mf_point_ledger
    WHERE user_id = p_user_id AND created_at >= CURRENT_DATE AND amount > 0;

    -- Inflation / Economy Factor (Basitçe streak ve günlük cap'e bakar)
    IF v_daily_mf >= v_orch_daily_cap THEN
        v_economy_factor := 0.0; -- Cap reached
    ELSIF v_daily_mf >= (v_orch_daily_cap / 2) THEN
        v_economy_factor := 0.8; -- Inflation risk
    ELSIF v_streak <= 1 THEN
        v_economy_factor := 1.2; -- Low activity, encourage
    ELSE
        v_economy_factor := 1.0; -- Normal
    END IF;

    -- Apply Orchestrator's Global MF Multiplier
    v_mf_earned := ROUND(v_base_mf * v_event_score * v_economy_factor * v_orch_mf_mult);
    
    -- Günlük limiti aşmamasını garantile
    IF (v_daily_mf + v_mf_earned) > v_orch_daily_cap THEN
        v_mf_earned := v_orch_daily_cap - v_daily_mf;
    END IF;

    IF v_mf_earned > 0 THEN
        PERFORM public.add_mf_points(p_user_id, v_mf_earned, 'event_completed', 'Unified Event Reward');
    END IF;

    ---------------------------------------------------------------------------
    -- STEP 6: RANK SCORE (Zaten vw_leaderboard üzerinden dinamik hesaplanır)
    ---------------------------------------------------------------------------
    -- The vw_leaderboard view already calculates Rank Score automatically 
    -- based on the updated XP and Trust!

    ---------------------------------------------------------------------------
    -- RETURN RESULT PAYLOAD
    ---------------------------------------------------------------------------
    RETURN jsonb_build_object(
        'xp_earned', v_xp_earned,
        'trust_delta', v_trust_delta,
        'mf_earned', v_mf_earned,
        'event_score', v_event_score,
        'components', jsonb_build_object(
            'participation', v_participation,
            'quality', v_quality,
            'integrity', v_integrity,
            'consistency', v_consistency
        )
    );
END;
$$;
