-- ==============================================================================
-- MATCHFIT LEGACY FUNCTION OVERLOAD CLEANUP
-- Standardizing @XPEngine, @EconomyEngine and @Referee RPC Contracts
-- ==============================================================================

-- 1. UPDATE award_daily_app_open_rewards TO USE CANONICAL IDEMPOTENT SIGNATURES
CREATE OR REPLACE FUNCTION public.award_daily_app_open_rewards()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_idemp_xp TEXT;
  v_idemp_mf TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  v_idemp_xp := 'app_open:xp:' || v_user_id::text || ':' || CURRENT_DATE::text;
  v_idemp_mf := 'app_open:mf:' || v_user_id::text || ':' || CURRENT_DATE::text;

  -- Add XP (Using canonical 13-param signature with defaults)
  -- Parameters: user_id, amount, source, ..., idempotency_key
  PERFORM public.add_user_xp(
    p_user_id => v_user_id, 
    p_amount => 10, 
    p_source => 'app_open',
    p_idempotency_key => v_idemp_xp
  );

  -- Add MF Points (Using canonical 5-param signature)
  PERFORM public.add_mf_points(
    p_user_id => v_user_id,
    p_amount => 5,
    p_source => 'app_open',
    p_description => 'Gunluk Giris Odulu',
    p_idempotency_key => v_idemp_mf
  );
END;
$$;

-- 2. DROP OBSOLETE/NON-IDEMPOTENT OVERLOADS

-- A. add_user_xp cleanup
-- Drop legacy 12-param version (missing idempotency_key)
DROP FUNCTION IF EXISTS public.add_user_xp(uuid, integer, text, text, text, boolean, integer, boolean, integer, boolean, boolean, text);
-- Drop legacy 3-param version
DROP FUNCTION IF EXISTS public.add_user_xp(uuid, integer, text);

-- B. add_mf_points cleanup
-- Drop legacy 3-param version
DROP FUNCTION IF EXISTS public.add_mf_points(uuid, integer, text);
-- Drop legacy 4-param version
DROP FUNCTION IF EXISTS public.add_mf_points(uuid, integer, text, text);

-- C. log_trust_event cleanup
-- Canonical version is 6-params (Migration 01). Drop older versions.
DROP FUNCTION IF EXISTS public.log_trust_event(uuid, text, text, integer, text); -- 5 params
DROP FUNCTION IF EXISTS public.log_trust_event(uuid, integer, text); -- 3 params (very old)

-- 3. ENSURE CANONICAL SIGNATURES ARE MAINTAINED (Idempotent definitions)
-- Note: These are already defined in previous migrations (01, 03, 06). 
-- This section serves as a verification/enforcement layer.

DO $$ 
BEGIN
    -- Verify add_user_xp (13 params)
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' AND p.proname = 'add_user_xp' AND pronargs = 13
    ) THEN
        RAISE WARNING 'Canonical 13-parameter add_user_xp not found. Ensure Migration 03 was applied.';
    END IF;

    -- Verify add_mf_points (5 params)
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' AND p.proname = 'add_mf_points' AND pronargs = 5
    ) THEN
        RAISE WARNING 'Canonical 5-parameter add_mf_points not found. Ensure Migration 06 was applied.';
    END IF;
END $$;
