-- 1. Profillere koordinat ekle
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS location geography(POINT);

-- 2. Profillerin koordinatlarını senkronize eden trigger
CREATE OR REPLACE FUNCTION update_profile_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_update_profile_location ON public.profiles;
CREATE TRIGGER tr_update_profile_location
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION update_profile_location();

-- 3. Matchmaker RPC Fonksiyonu (25km çapında, ortak ilgi alanlarına sahip kullanıcılar)
CREATE OR REPLACE FUNCTION get_recommended_users(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION DEFAULT 25000 -- 25km
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  avatar_url TEXT,
  trust_score INTEGER,
  distance DOUBLE PRECISION,
  shared_sports TEXT[] -- JSON array yerine metin dizisi
) AS $$
BEGIN
  RETURN QUERY
  WITH current_user_sports AS (
    SELECT sport_id FROM public.user_sports_preferences WHERE user_id = auth.uid()
  ),
  matching_users AS (
    SELECT 
      p.id,
      p.full_name,
      p.avatar_url,
      p.trust_score,
      ST_Distance(p.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography) as distance
    FROM public.profiles p
    WHERE p.id != auth.uid()
      AND p.location IS NOT NULL
      AND ST_DWithin(p.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, radius_meters)
  )
  SELECT 
    m.id,
    m.full_name,
    m.avatar_url,
    m.trust_score,
    m.distance,
    ARRAY(
      SELECT s.name 
      FROM public.user_sports_preferences usp
      JOIN public.sports s ON s.id = usp.sport_id
      WHERE usp.user_id = m.id AND usp.sport_id IN (SELECT sport_id FROM current_user_sports)
    ) as shared_sports
  FROM matching_users m
  WHERE EXISTS (
    -- Sadece en az 1 ortak spor olanları getir
    SELECT 1 FROM public.user_sports_preferences usp
    WHERE usp.user_id = m.id AND usp.sport_id IN (SELECT sport_id FROM current_user_sports)
  )
  ORDER BY m.distance ASC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;
