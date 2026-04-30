-- ==============================================================================
-- MatchFit Join Approval & Notification System
-- ==============================================================================

-- 1. Ensure event_participants has the correct status options
-- (If the table already exists, this is safe)
ALTER TABLE public.event_participants 
  DROP CONSTRAINT IF EXISTS event_participants_status_check;

ALTER TABLE public.event_participants 
  ADD CONSTRAINT event_participants_status_check 
  CHECK (status IN ('pending', 'joined', 'rejected'));

-- 2. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'join_request', 'join_approved', 'join_rejected'
  message TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT TO authenticated USING (auth.uid() = receiver_id);

-- 3. TRIGGER FOR JOIN REQUEST NOTIFICATION
-- When someone inserts into event_participants with status 'pending', notify the host.
CREATE OR REPLACE FUNCTION public.notify_host_on_join_request()
RETURNS TRIGGER AS $$
DECLARE
  event_host_id UUID;
  event_title TEXT;
  sender_name TEXT;
BEGIN
  -- Get event host and title
  SELECT host_id, title INTO event_host_id, event_title 
  FROM public.events WHERE id = NEW.event_id;
  
  -- Get sender name
  SELECT full_name INTO sender_name 
  FROM public.profiles WHERE id = NEW.user_id;

  IF NEW.status = 'pending' THEN
    INSERT INTO public.notifications (receiver_id, sender_id, event_id, type, message)
    VALUES (
      event_host_id, 
      NEW.user_id, 
      NEW.event_id, 
      'join_request', 
      sender_name || ' wants to join your event: ' || event_title
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_join_request ON public.event_participants;
CREATE TRIGGER on_join_request
  AFTER INSERT ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_host_on_join_request();

-- 4. TRIGGER FOR APPROVAL/REJECTION NOTIFICATION
CREATE OR REPLACE FUNCTION public.notify_user_on_status_change()
RETURNS TRIGGER AS $$
DECLARE
  event_title TEXT;
BEGIN
  SELECT title INTO event_title FROM public.events WHERE id = NEW.event_id;

  IF NEW.status = 'joined' AND OLD.status = 'pending' THEN
    INSERT INTO public.notifications (receiver_id, event_id, type, message)
    VALUES (NEW.user_id, NEW.event_id, 'join_approved', 'Your request to join "' || event_title || '" has been approved!');
  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    INSERT INTO public.notifications (receiver_id, event_id, type, message)
    VALUES (NEW.user_id, NEW.event_id, 'join_rejected', 'Your request to join "' || event_title || '" was not approved.');
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_join_status_change ON public.event_participants;
CREATE TRIGGER on_join_status_change
  AFTER UPDATE ON public.event_participants
  FOR EACH ROW EXECUTE FUNCTION public.notify_user_on_status_change();
