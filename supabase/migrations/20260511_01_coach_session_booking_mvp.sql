-- Coach Session Booking MVP Migration
-- Date: 2026-05-11
-- Description: Adds tables and RPCs for coach availability and session booking.

-- 1. Coach Availability Table
CREATE TABLE IF NOT EXISTS coach_availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    location_name TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Coach Sessions Table
CREATE TABLE IF NOT EXISTS coach_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'confirmed', 'rejected', 'cancelled', 'completed', 'no_show')),
    price_amount NUMERIC DEFAULT 0,
    currency TEXT DEFAULT 'TRY',
    meeting_point_text TEXT,
    cancellation_reason TEXT,
    idempotency_key TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure column exists if table was previously created without it
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS session_date DATE;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS start_time TIME;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS end_time TIME;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'requested';
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS price_amount NUMERIC DEFAULT 0;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'TRY';
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS meeting_point_text TEXT;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE coach_sessions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE coach_availability ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE coach_availability ADD COLUMN IF NOT EXISTS day_of_week INTEGER;
ALTER TABLE coach_availability ADD COLUMN IF NOT EXISTS start_time TIME;
ALTER TABLE coach_availability ADD COLUMN IF NOT EXISTS end_time TIME;
ALTER TABLE coach_availability ADD COLUMN IF NOT EXISTS location_name TEXT;
ALTER TABLE coach_availability ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE coach_availability ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE coach_availability ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Unique partial index for idempotency_key
CREATE UNIQUE INDEX IF NOT EXISTS idx_coach_sessions_idempotency_key ON coach_sessions (idempotency_key) WHERE idempotency_key IS NOT NULL;

-- 3. RLS Policies
ALTER TABLE coach_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_sessions ENABLE ROW LEVEL SECURITY;

-- Availability: Everyone can read active slots, coach can manage their own
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view active availability') THEN
        CREATE POLICY "Anyone can view active availability" ON coach_availability FOR SELECT USING (is_active = true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Coaches can manage their own availability') THEN
        CREATE POLICY "Coaches can manage their own availability" ON coach_availability FOR ALL USING (auth.uid() = coach_id);
    END IF;
END $$;

-- Sessions: Involved parties can read
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own sessions') THEN
        CREATE POLICY "Users can view their own sessions" ON coach_sessions FOR SELECT USING (auth.uid() = coach_id OR auth.uid() = student_id);
    END IF;
END $$;

-- Disable direct insert/update for sessions to enforce RPC logic
-- (Policies for insert/update are NOT created, so only RPCs with SECURITY DEFINER can write)

-- 4. RPCs

-- Backward-compatible @Notification bridge for legacy 5-argument calls.
-- The canonical implementation remains create_notification_request(..., p_event_id, p_data, p_idempotency_key, p_sender_id).
CREATE OR REPLACE FUNCTION create_notification_request(
    p_receiver_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_message TEXT,
    p_data JSONB
) RETURNS UUID AS $$
BEGIN
    RETURN public.create_notification_request(
        p_receiver_id := p_receiver_id,
        p_type := p_type,
        p_title := p_title,
        p_message := p_message,
        p_event_id := NULL,
        p_data := COALESCE(p_data, '{}'::jsonb),
        p_idempotency_key := NULL,
        p_sender_id := auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Upsert Coach Availability
CREATE OR REPLACE FUNCTION upsert_coach_availability(
    p_slots JSONB -- Array of {day_of_week, start_time, end_time, location_name}
) RETURNS VOID AS $$
BEGIN
    -- Delete existing for this coach and re-insert (Simple sync for MVP)
    DELETE FROM coach_availability WHERE coach_id = auth.uid();
    
    INSERT INTO coach_availability (coach_id, day_of_week, start_time, end_time, location_name)
    SELECT 
        auth.uid(),
        (elem->>'day_of_week')::INTEGER,
        (elem->>'start_time')::TIME,
        (elem->>'end_time')::TIME,
        elem->>'location_name'
    FROM jsonb_array_elements(p_slots) elem;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Get Coach Availability
CREATE OR REPLACE FUNCTION get_coach_availability(p_coach_id UUID)
RETURNS SETOF coach_availability AS $$
BEGIN
    RETURN QUERY SELECT * FROM coach_availability WHERE coach_id = p_coach_id AND is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Request Coach Session
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

    -- Notify Coach via @Notification
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

-- RPC: Handle Coach Session Request
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

    -- Notify Student
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

-- RPC: Get My Coach Sessions
CREATE OR REPLACE FUNCTION get_my_coach_sessions()
RETURNS TABLE (
    id UUID,
    coach_id UUID,
    student_id UUID,
    session_date DATE,
    start_time TIME,
    end_time TIME,
    status TEXT,
    price_amount NUMERIC,
    currency TEXT,
    meeting_point_text TEXT,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ,
    coach_profile JSONB,
    student_profile JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id, s.coach_id, s.student_id, s.session_date, s.start_time, s.end_time, s.status,
        s.price_amount, s.currency, s.meeting_point_text, s.cancellation_reason, s.created_at,
        (SELECT jsonb_build_object('full_name', p.full_name, 'avatar_url', p.avatar_url) FROM profiles p WHERE p.id = s.coach_id) as coach_profile,
        (SELECT jsonb_build_object('full_name', p.full_name, 'avatar_url', p.avatar_url) FROM profiles p WHERE p.id = s.student_id) as student_profile
    FROM coach_sessions s
    WHERE s.coach_id = auth.uid() OR s.student_id = auth.uid()
    ORDER BY s.session_date DESC, s.start_time DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
