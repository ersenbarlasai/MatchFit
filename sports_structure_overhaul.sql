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

-- 4. Update events table for new UX requirements
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS is_indoor BOOLEAN DEFAULT false;
