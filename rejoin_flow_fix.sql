-- ============================================================
-- MatchFit: Rejection / Re-Join Flow Fix
-- Run this once in Supabase SQL Editor.
--
-- Rules:
-- 1. Host gets a normal notification for first join requests.
-- 2. Host gets a warning notification for second join requests.
-- 3. Applicant gets a rejection notification after each rejection.
-- 4. Second rejection message explains that the event is now locked.
-- ============================================================

ALTER TABLE public.event_participants
  ADD COLUMN IF NOT EXISTS rejection_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_rejected_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.notify_host_on_join_request()
RETURNS TRIGGER AS $$
DECLARE
  event_host_id UUID;
  event_title TEXT;
  sender_name TEXT;
  rejection_total INTEGER;
  notification_message TEXT;
BEGIN
  SELECT host_id, title INTO event_host_id, event_title
  FROM public.events
  WHERE id = NEW.event_id;

  SELECT full_name INTO sender_name
  FROM public.profiles
  WHERE id = NEW.user_id;

  IF NEW.status = 'pending' THEN
    rejection_total := COALESCE(NEW.rejection_count, 0);

    IF rejection_total > 0 THEN
      notification_message :=
        '⚠️ 2. BAŞVURU: ' || COALESCE(sender_name, 'Bir kullanıcı') ||
        ', "' || event_title || '" etkinliğine 2. kez başvuruyor. Daha önce reddedilmişti. Bu sefer de reddederseniz bir daha bu etkinliğe başvuramayacak.';
    ELSE
      notification_message :=
        COALESCE(sender_name, 'Bir kullanıcı') || ', "' || event_title || '" etkinliğine katılmak istiyor.';
    END IF;

    INSERT INTO public.notifications (receiver_id, sender_id, event_id, type, message)
    VALUES (event_host_id, NEW.user_id, NEW.event_id, 'join_request', notification_message);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
RETURNS TRIGGER AS $$
DECLARE
  event_title TEXT;
BEGIN
  SELECT title INTO event_title
  FROM public.events
  WHERE id = NEW.event_id;

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
    INSERT INTO public.notifications (receiver_id, sender_id, event_id, type, message)
    VALUES (
      NEW.user_id,
      NULL,
      NEW.event_id,
      'join_rejected',
      CASE
        WHEN COALESCE(NEW.rejection_count, 0) >= 2 THEN
          '"' || event_title || '" etkinliğine katılım isteğin etkinlik sahibi tarafından reddedildi. Bu etkinliğe tekrar başvuramazsın.'
        ELSE
          '"' || event_title || '" etkinliğine katılım isteğin etkinlik sahibi tarafından reddedildi. Yeniden başvurabilmek için 2 saat beklemelisin.'
      END
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_join_status_change ON public.event_participants;
CREATE TRIGGER on_join_status_change
  AFTER UPDATE ON public.event_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_user_on_status_change();
