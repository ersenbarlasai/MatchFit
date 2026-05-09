-- Fix for ambiguous function signature error in create_notification_request
-- PostgreSQL couldn't resolve the overloaded function without named parameters or explicit type casting.

-- RPC: Request Coach Session (Updated with named parameters for create_notification_request)
CREATE OR REPLACE FUNCTION request_coach_session(
    p_coach_id UUID,
    p_session_date DATE,
    p_start_time TIME,
    p_end_time TIME,
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
    v_student_name TEXT;
BEGIN
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_session_id
        FROM coach_sessions
        WHERE idempotency_key = p_idempotency_key;

        IF v_session_id IS NOT NULL THEN
            RETURN v_session_id;
        END IF;
    END IF;

    -- Check for existing confirmed session in same slot
    IF EXISTS (
        SELECT 1 FROM coach_sessions 
        WHERE coach_id = p_coach_id 
        AND session_date = p_session_date 
        AND start_time = p_start_time 
        AND status = 'confirmed'
    ) THEN
        RAISE EXCEPTION 'Bu saat dilimi zaten dolu.';
    END IF;

    -- Insert session
    INSERT INTO coach_sessions (
        coach_id, 
        student_id, 
        session_date, 
        start_time, 
        end_time, 
        status, 
        idempotency_key
    ) VALUES (
        p_coach_id, 
        auth.uid(), 
        p_session_date, 
        p_start_time, 
        p_end_time, 
        'requested', 
        p_idempotency_key
    ) RETURNING id INTO v_session_id;

    -- Fetch student name for notification
    SELECT full_name INTO v_student_name FROM profiles WHERE id = auth.uid();

    -- Notify Coach via @Notification (Fixed to use public schema and named parameters)
    PERFORM public.create_notification_request(
        p_receiver_id := p_coach_id,
        p_type := 'coach_session_request',
        p_title := 'Yeni Seans Talebi',
        p_message := COALESCE(v_student_name, 'Bir kullanıcı') || ' sizden seans talep etti.',
        p_event_id := NULL,
        p_data := jsonb_build_object(
            'session_id', v_session_id,
            'type', 'coach_booking',
            'click_action', '/coach-sessions'
        ),
        p_idempotency_key := 'coach_session_request:' || v_session_id::text,
        p_sender_id := auth.uid()
    );

    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- RPC: Handle Coach Session Request (Updated with named parameters for create_notification_request)
CREATE OR REPLACE FUNCTION handle_coach_session_request(
    p_session_id UUID,
    p_action TEXT, -- 'confirm' or 'reject'
    p_reason TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_session RECORD;
    v_new_status TEXT;
    v_coach_name TEXT;
BEGIN
    SELECT * INTO v_session FROM coach_sessions WHERE id = p_session_id;
    
    IF v_session IS NULL THEN RAISE EXCEPTION 'Seans bulunamadı.'; END IF;
    IF v_session.coach_id != auth.uid() THEN RAISE EXCEPTION 'Bu işlem için yetkiniz yok.'; END IF;
    IF v_session.status != 'requested' THEN RAISE EXCEPTION 'Seans durumu uygun değil.'; END IF;

    IF p_action = 'confirm' THEN
        -- Re-check availability before confirming
        IF EXISTS (
            SELECT 1 FROM coach_sessions 
            WHERE coach_id = v_session.coach_id 
            AND session_date = v_session.session_date 
            AND start_time = v_session.start_time 
            AND status = 'confirmed' 
            AND id != p_session_id
        ) THEN
            RAISE EXCEPTION 'Bu saat dilimi zaten başka bir seans için rezerve edildi.';
        END IF;
        v_new_status := 'confirmed';
    ELSIF p_action = 'reject' THEN
        v_new_status := 'rejected';
    ELSE
        RAISE EXCEPTION 'Geçersiz işlem.';
    END IF;

    UPDATE coach_sessions 
    SET status = v_new_status, 
        cancellation_reason = p_reason,
        updated_at = now()
    WHERE id = p_session_id;

    -- Fetch coach name for notification
    SELECT full_name INTO v_coach_name FROM profiles WHERE id = auth.uid();

    -- Notify Student (Fixed to use public schema and named parameters)
    PERFORM public.create_notification_request(
        p_receiver_id := v_session.student_id,
        p_type := 'coach_session_update',
        p_title := CASE WHEN v_new_status = 'confirmed' THEN 'Seans Onaylandı!' ELSE 'Seans Reddedildi' END,
        p_message := COALESCE(v_coach_name, 'Koçunuz') || 
            CASE WHEN v_new_status = 'confirmed' THEN ' seans talebinizi onayladı.' ELSE ' seans talebinizi reddetti.' END,
        p_event_id := NULL,
        p_data := jsonb_build_object(
            'session_id', p_session_id,
            'status', v_new_status,
            'type', 'coach_booking_result'
        ),
        p_idempotency_key := 'coach_session_update:' || p_session_id::text || ':' || v_new_status,
        p_sender_id := auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
