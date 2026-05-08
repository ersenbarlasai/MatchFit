-- ==============================================================================
-- MATCHFIT FRAUD DETECTION FOUNDATION
-- @FraudDetection Agent System
-- ==============================================================================

-- 1. FRAUD SIGNALS (Event-based suspicious activity)
CREATE TABLE IF NOT EXISTS public.fraud_signals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  source_agent TEXT NOT NULL, -- e.g. '@Guardian', '@ContextAgent'
  signal_type TEXT NOT NULL,   -- e.g. 'bad_word', 'iban_detected', 'location_spoof'
  severity TEXT DEFAULT 'low', -- low, medium, high, critical
  confidence NUMERIC DEFAULT 1.0,
  event_id UUID REFERENCES public.events(id) ON DELETE SET NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  idempotency_key TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fraud_signals_idempotency_key
  ON public.fraud_signals (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- 2. RISK SCORES (Aggregated state for high-performance reading)
CREATE TABLE IF NOT EXISTS public.risk_scores (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  score INTEGER NOT NULL DEFAULT 0,
  risk_level TEXT DEFAULT 'clear', -- clear, suspicious, high_risk, blocked
  last_signal_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- 3. FRAUD CASES (Investigation state for admins/moderators)
CREATE TABLE IF NOT EXISTS public.fraud_cases (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'open', -- open, under_review, resolved, dismissed
  opened_reason TEXT,
  risk_score INTEGER,
  recommended_action TEXT,
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  opened_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  closed_at TIMESTAMPTZ
);

-- 4. RLS POLICIES (Internal Agent Security)
ALTER TABLE public.fraud_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraud_cases ENABLE ROW LEVEL SECURITY;

-- Users can see their own risk score summary for transparency, but not individual signals
DROP POLICY IF EXISTS "Users can view their own risk score" ON public.risk_scores;
CREATE POLICY "Users can view their own risk score"
  ON public.risk_scores FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- INSERTs to signals are prohibited from client side, must use log_fraud_signal RPC
DROP POLICY IF EXISTS "Agent only insert signals" ON public.fraud_signals;
CREATE POLICY "Agent only insert signals" ON public.fraud_signals
  FOR INSERT WITH CHECK (false);

-- 5. RPC CONTRACTS

-- recompute_user_risk_score (Internal aggregator)
CREATE OR REPLACE FUNCTION public.recompute_user_risk_score(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_score INTEGER := 0;
  v_level TEXT := 'clear';
BEGIN
  -- Weighted risk calculation
  SELECT 
    COALESCE(SUM(
      CASE 
        WHEN severity = 'critical' THEN 50
        WHEN severity = 'high' THEN 25
        WHEN severity = 'medium' THEN 10
        ELSE 5
      END
    ), 0)
  INTO v_score
  FROM public.fraud_signals
  WHERE user_id = p_user_id;

  -- Resolve Level
  IF v_score >= 100 THEN v_level := 'blocked';
  ELSIF v_score >= 50 THEN v_level := 'high_risk';
  ELSIF v_score >= 15 THEN v_level := 'suspicious';
  ELSE v_level := 'clear';
  END IF;

  INSERT INTO public.risk_scores (user_id, score, risk_level, last_signal_at, updated_at)
  VALUES (p_user_id, v_score, v_level, now(), now())
  ON CONFLICT (user_id) DO UPDATE
  SET 
    score = EXCLUDED.score,
    risk_level = EXCLUDED.risk_level,
    last_signal_at = EXCLUDED.last_signal_at,
    updated_at = EXCLUDED.updated_at;

  -- Automatically open a Fraud Case for High Risk users
  IF v_score >= 50 AND NOT EXISTS (SELECT 1 FROM public.fraud_cases WHERE user_id = p_user_id AND status IN ('open', 'under_review')) THEN
    INSERT INTO public.fraud_cases (user_id, opened_reason, risk_score, recommended_action)
    VALUES (p_user_id, 'High risk score threshold reached: ' || v_score, v_score, 'Audit user activity and apply restrictions if needed');
  END IF;
END;
$$;

-- log_fraud_signal (Public facing agent contract)
CREATE OR REPLACE FUNCTION public.log_fraud_signal(
    p_user_id UUID,
    p_source_agent TEXT,
    p_signal_type TEXT,
    p_severity TEXT DEFAULT 'low',
    p_confidence NUMERIC DEFAULT 1.0,
    p_event_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_signal_id UUID;
BEGIN
  -- Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_signal_id FROM public.fraud_signals WHERE idempotency_key = p_idempotency_key;
    IF v_signal_id IS NOT NULL THEN RETURN v_signal_id; END IF;
  END IF;

  INSERT INTO public.fraud_signals (
    user_id, source_agent, signal_type, severity, confidence, event_id, metadata, idempotency_key
  )
  VALUES (
    p_user_id, p_source_agent, p_signal_type, p_severity, p_confidence, p_event_id, p_metadata, p_idempotency_key
  )
  RETURNING id INTO v_signal_id;

  -- Async-like recomputation
  PERFORM public.recompute_user_risk_score(p_user_id);

  RETURN v_signal_id;
END;
$$;

-- get_user_risk_summary (Reader contract for other agents)
CREATE OR REPLACE FUNCTION public.get_user_risk_summary(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_summary JSONB;
BEGIN
  SELECT jsonb_build_object(
    'user_id', user_id,
    'score', score,
    'risk_level', risk_level,
    'last_signal_at', last_signal_at,
    'is_blocked', (risk_level = 'blocked')
  )
  INTO v_summary
  FROM public.risk_scores
  WHERE user_id = p_user_id;

  RETURN COALESCE(v_summary, jsonb_build_object('user_id', p_user_id, 'score', 0, 'risk_level', 'clear', 'is_blocked', false));
END;
$$;

-- 6. GRANTS
GRANT EXECUTE ON FUNCTION public.get_user_risk_summary(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_fraud_signal(UUID, TEXT, TEXT, TEXT, NUMERIC, UUID, JSONB, TEXT) TO authenticated;
