-- ==============================================================================
-- MATCHFIT ENGINE CONFLICT RESOLUTION - P2 FOLLOW-UP
-- Coach Verification Logs RPC
-- ==============================================================================

-- 1. REVOKE/GRANT permissions for the log table
-- Note: Client direct INSERT is disabled via RLS policy "Agent only insert" 
-- in migration 20260510_engine_conflict_resolution.sql.
-- Policy: FOR INSERT WITH CHECK (false)

REVOKE ALL ON public.coach_verification_logs FROM anon, authenticated;
GRANT SELECT ON public.coach_verification_logs TO authenticated;
-- Only the system (SECURITY DEFINER) will have INSERT permission.

-- 2. Create a secure RPC for logging coach verification events
CREATE OR REPLACE FUNCTION public.log_coach_verification_event(
    p_coach_id UUID,
    p_agent_name TEXT,
    p_action_type TEXT,
    p_details JSONB DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    -- Auth check: Only the coach themselves or a superuser/service_role can log this
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate that the caller is the coach or has service_role
    IF auth.uid() != p_coach_id AND current_setting('request.jwt.claims', true)::jsonb->>'role' != 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized to log events for this coach';
    END IF;

    INSERT INTO public.coach_verification_logs (coach_id, agent_name, action_type, details)
    VALUES (p_coach_id, p_agent_name, p_action_type, p_details);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.log_coach_verification_event(UUID, TEXT, TEXT, JSONB) TO authenticated;
