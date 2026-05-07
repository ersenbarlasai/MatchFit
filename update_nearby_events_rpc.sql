-- Update get_nearby_events RPC to include trust_score and bio
DROP FUNCTION IF EXISTS get_nearby_events(double precision, double precision, double precision);

CREATE OR REPLACE FUNCTION get_nearby_events(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION DEFAULT 10000
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  event_date DATE,
  start_time TIME,
  location_name TEXT,
  max_participants INTEGER,
  required_level TEXT,
  sport_id UUID,
  host_id UUID,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  distance DOUBLE PRECISION,
  sport_name TEXT,
  category TEXT,
  host_name TEXT,
  host_avatar TEXT,
  host_trust INTEGER,
  host_bio TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id,
    e.title,
    e.description,
    e.event_date,
    e.start_time,
    e.location_name,
    e.max_participants,
    e.required_level,
    e.sport_id,
    e.host_id,
    e.lat,
    e.lng,
    ST_Distance(e.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography) as distance,
    s.name as sport_name,
    s.category as category,
    p.full_name as host_name,
    p.avatar_url as host_avatar,
    COALESCE(p.trust_score, 0) as host_trust,
    p.bio as host_bio
  FROM public.events e
  JOIN public.sports s ON e.sport_id = s.id
  JOIN public.profiles p ON e.host_id = p.id
  WHERE e.status = 'open'
    AND ST_DWithin(e.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, radius_meters)
  ORDER BY distance ASC;
END;
$$ LANGUAGE plpgsql;
