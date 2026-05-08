-- ==============================================================================
-- MATCHFIT ANALYTICS AGENT FOUNDATION
-- @AnalyticsAgent Agent System
-- ==============================================================================

-- 1. ANALYTICS EVENTS (Central telemetry store)
CREATE TABLE IF NOT EXISTS public.analytics_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_name TEXT NOT NULL,
  event_type TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_id UUID, -- Correlation ID from the source agent
  subject_type TEXT, -- e.g. event, user, reward, campaign
  subject_id UUID,
  severity TEXT DEFAULT 'info', -- info, warning, error, critical
  metrics JSONB DEFAULT '{}'::jsonb, -- Numeric/Performance data
  metadata JSONB DEFAULT '{}'::jsonb, -- Contextual labels
  idempotency_key TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  UNIQUE(idempotency_key)
);

-- 2. DAILY AGENT HEALTH (Aggregated health snapshots)
CREATE TABLE IF NOT EXISTS public.daily_agent_health (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_name TEXT NOT NULL,
  snapshot_date DATE NOT NULL,
  event_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  warning_count INTEGER DEFAULT 0,
  avg_metric_value NUMERIC, -- Performance benchmark
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  UNIQUE(agent_name, snapshot_date)
);

-- 3. RLS POLICIES
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_agent_health ENABLE ROW LEVEL SECURITY;

-- Raw analytics events are restricted to Admin/Service role or secure RPCs.
-- User context is preserved for aggregation, but direct access is blocked.

-- Daily health summary is visible to users for system transparency (status page).
CREATE POLICY "Public view for agent health summary" ON public.daily_agent_health 
  FOR SELECT TO authenticated USING (true);

-- 4. RPC CONTRACTS

-- log_analytics_event (The central event collector)
CREATE OR REPLACE FUNCTION public.log_analytics_event(
    p_agent_name TEXT,
    p_event_type TEXT,
    p_user_id UUID DEFAULT NULL,
    p_event_id UUID DEFAULT NULL,
    p_subject_type TEXT DEFAULT NULL,
    p_subject_id UUID DEFAULT NULL,
    p_severity TEXT DEFAULT 'info',
    p_metrics JSONB DEFAULT '{}'::jsonb,
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
    -- 1. Idempotency Check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_event_id FROM public.analytics_events WHERE idempotency_key = p_idempotency_key;
        IF v_event_id IS NOT NULL THEN
            RETURN v_event_id;
        END IF;
    END IF;

    -- 2. Insert Event
    INSERT INTO public.analytics_events (
        agent_name, event_type, user_id, event_id, subject_type, subject_id, severity, metrics, metadata, idempotency_key
    )
    VALUES (
        p_agent_name, 
        p_event_type, 
        COALESCE(p_user_id, auth.uid()), 
        p_event_id, 
        p_subject_type, 
        p_subject_id, 
        p_severity, 
        p_metrics, 
        p_metadata, 
        p_idempotency_key
    )
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$;

-- build_daily_agent_health (Periodic aggregator for dashboarding)
CREATE OR REPLACE FUNCTION public.build_daily_agent_health(p_snapshot_date DATE DEFAULT current_date)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.daily_agent_health (agent_name, snapshot_date, event_count, error_count, warning_count, metadata, created_at)
    SELECT 
        agent_name,
        p_snapshot_date,
        COUNT(*),
        COUNT(*) FILTER (WHERE severity IN ('error', 'critical')),
        COUNT(*) FILTER (WHERE severity = 'warning'),
        jsonb_build_object('last_updated', now(), 'aggregator', 'AnalyticsAgent'),
        now()
    FROM public.analytics_events
    WHERE created_at::date = p_snapshot_date
    GROUP BY agent_name
    ON CONFLICT (agent_name, snapshot_date) DO UPDATE
    SET 
        event_count = EXCLUDED.event_count,
        error_count = EXCLUDED.error_count,
        warning_count = EXCLUDED.warning_count,
        metadata = daily_agent_health.metadata || EXCLUDED.metadata,
        created_at = EXCLUDED.created_at;
END;
$$;

-- get_agent_health_summary (Admin/Release Commander interface)
CREATE OR REPLACE FUNCTION public.get_agent_health_summary(p_snapshot_date DATE DEFAULT current_date)
RETURNS TABLE (
    agent_name TEXT,
    event_count INTEGER,
    error_count INTEGER,
    warning_count INTEGER,
    status TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        agent_name,
        event_count,
        error_count,
        warning_count,
        CASE 
            WHEN error_count > 0 THEN 'unhealthy'
            WHEN warning_count > 10 THEN 'degraded'
            ELSE 'healthy'
        END as status
    FROM public.daily_agent_health
    WHERE snapshot_date = p_snapshot_date;
$$;

-- 5. GRANTS
GRANT EXECUTE ON FUNCTION public.log_analytics_event(TEXT, TEXT, UUID, UUID, TEXT, UUID, TEXT, JSONB, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_agent_health_summary(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.build_daily_agent_health(DATE) TO authenticated;
