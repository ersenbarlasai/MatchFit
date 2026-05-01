-- ==========================================
-- SPORTS STRUCTURE OVERHAUL
-- ==========================================

-- 1. Update sports table structure
ALTER TABLE public.sports ADD COLUMN IF NOT EXISTS category TEXT;

-- 2. Clear old data to avoid foreign key violations
-- WARNING: This will delete existing events and preferences to allow the structural overhaul.
DELETE FROM public.event_participants;
DELETE FROM public.events;
DELETE FROM public.user_sports_preferences;
DELETE FROM public.sports;

-- 3. Seed new sports data
INSERT INTO public.sports (category, name) VALUES
('RAKET SPORLARI', 'Tenis'),
('RAKET SPORLARI', 'Padel'),
('RAKET SPORLARI', 'Masa Tenisi'),

('TAKIM SPORLARI', 'Basketbol'),
('TAKIM SPORLARI', 'Futbol / Halı Saha'),
('TAKIM SPORLARI', 'Voleybol'),

('KOŞU & KARDİYO', 'Yol Koşusu'),
('KOŞU & KARDİYO', 'Trail Run'),
('KOŞU & KARDİYO', 'Sprint / Interval'),

('BİSİKLET', 'Yol Bisikleti'),
('BİSİKLET', 'MTB (Dağ Bisikleti)'),
('BİSİKLET', 'Şehir / Grup Sürüşü'),

('FITNESS & GYM', 'Ağırlık Antrenmanı'),
('FITNESS & GYM', 'Functional Training'),
('FITNESS & GYM', 'Cross Training'),

('YÜRÜYÜŞ & HIKING', 'Tempolu Yürüyüş'),
('YÜRÜYÜŞ & HIKING', 'Trekking'),
('YÜRÜYÜŞ & HIKING', 'Doğa Yürüyüşü'),

('SU SPORLARI', 'Yüzme'),
('SU SPORLARI', 'Kürek / Paddle'),
('SU SPORLARI', 'Sörf / SUP'),

('DÖVÜŞ SPORLARI', 'Boks'),
('DÖVÜŞ SPORLARI', 'Kick Boks / MMA'),
('DÖVÜŞ SPORLARI', 'Jiu Jitsu / Grappling'),

('ZİHİN & DENGE', 'Yoga'),
('ZİHİN & DENGE', 'Pilates'),
('ZİHİN & DENGE', 'Meditasyon Hareketi'),

('KIŞ & EKSTREM', 'Kayak / Snowboard'),
('KIŞ & EKSTREM', 'Tırmanış / Boulder'),
('KIŞ & EKSTREM', 'Skate / Roller'),

('GENÇLİK & URBAN SPORTS', 'Calisthenics'),
('GENÇLİK & URBAN SPORTS', 'Street Workout'),
('GENÇLİK & URBAN SPORTS', 'Parkour'),

('MOTORLU AKTİVİTE', 'Motocross'),
('MOTORLU AKTİVİTE', 'ATV Ride'),
('MOTORLU AKTİVİTE', 'Enduro Grup Sürüşü');

-- 4. Update get_nearby_events RPC to include category
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
    s.category as category,
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

-- 4. Update events table for new UX requirements
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS is_indoor BOOLEAN DEFAULT false;
