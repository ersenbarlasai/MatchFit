-- ==============================================================================
-- MATCHFIT PARTNER INVENTORY OVERLOAD CLEANUP
-- @PartnerCatalog Agent System
-- ==============================================================================

-- 1. DROP OBSOLETE 2-PARAMETER OVERLOAD
-- Migration 08 created a 2-param version, and Migration 09 created a 3-param version.
-- This caused ambiguity because the 3rd parameter in the new version has a default value.
DROP FUNCTION IF EXISTS public.reserve_reward_inventory(p_reward_id UUID, p_idempotency_key TEXT);

-- 2. RE-GRANT PERMISSIONS TO THE CANONICAL 3-PARAMETER VERSION
-- Just to be certain the active version has the correct permissions.
GRANT EXECUTE ON FUNCTION public.reserve_reward_inventory(UUID, TEXT, JSONB) TO authenticated;
