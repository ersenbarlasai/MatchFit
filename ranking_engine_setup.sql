-- ==============================================================================
-- @RankingEngine Agent Veritabanı Kurulumu (Supabase SQL Editor)
-- ==============================================================================

-- 1. LİG TABLOSU VE DURUMU (User Leagues)
CREATE TABLE IF NOT EXISTS public.user_leagues (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  league_name TEXT NOT NULL DEFAULT 'Bronze', -- Bronze, Silver, Gold, Platinum, Elite
  rank_score NUMERIC NOT NULL DEFAULT 0,
  global_rank INTEGER,
  city_rank INTEGER,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- user_xp tablosuna weekly_xp eklentisi (eğer yoksa eklenecek)
ALTER TABLE public.user_xp ADD COLUMN IF NOT EXISTS weekly_xp INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS abuse_status TEXT DEFAULT 'clean'; -- 'clean', 'low_variation', 'suspicious', 'confirmed_abuse'


ALTER TABLE public.user_leagues ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all leagues" ON public.user_leagues;
CREATE POLICY "Users can view all leagues"
ON public.user_leagues FOR SELECT TO authenticated USING (true);

-- 2. SIRALAMA VE SKOR HESAPLAMA GÖRÜNÜMÜ (View)
-- RankScore = XP * TrustMultiplier * ActivityFactor
CREATE OR REPLACE VIEW public.vw_leaderboard AS
SELECT 
    p.id AS user_id,
    p.full_name,
    p.avatar_url,
    p.city,
    p.trust_score,
    COALESCE(x.xp_amount, 0) AS xp_amount,
    COALESCE(x.current_level, 1) AS level,
    -- Rank Score Hesaplama
    (
        COALESCE(x.xp_amount, 0) 
        * 
        -- STEP 2: Trust Multiplier
        CASE 
            WHEN p.trust_score >= 80 THEN 1.2
            WHEN p.trust_score >= 60 THEN 1.1
            WHEN p.trust_score >= 40 THEN 1.0
            ELSE 0.7
        END
        *
        -- STEP 3: Activity Factor
        CASE 
            WHEN x.last_activity_date >= CURRENT_DATE - INTERVAL '1 day' THEN 1.1
            WHEN x.last_activity_date >= CURRENT_DATE - INTERVAL '3 days' THEN 1.0
            WHEN x.last_activity_date >= CURRENT_DATE - INTERVAL '7 days' THEN 0.9
            ELSE 0.75
        END
        *
        -- STEP 4: Abuse Adjustment
        CASE
            WHEN p.abuse_status = 'confirmed_abuse' THEN 0.4
            WHEN p.abuse_status = 'suspicious' THEN 0.7
            WHEN p.abuse_status = 'low_variation' THEN 0.95
            ELSE 1.0
        END
    ) AS rank_score,
    -- League Belirleme (STEP 5)
    CASE 
        WHEN COALESCE(x.xp_amount, 0) >= 15000 THEN 'Elite'
        WHEN COALESCE(x.xp_amount, 0) >= 7000 THEN 'Platinum'
        WHEN COALESCE(x.xp_amount, 0) >= 3000 THEN 'Gold'
        WHEN COALESCE(x.xp_amount, 0) >= 1000 THEN 'Silver'
        ELSE 'Bronze'
    END AS league
FROM public.profiles p
LEFT JOIN public.user_xp x ON p.id = x.user_id
WHERE p.full_name IS NOT NULL;

-- 3. GLOBAL LEADERBOARD GETİRME FONKSİYONU
CREATE OR REPLACE FUNCTION public.get_global_leaderboard(p_limit INTEGER DEFAULT 100)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    avatar_url TEXT,
    city TEXT,
    trust_score INTEGER,
    xp_amount INTEGER,
    level INTEGER,
    rank_score NUMERIC,
    league TEXT,
    global_rank BIGINT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT 
        v.user_id,
        v.full_name,
        v.avatar_url,
        v.city,
        v.trust_score,
        v.xp_amount,
        v.level,
        v.rank_score,
        v.league,
        ROW_NUMBER() OVER(ORDER BY v.rank_score DESC, v.trust_score DESC) as global_rank
    FROM public.vw_leaderboard v
    LIMIT p_limit;
$$;

-- 4. CITY (LOKAL) LEADERBOARD GETİRME FONKSİYONU
CREATE OR REPLACE FUNCTION public.get_city_leaderboard(p_city TEXT, p_limit INTEGER DEFAULT 100)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    avatar_url TEXT,
    city TEXT,
    trust_score INTEGER,
    xp_amount INTEGER,
    level INTEGER,
    rank_score NUMERIC,
    league TEXT,
    city_rank BIGINT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT 
        v.user_id,
        v.full_name,
        v.avatar_url,
        v.city,
        v.trust_score,
        v.xp_amount,
        v.level,
        v.rank_score,
        v.league,
        ROW_NUMBER() OVER(ORDER BY v.rank_score DESC, v.trust_score DESC) as city_rank
    FROM public.vw_leaderboard v
    WHERE v.city = p_city
    LIMIT p_limit;
$$;

-- 5. FRIENDS LEADERBOARD GETİRME FONKSİYONU
CREATE OR REPLACE FUNCTION public.get_friends_leaderboard(p_user_id UUID, p_limit INTEGER DEFAULT 100)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    avatar_url TEXT,
    city TEXT,
    trust_score INTEGER,
    xp_amount INTEGER,
    level INTEGER,
    rank_score NUMERIC,
    league TEXT,
    friend_rank BIGINT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT 
        v.user_id,
        v.full_name,
        v.avatar_url,
        v.city,
        v.trust_score,
        v.xp_amount,
        v.level,
        v.rank_score,
        v.league,
        ROW_NUMBER() OVER(ORDER BY v.rank_score DESC, v.trust_score DESC) as friend_rank
    FROM public.vw_leaderboard v
    WHERE v.user_id = p_user_id
       OR v.user_id IN (
           SELECT receiver_id FROM public.user_relationships WHERE sender_id = p_user_id AND status = 'following'
           UNION
           SELECT sender_id FROM public.user_relationships WHERE receiver_id = p_user_id AND status = 'following'
       )
    LIMIT p_limit;
$$;

-- 6. UNIFIED LEADERBOARD GETİRME FONKSİYONU (City ve Sport Filter desteği)
CREATE OR REPLACE FUNCTION public.get_filtered_leaderboard(
    p_city TEXT DEFAULT NULL,
    p_sport_name TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    avatar_url TEXT,
    city TEXT,
    trust_score INTEGER,
    xp_amount INTEGER,
    level INTEGER,
    rank_score NUMERIC,
    league TEXT,
    global_rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.user_id,
        v.full_name,
        v.avatar_url,
        v.city,
        v.trust_score,
        v.xp_amount,
        v.level,
        v.rank_score,
        v.league,
        ROW_NUMBER() OVER(ORDER BY v.rank_score DESC, v.trust_score DESC) as global_rank
    FROM public.vw_leaderboard v
    WHERE (
          p_city IS NULL OR p_city = 'Tüm Şehirler' OR
          EXISTS (
              SELECT 1 
              FROM public.events e
              LEFT JOIN public.event_participants ep ON e.id = ep.event_id
              WHERE e.status = 'completed'
                AND TRIM(split_part(e.location_name, ',', 2)) = p_city
                AND (e.host_id = v.user_id OR ep.user_id = v.user_id)
          )
      )
      AND (
          p_sport_name IS NULL OR p_sport_name = 'Tüm Branşlar' OR
          EXISTS (
              SELECT 1 
              FROM public.user_sports_preferences usp
              JOIN public.sports s ON usp.sport_id = s.id
              WHERE usp.user_id = v.user_id AND s.name = p_sport_name
          )
      )
    LIMIT p_limit;
END;
$$;

-- 7. ETKİNLİK AÇILAN ŞEHİRLERİ GETİRME
CREATE OR REPLACE FUNCTION public.get_active_event_cities()
RETURNS TABLE (city TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT TRIM(split_part(location_name, ',', 2)) AS city
    FROM public.events
    WHERE location_name IS NOT NULL 
      AND location_name LIKE '%,%,%'
      AND status = 'completed';
END;
$$;

-- 8. WEEKLY LEADERBOARD GETİRME FONKSİYONU
CREATE OR REPLACE FUNCTION public.get_weekly_leaderboard(p_limit INTEGER DEFAULT 100)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    avatar_url TEXT,
    city TEXT,
    trust_score INTEGER,
    xp_amount INTEGER,
    level INTEGER,
    rank_score NUMERIC,
    league TEXT,
    weekly_rank BIGINT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT 
        v.user_id,
        v.full_name,
        v.avatar_url,
        v.city,
        v.trust_score,
        COALESCE(ux.weekly_xp, 0) as xp_amount,
        v.level,
        -- Calculate weekly rank score using weekly_xp
        COALESCE(
            COALESCE(ux.weekly_xp, 0) * (v.rank_score / NULLIF(v.xp_amount, 0)), 
            0
        ) as rank_score,
        v.league,
        ROW_NUMBER() OVER(
            ORDER BY COALESCE(COALESCE(ux.weekly_xp, 0) * (v.rank_score / NULLIF(v.xp_amount, 0)), 0) DESC, 
            v.trust_score DESC
        ) as weekly_rank
    FROM public.vw_leaderboard v
    LEFT JOIN public.user_xp ux ON v.user_id = ux.user_id
    LIMIT p_limit;
$$;

-- 9. HAFTALIK SIFIRLAMA (WEEKLY RESET LOGIC)
-- Bu fonksiyon pg_cron veya bir external scheduler ile her Pazartesi çalıştırılmalıdır.
CREATE OR REPLACE FUNCTION public.reset_weekly_leaderboard()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- İstendiğinde önceki haftanın verilerini arşive taşıyabiliriz. (MVP'de sadece sıfırlama yapılıyor)
    UPDATE public.user_xp SET weekly_xp = 0;
END;
$$;
