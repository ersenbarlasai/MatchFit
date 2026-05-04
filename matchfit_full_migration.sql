-- ============================================================
-- MatchFit: Full Migration Script
-- Run this ONCE in Supabase SQL Editor (Dashboard → SQL Editor)
-- Safe to re-run (uses IF NOT EXISTS and CREATE OR REPLACE)
-- ============================================================

-- ── STEP 1: event_participants kolonları ────────────────────
ALTER TABLE public.event_participants
  ADD COLUMN IF NOT EXISTS rejection_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_rejected_at TIMESTAMPTZ;

-- ── STEP 2: Status constraint güncelle ──────────────────────
ALTER TABLE public.event_participants
  DROP CONSTRAINT IF EXISTS event_participants_status_check;

ALTER TABLE public.event_participants
  ADD CONSTRAINT event_participants_status_check
  CHECK (status IN ('pending', 'joined', 'rejected'));

-- ── STEP 3: notifications tablosu ───────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_id    UUID REFERENCES public.events(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,
  message     TEXT,
  title       TEXT,
  is_read     BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- Eski şemada title/content yoksa güvenli ekle
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;

-- ── STEP 4: RLS politikaları ─────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notifications"   ON public.notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;

CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT TO authenticated
  USING (auth.uid() = receiver_id);

CREATE POLICY "Users can delete their own notifications"
  ON public.notifications FOR DELETE TO authenticated
  USING (auth.uid() = receiver_id);

CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE TO authenticated
  USING (auth.uid() = receiver_id);

-- ── STEP 5: JOIN REQUEST trigger (INSERT) ────────────────────
CREATE OR REPLACE FUNCTION public.notify_host_on_join_request()
RETURNS TRIGGER AS $$
DECLARE
  event_host_id UUID;
  event_title   TEXT;
  sender_name   TEXT;
BEGIN
  SELECT host_id, title INTO event_host_id, event_title
  FROM public.events WHERE id = NEW.event_id;

  SELECT full_name INTO sender_name
  FROM public.profiles WHERE id = NEW.user_id;

  IF NEW.status = 'pending' THEN
    INSERT INTO public.notifications (receiver_id, sender_id, event_id, type, message)
    VALUES (
      event_host_id,
      NEW.user_id,
      NEW.event_id,
      'join_request',
      sender_name || ', "' || event_title || '" etkinliğine katılmak istiyor.'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- INSERT trigger (yeni katılım)
DROP TRIGGER IF EXISTS on_join_request ON public.event_participants;
CREATE TRIGGER on_join_request
  AFTER INSERT ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_host_on_join_request();

-- UPDATE trigger (rejected → pending: tekrar katılma)
DROP TRIGGER IF EXISTS on_join_request_update ON public.event_participants;
CREATE TRIGGER on_join_request_update
  AFTER UPDATE ON public.event_participants
  FOR EACH ROW
  WHEN (NEW.status = 'pending' AND OLD.status = 'rejected')
  EXECUTE FUNCTION public.notify_host_on_join_request();

-- ── STEP 6: STATUS CHANGE trigger (onay/ret bildirimi) ───────
CREATE OR REPLACE FUNCTION public.notify_user_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
  event_title TEXT;
BEGIN
  SELECT title INTO event_title FROM public.events WHERE id = NEW.event_id;

  IF NEW.status = 'joined' AND OLD.status = 'pending' THEN
    INSERT INTO public.notifications (receiver_id, sender_id, event_id, type, message)
    VALUES (
      NEW.user_id,
      NULL,
      NEW.event_id,
      'join_approved',
      '"' || event_title || '" etkinliğine katılımın onaylandı! 🎉'
    );
  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    -- Güncelle: rejection_count artır ve last_rejected_at yaz
    UPDATE public.event_participants
    SET
      rejection_count   = COALESCE(rejection_count, 0) + 1,
      last_rejected_at  = NOW()
    WHERE event_id = NEW.event_id AND user_id = NEW.user_id;

    INSERT INTO public.notifications (receiver_id, sender_id, event_id, type, message)
    VALUES (
      NEW.user_id,
      NULL,
      NEW.event_id,
      'join_rejected',
      '"' || event_title || '" etkinliğine katılım isteğin reddedildi.'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_join_status_change ON public.event_participants;
CREATE TRIGGER on_join_status_change
  AFTER UPDATE ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_user_on_status_change();
