-- Revert sports table names and categories to Turkish
-- RAKET SPORLARI
UPDATE public.sports SET name = 'Tenis', category = 'RAKET SPORLARI' WHERE name = 'Tennis';
UPDATE public.sports SET name = 'Padel', category = 'RAKET SPORLARI' WHERE name = 'Padel';
UPDATE public.sports SET name = 'Masa Tenisi', category = 'RAKET SPORLARI' WHERE name = 'Table Tennis';

-- TAKIM SPORLARI
UPDATE public.sports SET name = 'Basketbol', category = 'TAKIM SPORLARI' WHERE name = 'Basketball';
UPDATE public.sports SET name = 'Futbol / Halı Saha', category = 'TAKIM SPORLARI' WHERE name = 'Football / Soccer';
UPDATE public.sports SET name = 'Voleybol', category = 'TAKIM SPORLARI' WHERE name = 'Volleyball';

-- KOŞU & KARDİYO
UPDATE public.sports SET name = 'Yol Koşusu', category = 'KOŞU & KARDİYO' WHERE name = 'Road Running';
UPDATE public.sports SET name = 'Trail Run', category = 'KOŞU & KARDİYO' WHERE name = 'Trail Run';
UPDATE public.sports SET name = 'Sprint / Interval', category = 'KOŞU & KARDİYO' WHERE name = 'Sprint / Interval';

-- BİSİKLET
UPDATE public.sports SET name = 'Yol Bisikleti', category = 'BİSİKLET' WHERE name = 'Road Cycling';
UPDATE public.sports SET name = 'MTB (Dağ Bisikleti)', category = 'BİSİKLET' WHERE name = 'Mountain Bike (MTB)';
UPDATE public.sports SET name = 'Şehir / Grup Sürüşü', category = 'BİSİKLET' WHERE name = 'City / Group Ride';

-- FITNESS & GYM
UPDATE public.sports SET name = 'Ağırlık Antrenmanı', category = 'FITNESS & GYM' WHERE name = 'Weight Training';
UPDATE public.sports SET name = 'Functional Training', category = 'FITNESS & GYM' WHERE name = 'Functional Training';
UPDATE public.sports SET name = 'Cross Training', category = 'FITNESS & GYM' WHERE name = 'Cross Training';

-- YÜRÜYÜŞ & HIKING
UPDATE public.sports SET name = 'Tempolu Yürüyüş', category = 'YÜRÜYÜŞ & HIKING' WHERE name = 'Brisk Walking';
UPDATE public.sports SET name = 'Trekking', category = 'YÜRÜYÜŞ & HIKING' WHERE name = 'Trekking';
UPDATE public.sports SET name = 'Doğa Yürüyüşü', category = 'YÜRÜYÜŞ & HIKING' WHERE name = 'Nature Walk';

-- SU SPORLARI
UPDATE public.sports SET name = 'Yüzme', category = 'SU SPORLARI' WHERE name = 'Swimming';
UPDATE public.sports SET name = 'Kürek / Paddle', category = 'SU SPORLARI' WHERE name = 'Rowing / Paddle';
UPDATE public.sports SET name = 'Sörf / SUP', category = 'SU SPORLARI' WHERE name = 'Surf / SUP';

-- DÖVÜŞ SPORLARI
UPDATE public.sports SET name = 'Boks', category = 'DÖVÜŞ SPORLARI' WHERE name = 'Boxing';
UPDATE public.sports SET name = 'Kick Boks / MMA', category = 'DÖVÜŞ SPORLARI' WHERE name = 'Kickboxing / MMA';
UPDATE public.sports SET name = 'Jiu Jitsu / Grappling', category = 'DÖVÜŞ SPORLARI' WHERE name = 'Jiu Jitsu / Grappling';

-- ZİHİN & DENGE
UPDATE public.sports SET name = 'Yoga', category = 'ZİHİN & DENGE' WHERE name = 'Yoga';
UPDATE public.sports SET name = 'Pilates', category = 'ZİHİN & DENGE' WHERE name = 'Pilates';
UPDATE public.sports SET name = 'Meditasyon Hareketi', category = 'ZİHİN & DENGE' WHERE name = 'Meditation Movement';

-- KIŞ & EKSTREM
UPDATE public.sports SET name = 'Kayak / Snowboard', category = 'KIŞ & EKSTREM' WHERE name = 'Skiing / Snowboard';
UPDATE public.sports SET name = 'Tırmanış / Boulder', category = 'KIŞ & EKSTREM' WHERE name = 'Climbing / Boulder';
UPDATE public.sports SET name = 'Skate / Roller', category = 'KIŞ & EKSTREM' WHERE name = 'Skate / Roller';

-- GENÇLİK & URBAN SPORTS
UPDATE public.sports SET name = 'Calisthenics', category = 'GENÇLİK & URBAN SPORTS' WHERE name = 'Calisthenics';
UPDATE public.sports SET name = 'Street Workout', category = 'GENÇLİK & URBAN SPORTS' WHERE name = 'Street Workout';
UPDATE public.sports SET name = 'Parkour', category = 'GENÇLİK & URBAN SPORTS' WHERE name = 'Parkour';

-- MOTORLU AKTİVİTE
UPDATE public.sports SET name = 'Motocross', category = 'MOTORLU AKTİVİTE' WHERE name = 'Motocross';
UPDATE public.sports SET name = 'ATV Ride', category = 'MOTORLU AKTİVİTE' WHERE name = 'ATV Ride';
UPDATE public.sports SET name = 'Enduro Grup Sürüşü', category = 'MOTORLU AKTİVİTE' WHERE name = 'Enduro Group Ride';
