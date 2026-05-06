-- MatchFit agent system hardening.
-- Safe to re-run. Does not delete user, event, sport, XP, trust, or ledger data.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ---------------------------------------------------------------------------
-- @Notification: one schema contract and idempotent policies.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT,
  message TEXT,
  data JSONB DEFAULT '{}'::jsonb,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS message TEXT,
  ADD COLUMN IF NOT EXISTS data JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;
CREATE POLICY "Users can delete their own notifications"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = receiver_id)
  WITH CHECK (auth.uid() = receiver_id);

-- Central app-facing notification entry point. Sender is always auth.uid().
CREATE OR REPLACE FUNCTION public.create_notification_request(
  p_receiver_id UUID,
  p_type TEXT,
  p_title TEXT DEFAULT NULL,
  p_message TEXT DEFAULT NULL,
  p_event_id UUID DEFAULT NULL,
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  INSERT INTO public.notifications (
    receiver_id,
    sender_id,
    event_id,
    type,
    title,
    message,
    data
  )
  VALUES (
    p_receiver_id,
    auth.uid(),
    p_event_id,
    p_type,
    p_title,
    p_message,
    COALESCE(p_data, '{}'::jsonb)
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

-- Join-request notifications stay DB-owned and bypass user INSERT policies.
ALTER TABLE public.event_participants
  ADD COLUMN IF NOT EXISTS rejection_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_rejected_at TIMESTAMPTZ;

ALTER TABLE public.event_participants
  DROP CONSTRAINT IF EXISTS event_participants_status_check;

ALTER TABLE public.event_participants
  ADD CONSTRAINT event_participants_status_check
  CHECK (status IN ('pending', 'joined', 'rejected'));

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

    IF rejection_total > 0 THEN
      notification_message :=
        COALESCE(sender_name, 'Bir kullanici') ||
        ', "' || COALESCE(event_title, 'etkinlik') ||
        '" etkinligine tekrar basvuruyor. Daha once reddedilmisti.';
    ELSE
      notification_message :=
        COALESCE(sender_name, 'Bir kullanici') ||
        ', "' || COALESCE(event_title, 'etkinlik') ||
        '" etkinligine katilmak istiyor.';
    END IF;

    INSERT INTO public.notifications (
      receiver_id,
      sender_id,
      event_id,
      type,
      title,
      message
    )
    VALUES (
      event_host_id,
      NEW.user_id,
      NEW.event_id,
      'join_request',
      'Katilim istegi',
      notification_message
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_join_request ON public.event_participants;
CREATE TRIGGER on_join_request
  AFTER INSERT ON public.event_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_host_on_join_request();

DROP TRIGGER IF EXISTS on_join_request_update ON public.event_participants;
CREATE TRIGGER on_join_request_update
  AFTER UPDATE ON public.event_participants
  FOR EACH ROW
  WHEN (NEW.status = 'pending' AND OLD.status = 'rejected')
  EXECUTE FUNCTION public.notify_host_on_join_request();

CREATE OR REPLACE FUNCTION public.notify_user_on_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  event_title TEXT;
BEGIN
  SELECT title
  INTO event_title
  FROM public.events
  WHERE id = NEW.event_id;

  IF NEW.status = 'joined' AND OLD.status = 'pending' THEN
    INSERT INTO public.notifications (receiver_id, sender_id, event_id, type, title, message)
    VALUES (
      NEW.user_id,
      NULL,
      NEW.event_id,
      'join_approved',
      'Katilim onaylandi',
      '"' || COALESCE(event_title, 'Etkinlik') || '" etkinligine katilimin onaylandi.'
    );
  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    INSERT INTO public.notifications (receiver_id, sender_id, event_id, type, title, message)
    VALUES (
      NEW.user_id,
      NULL,
      NEW.event_id,
      'join_rejected',
      'Katilim reddedildi',
      CASE
        WHEN COALESCE(NEW.rejection_count, 0) >= 2 THEN
          '"' || COALESCE(event_title, 'Etkinlik') || '" etkinligine katilim istegin reddedildi. Bu etkinlige tekrar basvuramazsin.'
        ELSE
          '"' || COALESCE(event_title, 'Etkinlik') || '" etkinligine katilim istegin reddedildi. Yeniden basvurabilmek icin 2 saat beklemelisin.'
      END
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_join_status_change ON public.event_participants;
CREATE TRIGGER on_join_status_change
  AFTER UPDATE ON public.event_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_user_on_status_change();

-- ---------------------------------------------------------------------------
-- @Guardian / @ContextAgent: location trigger is re-runnable.
-- ---------------------------------------------------------------------------
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location geography(POINT);

CREATE OR REPLACE FUNCTION public.update_event_location()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
  ELSE
    NEW.location = NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_update_event_location ON public.events;
CREATE TRIGGER tr_update_event_location
  BEFORE INSERT OR UPDATE ON public.events
  FOR EACH ROW
  EXECUTE FUNCTION public.update_event_location();

-- ---------------------------------------------------------------------------
-- @EconomyEngine: daily app_open idempotency and positive earning cap.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mf_point_ledger (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  balance_after INTEGER NOT NULL,
  source TEXT NOT NULL,
  description TEXT,
  idempotency_key TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE public.mf_point_ledger
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mf_point_ledger_idempotency_key
  ON public.mf_point_ledger (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

ALTER TABLE public.mf_point_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own ledger" ON public.mf_point_ledger;
CREATE POLICY "Users can view their own ledger"
  ON public.mf_point_ledger FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.user_mf_balance (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance INTEGER NOT NULL DEFAULT 0,
  total_earned INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE public.user_mf_balance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all mf balances" ON public.user_mf_balance;
CREATE POLICY "Users can view all mf balances"
  ON public.user_mf_balance FOR SELECT
  TO authenticated
  USING (true);

DROP FUNCTION IF EXISTS public.add_mf_points(UUID, INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.add_mf_points(UUID, INTEGER, TEXT, TEXT, TEXT);

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
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User id is required.';
  END IF;

  IF p_idempotency_key IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.mf_point_ledger
       WHERE idempotency_key = p_idempotency_key
     ) THEN
    RETURN;
  END IF;

  IF p_source = 'app_open'
     AND EXISTS (
       SELECT 1
       FROM public.mf_point_ledger
       WHERE user_id = p_user_id
         AND source = 'app_open'
         AND amount > 0
         AND created_at >= CURRENT_DATE
     ) THEN
    RETURN;
  END IF;

  SELECT COALESCE(daily_mf_cap, 100)
  INTO v_daily_cap
  FROM public.orchestrator_config
  WHERE id = 1;

  SELECT balance, total_earned
  INTO v_current_balance, v_total_earned
  FROM public.user_mf_balance
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    v_current_balance := 0;
    v_total_earned := 0;

    INSERT INTO public.user_mf_balance (user_id, balance, total_earned)
    VALUES (p_user_id, 0, 0);
  END IF;

  IF p_amount > 0 THEN
    SELECT COALESCE(SUM(amount), 0)
    INTO v_daily_earned
    FROM public.mf_point_ledger
    WHERE user_id = p_user_id
      AND amount > 0
      AND created_at >= CURRENT_DATE;

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

  INSERT INTO public.mf_point_ledger (
    user_id,
    amount,
    balance_after,
    source,
    description,
    idempotency_key
  )
  VALUES (
    p_user_id,
    v_effective_amount,
    v_new_balance,
    p_source,
    p_description,
    p_idempotency_key
  );

  UPDATE public.user_mf_balance
  SET balance = v_new_balance,
      total_earned = v_total_earned,
      updated_at = timezone('utc', now())
  WHERE user_id = p_user_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- @XPEngine: app_open XP is also daily-idempotent.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_xp (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  xp_amount INTEGER NOT NULL DEFAULT 0,
  current_level INTEGER NOT NULL DEFAULT 1,
  current_streak INTEGER NOT NULL DEFAULT 0,
  last_activity_date DATE,
  weekly_xp INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.xp_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  xp_earned INTEGER NOT NULL,
  source TEXT NOT NULL,
  details JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE public.xp_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own xp events" ON public.xp_events;
CREATE POLICY "Users can view their own xp events"
  ON public.xp_events FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

ALTER TABLE public.user_xp ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all xp profiles" ON public.user_xp;
CREATE POLICY "Users can view all xp profiles"
  ON public.user_xp FOR SELECT
  TO authenticated
  USING (true);

DROP TRIGGER IF EXISTS before_xp_events_guard_app_open ON public.xp_events;
DROP FUNCTION IF EXISTS public.guard_daily_app_open_xp();

CREATE OR REPLACE FUNCTION public.award_daily_app_open_rewards()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.xp_events
    WHERE user_id = v_user_id
      AND source = 'app_open'
      AND created_at >= CURRENT_DATE
  ) THEN
    PERFORM public.add_user_xp(v_user_id, 10, 'app_open');
  END IF;

  PERFORM public.add_mf_points(
    v_user_id,
    5,
    'app_open',
    'Gunluk Giris Odulu',
    'app_open:' || v_user_id::text || ':' || CURRENT_DATE::text
  );
END;
$$;
