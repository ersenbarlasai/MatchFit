-- Economy & Partner Catalog Redemption Integration
-- Date: 2026-05-12
-- Description: Adds redemption_attempts table and the attempt_reward_redemption RPC.

-- 1. Redemption Attempts Table
CREATE TABLE IF NOT EXISTS public.redemption_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    reward_id UUID REFERENCES public.reward_catalog(id) ON DELETE SET NULL,
    partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL,
    cost_points INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'completed'
    rejection_reason TEXT,
    risk_level TEXT DEFAULT 'clear',
    idempotency_key TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Schema Drift Protection
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS reward_id UUID REFERENCES public.reward_catalog(id);
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES public.partners(id);
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS cost_points INTEGER DEFAULT 0;
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS risk_level TEXT DEFAULT 'clear';
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.redemption_attempts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 2. Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_redemption_attempts_idem_key ON public.redemption_attempts (idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_redemption_attempts_user_created ON public.redemption_attempts (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_redemption_attempts_reward_id ON public.redemption_attempts (reward_id);
CREATE INDEX IF NOT EXISTS idx_redemption_attempts_status ON public.redemption_attempts (status);

-- 3. RLS
ALTER TABLE public.redemption_attempts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own redemption attempts') THEN
        CREATE POLICY "Users can view their own redemption attempts" ON public.redemption_attempts
            FOR SELECT USING (auth.uid() = user_id);
    END IF;
END $$;

-- 4. RPC: Attempt Reward Redemption
DROP FUNCTION IF EXISTS public.attempt_reward_redemption(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.attempt_reward_redemption(
    p_reward_id UUID,
    p_idempotency_key TEXT
) RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_reward RECORD;
    v_balance INTEGER;
    v_trust_score INTEGER;
    v_existing_attempt RECORD;
    v_reservation_id UUID;
    v_result JSONB;
BEGIN
    -- 1. Auth Check
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('status', 'rejected', 'reason', 'not_authenticated');
    END IF;

    -- 2. Idempotency Check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT * INTO v_existing_attempt
        FROM public.redemption_attempts
        WHERE idempotency_key = p_idempotency_key;

        IF v_existing_attempt IS NOT NULL THEN
            RETURN jsonb_build_object(
                'status', v_existing_attempt.status,
                'id', v_existing_attempt.id,
                'reason', v_existing_attempt.rejection_reason,
                'is_idempotent', true
            );
        END IF;
    END IF;

    -- 3. Fetch Reward Details
    SELECT r.*, i.stock_remaining, i.is_unlimited
    INTO v_reward
    FROM public.reward_catalog r
    JOIN public.reward_inventory i ON r.id = i.reward_id
    WHERE r.id = p_reward_id;

    IF v_reward IS NULL THEN
        RETURN jsonb_build_object('status', 'rejected', 'reason', 'reward_not_found');
    END IF;

    -- 4. Validate Reward Status & Dates
    IF v_reward.status != 'active' THEN
        RETURN jsonb_build_object('status', 'rejected', 'reason', 'reward_inactive');
    END IF;

    IF v_reward.valid_from > now() OR (v_reward.valid_until IS NOT NULL AND v_reward.valid_until < now()) THEN
        RETURN jsonb_build_object('status', 'rejected', 'reason', 'reward_expired');
    END IF;

    -- 5. Trust Score Check (Safe Check)
    BEGIN
        SELECT trust_score INTO v_trust_score FROM public.profiles WHERE id = v_user_id;
    EXCEPTION WHEN OTHERS THEN
        v_trust_score := 0;
    END;
    
    IF v_reward.trust_minimum > COALESCE(v_trust_score, 0) THEN
        INSERT INTO public.redemption_attempts (user_id, reward_id, partner_id, cost_points, status, rejection_reason, idempotency_key)
        VALUES (v_user_id, p_reward_id, v_reward.partner_id, v_reward.cost_points, 'rejected', 'trust_too_low', p_idempotency_key);
        
        RETURN jsonb_build_object('status', 'rejected', 'reason', 'trust_too_low');
    END IF;

    -- 6. Balance Check
    SELECT balance INTO v_balance FROM public.user_mf_balance WHERE user_id = v_user_id;
    
    IF COALESCE(v_balance, 0) < v_reward.cost_points THEN
        INSERT INTO public.redemption_attempts (user_id, reward_id, partner_id, cost_points, status, rejection_reason, idempotency_key)
        VALUES (v_user_id, p_reward_id, v_reward.partner_id, v_reward.cost_points, 'rejected', 'insufficient_balance', p_idempotency_key);
        
        RETURN jsonb_build_object('status', 'rejected', 'reason', 'insufficient_balance');
    END IF;

    -- 7. Reserve Stock (Deterministic Key)
    IF NOT public.reserve_reward_inventory(
        p_reward_id := p_reward_id,
        p_idempotency_key := 'redemption:' || v_user_id::text || ':' || p_reward_id::text || ':' || p_idempotency_key || ':inventory',
        p_metadata := jsonb_build_object('source', 'attempt_reward_redemption')
    ) THEN
        INSERT INTO public.redemption_attempts (user_id, reward_id, partner_id, cost_points, status, rejection_reason, idempotency_key)
        VALUES (v_user_id, p_reward_id, v_reward.partner_id, v_reward.cost_points, 'rejected', 'out_of_stock', p_idempotency_key);
        
        RETURN jsonb_build_object('status', 'rejected', 'reason', 'out_of_stock');
    END IF;

    -- 8. Deduct Points (Deterministic Key)
    IF v_reward.cost_points > 0 THEN
        PERFORM public.add_mf_points(
            p_user_id := v_user_id,
            p_amount := -v_reward.cost_points,
            p_source := 'reward_redemption',
            p_description := 'Reward redemption: ' || v_reward.name,
            p_idempotency_key := 'redemption:' || v_user_id::text || ':' || p_reward_id::text || ':' || p_idempotency_key || ':ledger'
        );
    END IF;

    -- 9. Record Successful Attempt
    INSERT INTO public.redemption_attempts (
        user_id, 
        reward_id, 
        partner_id, 
        cost_points, 
        status, 
        idempotency_key,
        metadata
    ) VALUES (
        v_user_id, 
        p_reward_id, 
        v_reward.partner_id, 
        v_reward.cost_points, 
        'approved', 
        p_idempotency_key,
        jsonb_build_object('reward_name', v_reward.name)
    ) RETURNING id INTO v_reservation_id;

    RETURN jsonb_build_object(
        'status', 'approved',
        'id', v_reservation_id,
        'cost_points', v_reward.cost_points,
        'reward_name', v_reward.name
    );

EXCEPTION WHEN OTHERS THEN
    -- In case of unexpected error (e.g. add_mf_points failure), transaction rolls back.
    -- However, if we want to log the failure, we'd need to catch it outside.
    -- For MVP, letting it bubble up as an RPC error is acceptable as it ensures data integrity.
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
