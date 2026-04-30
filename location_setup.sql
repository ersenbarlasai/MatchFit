-- 1. PostGIS eklentisini etkinleştir (Zaten etkin olabilir)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Events tablosuna koordinat sütunu ekle
ALTER TABLE public.events 
ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS location geography(POINT);

-- 3. Mevcut lat/lng değerlerini location sütununa dönüştür (Eğer varsa)
CREATE OR REPLACE FUNCTION update_event_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.lat IS NOT NULL AND NEW.lng IS NOT NULL THEN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_update_event_location
BEFORE INSERT OR UPDATE ON public.events
FOR EACH ROW EXECUTE FUNCTION update_event_location();

-- 4. Coğrafi arama için RPC fonksiyonu
-- Bu fonksiyon kullanıcının konumuna göre mesafe filtreli arama yapar
CREATE OR REPLACE FUNCTION get_nearby_events(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION DEFAULT 10000 -- Varsayılan 10km
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
  host_name TEXT,
  host_avatar TEXT
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
    p.full_name as host_name,
    p.avatar_url as host_avatar
  FROM public.events e
  JOIN public.sports s ON e.sport_id = s.id
  JOIN public.profiles p ON e.host_id = p.id
  WHERE e.status = 'open'
    AND ST_DWithin(e.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, radius_meters)
  ORDER BY distance ASC;
END;
$$ LANGUAGE plpgsql;
