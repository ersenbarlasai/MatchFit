-- ==============================================================================
-- MATCHFIT PARTNER INVENTORY IDEMPOTENCY FIX
-- @PartnerCatalog Agent Stock Management
-- ==============================================================================

-- 1. RESERVATIONS LOG (Ensures atomic and idempotent stock reduction)
CREATE TABLE IF NOT EXISTS public.reward_inventory_reservations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reward_id UUID REFERENCES public.reward_catalog(id) ON DELETE CASCADE,
  idempotency_key TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'reserved', -- reserved, consumed, cancelled
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  UNIQUE(idempotency_key)
);

-- RLS: Internal agent log, not directly accessible by users for write/delete
ALTER TABLE public.reward_inventory_reservations ENABLE ROW LEVEL SECURITY;

-- 2. UPDATED reserve_reward_inventory RPC (Idempotent & Atomic)
CREATE OR REPLACE FUNCTION public.reserve_reward_inventory(
    p_reward_id UUID, 
    p_idempotency_key TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reservation_id UUID;
  v_stock_remaining INTEGER;
BEGIN
  -- 1. Input Validation
  IF p_idempotency_key IS NULL OR p_idempotency_key = '' THEN
    RAISE EXCEPTION 'Idempotency key is required for inventory reservation.';
  END IF;

  -- 2. Idempotency Check (Look for existing reservation with the same key)
  SELECT id INTO v_reservation_id 
  FROM public.reward_inventory_reservations 
  WHERE idempotency_key = p_idempotency_key;

  IF v_reservation_id IS NOT NULL THEN
    -- Key already used, return TRUE (idempotent success) without deducting again
    RETURN TRUE;
  END IF;

  -- 3. Atomic Stock Check & Deduction
  -- Use FOR UPDATE to lock the inventory row for the duration of this transaction
  SELECT stock_remaining INTO v_stock_remaining
  FROM public.reward_inventory
  WHERE reward_id = p_reward_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reward inventory entry not found for reward_id: %', p_reward_id;
  END IF;

  -- 4. Decide based on stock availability
  IF v_stock_remaining IS NULL THEN
    -- Unlimited stock: Just record the reservation
    INSERT INTO public.reward_inventory_reservations (reward_id, idempotency_key, metadata)
    VALUES (p_reward_id, p_idempotency_key, p_metadata);
    RETURN TRUE;
    
  ELSIF v_stock_remaining > 0 THEN
    -- Limited stock available: Deduct 1 and record the reservation
    UPDATE public.reward_inventory
    SET stock_remaining = stock_remaining - 1,
        updated_at = now()
    WHERE reward_id = p_reward_id;

    INSERT INTO public.reward_inventory_reservations (reward_id, idempotency_key, metadata)
    VALUES (p_reward_id, p_idempotency_key, p_metadata);
    
    RETURN TRUE;
    
  ELSE
    -- Out of stock: No deduction, no reservation recorded
    RETURN FALSE;
  END IF;
END;
$$;

-- 3. RE-GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION public.reserve_reward_inventory(UUID, TEXT, JSONB) TO authenticated;
