-- 1. Update profiles table with required scoring columns
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS trust_score INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS reliability_score INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS social_score INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS activity_score INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS no_show_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS streak_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_bench_mode BOOLEAN DEFAULT FALSE;

-- 2. Reset all existing users to the starting state (Score: 0, No Badges)
UPDATE public.profiles 
SET 
  trust_score = 0,
  reliability_score = 0,
  social_score = 0,
  activity_score = 0,
  no_show_count = 0,
  streak_count = 0,
  is_bench_mode = FALSE;

-- 3. Clear all user badges
-- Note: If you don't have a user_badges table yet, this part can be skipped or will error.
-- Assuming table exists based on TrustSystem provider.
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_badges') THEN
        TRUNCATE public.user_badges;
    END IF;
END $$;
