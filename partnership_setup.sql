-- ==========================================
-- PARTNERSHIP SYSTEM SETUP
-- ==========================================

-- 1. Add accepts_partnership field to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS accepts_partnership BOOLEAN DEFAULT TRUE;

-- 2. Create user_partnerships table
CREATE TABLE IF NOT EXISTS public.user_partnerships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(sender_id, receiver_id)
);

-- 3. Enable RLS
ALTER TABLE public.user_partnerships ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
DROP POLICY IF EXISTS "Users can view their own partnerships" ON public.user_partnerships;
CREATE POLICY "Users can view their own partnerships"
ON public.user_partnerships FOR SELECT
TO authenticated
USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can send partnership requests" ON public.user_partnerships;
CREATE POLICY "Users can send partnership requests"
ON public.user_partnerships FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "Users can update their own received requests" ON public.user_partnerships;
CREATE POLICY "Users can update their own received requests"
ON public.user_partnerships FOR UPDATE
TO authenticated
USING (auth.uid() = receiver_id);
