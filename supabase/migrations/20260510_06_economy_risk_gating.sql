-- ==============================================================================
-- MATCHFIT ECONOMY RISK GATING & REDEMPTION
-- @EconomyEngine & @FraudDetection Integration
-- ==============================================================================

-- 1. REDEMPTION ATTEMPTS (Tracking reward requests)
CREATE TABLE IF NOT EXISTS public.redemption_attempts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_id UUID, -- Nullable until PartnerCatalog is integrated
  amount INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  rejection_reason TEXT,
  risk_level TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  idempotency_key TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_redemption_attempts_idempotency_key
  ON public.redemption_attempts (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- RLS: Users can view their own attempts
ALTER TABLE public.redemption_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own redemption attempts" ON public.redemption_attempts;
CREATE POLICY "Users can view their own redemption attempts"
  ON public.redemption_attempts FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- 2. UPDATED add_mf_points WITH RISK GATING
-- This version reads risk_scores to enforce gating and caps.
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
SET search_path = public
AS $$
DECLARE
  v_current_balance INTEGER;
  v_new_balance INTEGER;
  v_total_earned INTEGER;
  v_daily_earned INTEGER;
  v_daily_cap INTEGER := 100;
  v_effective_amount INTEGER := p_amount;
  v_risk_level TEXT := 'clear';
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User id is required.';
  END IF;

  -- 1. Idempotency Check
  IF p_idempotency_key IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM public.mf_point_ledger
       WHERE idempotency_key = p_idempotency_key
     ) THEN
    RETURN;
  END IF;

  -- 2. Fraud Risk Gating
  -- Get risk level from @FraudDetection agent's state
  SELECT risk_level INTO v_risk_level FROM public.risk_scores WHERE user_id = p_user_id;
  v_risk_level := COALESCE(v_risk_level, 'clear');

  IF p_amount > 0 THEN
    -- Blocked or High Risk users cannot earn points
    IF v_risk_level IN ('blocked', 'high_risk') THEN
      RETURN;
    END IF;
  ELSE
    -- Blocked users cannot redeem/spend points
    IF v_risk_level = 'blocked' THEN
      RAISE EXCEPTION 'Blocked users cannot spend points.';
    END IF;
  END IF;

  -- 3. Daily Cap Logic (Orchestrator defined)
  SELECT COALESCE(daily_mf_cap, 100) INTO v_daily_cap FROM public.orchestrator_config WHERE id = 1;
  
  -- Suspicious users get a 50% penalty on daily earning cap
  IF v_risk_level = 'suspicious' THEN
    v_daily_cap := v_daily_cap / 2;
  END IF;

  -- 4. Balance State Management
  SELECT balance, total_earned INTO v_current_balance, v_total_earned FROM public.user_mf_balance WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    v_current_balance := 0;
    v_total_earned := 0;
    INSERT INTO public.user_mf_balance (user_id, balance, total_earned) VALUES (p_user_id, 0, 0);
  END IF;

  -- Earning Cap Enforcement (Only for positive amounts)
  IF p_amount > 0 THEN
    SELECT COALESCE(SUM(amount), 0) INTO v_daily_earned FROM public.mf_point_ledger WHERE user_id = p_user_id AND amount > 0 AND created_at >= CURRENT_DATE;
    IF v_daily_earned >= v_daily_cap THEN
      RETURN;
    END IF;
    v_effective_amount := LEAST(p_amount, v_daily_cap - v_daily_earned);
  END IF;

  v_new_balance := v_current_balance + v_effective_amount;
  IF v_new_balance < 0 THEN
    RAISE EXCEPTION 'Yetersiz MF Points bakiyesi.';
  END IF;

  IF v_effective_amount > 0 THEN
    v_total_earned := v_total_earned + v_effective_amount;
  END IF;

  -- 5. Ledger Entry
  INSERT INTO public.mf_point_ledger (user_id, amount, balance_after, source, description, idempotency_key)
  VALUES (p_user_id, v_effective_amount, v_new_balance, p_source, p_description, p_idempotency_key);

  UPDATE public.user_mf_balance
  SET balance = v_new_balance, total_earned = v_total_earned, updated_at = timezone('utc', now())
  WHERE user_id = p_user_id;
END;
$$;

-- 3. REDEMPTION ELIGIBILITY & EXECUTION CONTRACT
CREATE OR REPLACE FUNCTION public.attempt_reward_redemption(
    p_user_id UUID,
    p_reward_id UUID,
    p_amount INTEGER,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance INTEGER;
    v_trust_score INTEGER;
    v_risk_level TEXT;
    v_status TEXT := 'approved';
    v_reason TEXT := '';
    v_redemption_id UUID;
BEGIN
    -- 1. Idempotency Check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, status, rejection_reason INTO v_redemption_id, v_status, v_reason
        FROM public.redemption_attempts WHERE idempotency_key = p_idempotency_key;
        IF v_redemption_id IS NOT NULL THEN
            RETURN jsonb_build_object('id', v_redemption_id, 'status', v_status, 'reason', v_reason);
        END IF;
    END IF;

    -- 2. Eligibility Checks
    SELECT balance INTO v_balance FROM public.user_mf_balance WHERE user_id = p_user_id;
    SELECT trust_score INTO v_trust_score FROM public.profiles WHERE id = p_user_id;
    SELECT risk_level INTO v_risk_level FROM public.risk_scores WHERE user_id = p_user_id;
    
    v_risk_level := COALESCE(v_risk_level, 'clear');

    IF v_balance IS NULL OR v_balance < p_amount THEN
        v_status := 'rejected'; v_reason := 'Yetersiz MF Points bakiyesi.';
    ELSIF v_trust_score < 40 THEN
        v_status := 'rejected'; v_reason := 'Güven puanı ödül alımı için çok düşük (Min: 40).';
    ELSIF v_risk_level IN ('blocked', 'high_risk') THEN
        v_status := 'rejected'; v_reason := 'Hesap güvenliği nedeniyle ödül alımı kısıtlandı.';
    END IF;

    -- 3. Log the attempt
    INSERT INTO public.redemption_attempts (user_id, reward_id, amount, status, rejection_reason, risk_level, idempotency_key)
    VALUES (p_user_id, p_reward_id, p_amount, v_status, v_reason, v_risk_level, p_idempotency_key)
    RETURNING id INTO v_redemption_id;

    -- 4. Execution or Notification
    IF v_status = 'approved' THEN
        -- Execute point deduction via centralized add_mf_points
        PERFORM public.add_mf_points(p_user_id, -p_amount, 'redemption', 'Reward Redemption ID: ' || v_redemption_id, 'redemption:' || v_redemption_id);
    ELSE
        -- Send rejection notification via @Notification contract
        PERFORM public.create_notification_request(
            p_user_id,
            'redemption_rejected',
            'Ödül Talebi Reddedildi',
            'Talebiniz reddedildi: ' || v_reason,
            NULL,
            jsonb_build_object('redemption_id', v_redemption_id, 'reason', v_reason),
            'notif:redemption_reject:' || v_redemption_id
        );
    END IF;

    RETURN jsonb_build_object('id', v_redemption_id, 'status', v_status, 'reason', v_reason);
END;
$$;

-- 4. GRANTS
GRANT EXECUTE ON FUNCTION public.attempt_reward_redemption(UUID, UUID, INTEGER, TEXT) TO authenticated;
