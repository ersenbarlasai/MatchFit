-- ============================================================
-- MatchFit: Notifications RLS Fix
-- Run this in Supabase SQL Editor if notifications are not arriving.
-- ============================================================

-- 1. Ensure the trigger function has SECURITY DEFINER (bypasses RLS)
--    Re-create it to be safe:
CREATE OR REPLACE FUNCTION public.notify_host_on_join_request()
RETURNS TRIGGER AS $$
DECLARE
  event_host_id UUID;
  event_title TEXT;
  sender_name TEXT;
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

-- 2. Re-attach trigger (safe even if it already exists)
DROP TRIGGER IF EXISTS on_join_request ON public.event_participants;
CREATE TRIGGER on_join_request
  AFTER INSERT ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_host_on_join_request();

-- 3. Also trigger for RE-JOIN (UPDATE from rejected -> pending)
DROP TRIGGER IF EXISTS on_join_request_update ON public.event_participants;
CREATE TRIGGER on_join_request_update
  AFTER UPDATE ON public.event_participants
  FOR EACH ROW
  WHEN (NEW.status = 'pending' AND OLD.status = 'rejected')
  EXECUTE FUNCTION public.notify_host_on_join_request();

-- 4. Ensure RLS policies are correct
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- SELECT: users can only read their own notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = receiver_id);

-- DELETE: users can delete their own notifications
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;
CREATE POLICY "Users can delete their own notifications"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (auth.uid() = receiver_id);

-- UPDATE: users can mark their own notifications as read
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = receiver_id);

-- NOTE: No INSERT policy needed for authenticated users —
-- Notifications are ONLY inserted by SECURITY DEFINER triggers.
-- This prevents users from spoofing notifications to others.
