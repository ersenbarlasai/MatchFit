-- ==============================================================================
-- MatchFit: Direct Messaging System
-- ==============================================================================

-- 1. Create direct_messages table
CREATE TABLE IF NOT EXISTS public.direct_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. Enable RLS
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies
-- Users can only view messages where they are either the sender or the receiver
CREATE POLICY "Users can view their own messages" ON public.direct_messages
    FOR SELECT USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );

-- Users can only insert messages if they are the sender
CREATE POLICY "Users can send messages" ON public.direct_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id
    );

-- Users can only update messages to mark them as read (if they are the receiver)
CREATE POLICY "Users can mark received messages as read" ON public.direct_messages
    FOR UPDATE USING (
        auth.uid() = receiver_id
    );

-- 4. Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_direct_messages_sender_receiver ON public.direct_messages(sender_id, receiver_id);
CREATE INDEX IF NOT EXISTS idx_direct_messages_created_at ON public.direct_messages(created_at);

-- 5. Set up realtime for direct_messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages;
