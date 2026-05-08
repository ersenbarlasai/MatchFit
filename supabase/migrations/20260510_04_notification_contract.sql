-- ==============================================================================
-- MATCHFIT NOTIFICATION CONTRACT & IDEMPOTENCY
-- @Notification Agent System Hardening
-- ==============================================================================

-- 1. ADD MISSING COLUMNS DUE TO SCHEMA DRIFT
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS data JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency_key
  ON public.notifications (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- 2. UPDATED NOTIFICATION RPC CONTRACT (The Single Source of Truth)
CREATE OR REPLACE FUNCTION public.create_notification_request(
  p_receiver_id UUID,
  p_type TEXT,
  p_title TEXT DEFAULT NULL,
  p_message TEXT DEFAULT NULL,
  p_event_id UUID DEFAULT NULL,
  p_data JSONB DEFAULT '{}'::jsonb,
  p_idempotency_key TEXT DEFAULT NULL,
  p_sender_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id UUID;
  v_sender_id UUID := COALESCE(p_sender_id, auth.uid());
BEGIN
  -- Idempotency check: Skip if already exists, but return the existing ID
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_notification_id
    FROM public.notifications
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;
    
    IF v_notification_id IS NOT NULL THEN
      RETURN v_notification_id;
    END IF;
  END IF;

  INSERT INTO public.notifications (
    receiver_id,
    sender_id,
    event_id,
    type,
    title,
    message,
    data,
    idempotency_key
  )
  VALUES (
    p_receiver_id,
    v_sender_id,
    p_event_id,
    p_type,
    p_title,
    p_message,
    COALESCE(p_data, '{}'::jsonb),
    p_idempotency_key
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

-- 3. REFACTOR EXISTING TRIGGERS TO USE THE CONTRACT (Removing direct inserts)

-- notify_host_on_join_request
CREATE OR REPLACE FUNCTION public.notify_host_on_join_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  event_host_id UUID;
  event_title TEXT;
  sender_name TEXT;
  rejection_total INTEGER;
  notification_message TEXT;
  v_idemp_key TEXT;
BEGIN
  SELECT host_id, title
  INTO event_host_id, event_title
  FROM public.events
  WHERE id = NEW.event_id;

  SELECT full_name
  INTO sender_name
  FROM public.profiles
  WHERE id = NEW.user_id;

  IF NEW.status = 'pending' THEN
    rejection_total := COALESCE(NEW.rejection_count, 0);
    -- Deterministic key for join requests
    v_idemp_key := 'join_request:' || NEW.event_id::text || ':' || NEW.user_id::text || ':' || rejection_total::text;

    IF rejection_total > 0 THEN
      notification_message :=
        COALESCE(sender_name, 'Bir kullanıcı') ||
        ', "' || COALESCE(event_title, 'etkinlik') ||
        '" etkinliğine tekrar başvuruyor. Daha önce reddedilmişti.';
    ELSE
      notification_message :=
        COALESCE(sender_name, 'Bir kullanıcı') ||
        ', "' || COALESCE(event_title, 'etkinlik') ||
        '" etkinliğine katılmak istiyor.';
    END IF;

    PERFORM public.create_notification_request(
      event_host_id,
      'join_request',
      'Katılım isteği',
      notification_message,
      NEW.event_id,
      '{}'::jsonb,
      v_idemp_key,
      NEW.user_id
    );
  END IF;

  RETURN NEW;
END;
$$;

-- notify_user_on_status_change
CREATE OR REPLACE FUNCTION public.notify_user_on_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  event_title TEXT;
  v_idemp_key TEXT;
BEGIN
  SELECT title
  INTO event_title
  FROM public.events
  WHERE id = NEW.event_id;

  -- Deterministic key for status changes
  v_idemp_key := 'status_change:' || NEW.event_id::text || ':' || NEW.user_id::text || ':' || NEW.status;

  IF NEW.status = 'joined' AND OLD.status = 'pending' THEN
    PERFORM public.create_notification_request(
      NEW.user_id,
      'join_approved',
      'Katılım onaylandı',
      '"' || COALESCE(event_title, 'Etkinlik') || '" etkinliğine katılımın onaylandı.',
      NEW.event_id,
      '{}'::jsonb,
      v_idemp_key,
      NULL -- System/Agent notification
    );
  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    PERFORM public.create_notification_request(
      NEW.user_id,
      'join_rejected',
      'Katılım reddedildi',
      CASE
        WHEN COALESCE(NEW.rejection_count, 0) >= 2 THEN
          '"' || COALESCE(event_title, 'Etkinlik') || '" etkinliğine katılım isteğin reddedildi. Bu etkinliğe tekrar başvuramazsın.'
        ELSE
          '"' || COALESCE(event_title, 'Etkinlik') || '" etkinliğine katılım isteğin reddedildi. Yeniden başvurabilmek için 2 saat beklemelisin.'
      END,
      NEW.event_id,
      '{}'::jsonb,
      v_idemp_key,
      NULL
    );
  END IF;

  RETURN NEW;
END;
$$;

-- handle_new_message_notification (DM support)
CREATE OR REPLACE FUNCTION public.handle_new_message_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
    v_idemp_key TEXT;
BEGIN
    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;
    v_idemp_key := 'dm:' || NEW.id::text;

    PERFORM public.create_notification_request(
        NEW.receiver_id,
        'new_message',
        'Yeni Mesaj: ' || COALESCE(v_sender_name, 'Kullanıcı'),
        NEW.content,
        NULL,
        '{}'::jsonb,
        v_idemp_key,
        NEW.sender_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. RLS UPDATES (Restricting direct inserts)
DROP POLICY IF EXISTS "Agent only insert" ON public.notifications;
CREATE POLICY "Agent only insert" ON public.notifications
  FOR INSERT WITH CHECK (false); -- Must use create_notification_request RPC

-- 5. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION public.create_notification_request(UUID, TEXT, TEXT, TEXT, UUID, JSONB, TEXT, UUID) TO authenticated;
