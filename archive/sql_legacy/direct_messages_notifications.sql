-- ==============================================================================
-- MatchFit: Direct Messages Notifications Trigger
-- ==============================================================================

-- Function to handle new message notifications
CREATE OR REPLACE FUNCTION public.handle_new_message_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
BEGIN
    -- Only create a notification if it's the first unread message in the last minute
    -- to avoid spamming notifications for every single message.
    -- We can just create one for each for simplicity, or we can check.
    -- For now, create a notification for every message to ensure they get it.
    
    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;

    INSERT INTO public.notifications (
        receiver_id,
        sender_id,
        type,
        title,
        message
    ) VALUES (
        NEW.receiver_id,
        NEW.sender_id,
        'new_message',
        'Yeni Mesaj: ' || COALESCE(v_sender_name, 'Kullanıcı'),
        NEW.content
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for direct_messages
DROP TRIGGER IF EXISTS on_direct_message_inserted ON public.direct_messages;

CREATE TRIGGER on_direct_message_inserted
AFTER INSERT ON public.direct_messages
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_message_notification();
