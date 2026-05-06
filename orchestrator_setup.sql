-- ==============================================================================
-- @Orchestrator Agent Veritabanı Kurulumu (Supabase SQL Editor)
-- Tüm sistemin CEO'su: Parametreleri, limitleri ve çarpanları yönetir.
-- ==============================================================================

-- 1. SYSTEM PARAMETERS (Orchestrator'ın yönettiği tablo)
CREATE TABLE IF NOT EXISTS public.orchestrator_config (
    id INTEGER PRIMARY KEY DEFAULT 1,
    xp_multiplier NUMERIC NOT NULL DEFAULT 1.0,
    mf_multiplier NUMERIC NOT NULL DEFAULT 1.0,
    reward_price_factor NUMERIC NOT NULL DEFAULT 1.0,
    abuse_sensitivity NUMERIC NOT NULL DEFAULT 1.0,
    
    -- Dinamik Limitler ve Base Puanlar
    base_xp_join INTEGER NOT NULL DEFAULT 15,
    base_xp_create INTEGER NOT NULL DEFAULT 20,
    base_xp_checkin INTEGER NOT NULL DEFAULT 10,
    base_xp_complete INTEGER NOT NULL DEFAULT 15,
    
    base_mf_event INTEGER NOT NULL DEFAULT 5,
    base_mf_checkin INTEGER NOT NULL DEFAULT 2,
    daily_mf_cap INTEGER NOT NULL DEFAULT 100,
    
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.orchestrator_config ENABLE ROW LEVEL SECURITY;

-- Sadece sistem/admin değiştirebilir, herkes okuyabilir
DROP POLICY IF EXISTS "Anyone can read orchestrator config" ON public.orchestrator_config;
CREATE POLICY "Anyone can read orchestrator config"
ON public.orchestrator_config FOR SELECT
TO authenticated
USING (true);

-- Tablonun tek satırlı (Singleton) olmasını garantile
INSERT INTO public.orchestrator_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- 2. ORCHESTRATOR UPDATE FONKSİYONU
CREATE OR REPLACE FUNCTION public.update_orchestrator_config(
    p_xp_multiplier NUMERIC DEFAULT NULL,
    p_mf_multiplier NUMERIC DEFAULT NULL,
    p_reward_price_factor NUMERIC DEFAULT NULL,
    p_abuse_sensitivity NUMERIC DEFAULT NULL,
    p_daily_mf_cap INTEGER DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.orchestrator_config
    SET 
        xp_multiplier = COALESCE(p_xp_multiplier, xp_multiplier),
        mf_multiplier = COALESCE(p_mf_multiplier, mf_multiplier),
        reward_price_factor = COALESCE(p_reward_price_factor, reward_price_factor),
        abuse_sensitivity = COALESCE(p_abuse_sensitivity, abuse_sensitivity),
        daily_mf_cap = COALESCE(p_daily_mf_cap, daily_mf_cap),
        updated_at = timezone('utc'::text, now())
    WHERE id = 1;
END;
$$;

-- 3. SYSTEM HEALTH METRICS (Orchestrator'ın okuyup karar vereceği Data)
CREATE OR REPLACE FUNCTION public.get_system_health_metrics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dau INTEGER;
    v_avg_xp NUMERIC;
    v_avg_mf NUMERIC;
    v_avg_trust NUMERIC;
    v_no_show_rate NUMERIC;
    v_total_events INTEGER;
    v_total_no_shows INTEGER;
BEGIN
    -- DAU (Daily Active Users)
    SELECT COUNT(DISTINCT user_id) INTO v_dau
    FROM public.user_xp 
    WHERE last_activity_date = CURRENT_DATE;

    -- AVG XP
    SELECT COALESCE(AVG(xp_amount), 0) INTO v_avg_xp FROM public.user_xp;

    -- AVG MF
    SELECT COALESCE(AVG(balance), 0) INTO v_avg_mf FROM public.user_mf_balance;

    -- AVG Trust
    SELECT COALESCE(AVG(trust_score), 0) INTO v_avg_trust FROM public.profiles;

    -- No-Show Rate (Son 7 Gün)
    SELECT COUNT(*) INTO v_total_events
    FROM public.event_participants ep
    JOIN public.events e ON ep.event_id = e.id
    WHERE e.event_date >= CURRENT_DATE - INTERVAL '7 days';

    SELECT COUNT(*) INTO v_total_no_shows
    FROM public.trust_events
    WHERE event_type = 'unified_outcome' AND note ILIKE '%no-show%' AND created_at >= CURRENT_DATE - INTERVAL '7 days';

    IF v_total_events > 0 THEN
        v_no_show_rate := (v_total_no_shows::NUMERIC / v_total_events::NUMERIC) * 100;
    ELSE
        v_no_show_rate := 0;
    END IF;

    RETURN jsonb_build_object(
        'dau', v_dau,
        'avg_xp', ROUND(v_avg_xp, 2),
        'avg_mf', ROUND(v_avg_mf, 2),
        'avg_trust', ROUND(v_avg_trust, 2),
        'no_show_rate_percent', ROUND(v_no_show_rate, 2),
        'timestamp', timezone('utc'::text, now())
    );
END;
$$;
