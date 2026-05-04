-- Update profiles table with new registration fields
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS birth_date DATE,
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS district TEXT;

-- Ensure user_sports_preferences table exists (if not already)
CREATE TABLE IF NOT EXISTS public.user_sports_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    sport_id UUID REFERENCES public.sports(id) ON DELETE CASCADE,
    skill_level TEXT DEFAULT 'beginner',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, sport_id)
);
