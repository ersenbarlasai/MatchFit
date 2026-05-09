-- Coach Admin Hardening Migration
-- Date: 2026-05-11
-- Description: RPCs for admin coach verification and document review to eliminate direct table writes.

-- 1. RPC: Handle Coach Verification (Admin Hardened)
CREATE OR REPLACE FUNCTION public.handle_coach_verification(
    p_user_id UUID,
    p_level TEXT,
    p_is_active BOOLEAN,
    p_reason TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- Authorization check (admins or service role)
    IF auth.role() != 'service_role' AND NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND (role = 'admin' OR role = 'system_admin')
    ) THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    UPDATE public.coaches 
    SET verification_level = p_level,
        is_active = p_is_active,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- Log the decision using existing RPC logic
    PERFORM public.log_coach_verification_event(
        p_coach_id := p_user_id,
        p_agent_name := '@CoachVerificationAgent',
        p_action_type := CASE WHEN p_is_active THEN 'coach_approved' ELSE 'coach_rejected' END,
        p_details := jsonb_build_object('level', p_level, 'reason', p_reason)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. RPC: Handle Coach Document Review (Admin Hardened)
CREATE OR REPLACE FUNCTION public.handle_coach_document_review(
    p_doc_id UUID,
    p_status TEXT,
    p_reason TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- Authorization check (admins or service role)
    IF auth.role() != 'service_role' AND NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND (role = 'admin' OR role = 'system_admin')
    ) THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    UPDATE public.coach_documents 
    SET status = p_status,
        rejection_reason = p_reason,
        reviewed_at = now(),
        reviewed_by = auth.uid()
    WHERE id = p_doc_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
