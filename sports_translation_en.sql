-- Update sports table names and categories to English
-- RACKET SPORTS
UPDATE public.sports SET name = 'Tennis', category = 'RACKET SPORTS' WHERE name = 'Tenis';
UPDATE public.sports SET name = 'Padel', category = 'RACKET SPORTS' WHERE name = 'Padel';
UPDATE public.sports SET name = 'Table Tennis', category = 'RACKET SPORTS' WHERE name = 'Masa Tenisi';

-- TEAM SPORTS
UPDATE public.sports SET name = 'Basketball', category = 'TEAM SPORTS' WHERE name = 'Basketbol';
UPDATE public.sports SET name = 'Football / Soccer', category = 'TEAM SPORTS' WHERE name = 'Futbol / Halı Saha';
UPDATE public.sports SET name = 'Volleyball', category = 'TEAM SPORTS' WHERE name = 'Voleybol';

-- RUNNING & CARDIO
UPDATE public.sports SET name = 'Road Running', category = 'RUNNING & CARDIO' WHERE name = 'Yol Koşusu';
UPDATE public.sports SET name = 'Trail Run', category = 'RUNNING & CARDIO' WHERE name = 'Trail Run';
UPDATE public.sports SET name = 'Sprint / Interval', category = 'RUNNING & CARDIO' WHERE name = 'Sprint / Interval';

-- CYCLING
UPDATE public.sports SET name = 'Road Cycling', category = 'CYCLING' WHERE name = 'Yol Bisikleti';
UPDATE public.sports SET name = 'Mountain Bike (MTB)', category = 'CYCLING' WHERE name = 'MTB (Dağ Bisikleti)';
UPDATE public.sports SET name = 'City / Group Ride', category = 'CYCLING' WHERE name = 'Şehir / Grup Sürüşü';

-- FITNESS & GYM
UPDATE public.sports SET name = 'Weight Training', category = 'FITNESS & GYM' WHERE name = 'Ağırlık Antrenmanı';
UPDATE public.sports SET name = 'Functional Training', category = 'FITNESS & GYM' WHERE name = 'Functional Training';
UPDATE public.sports SET name = 'Cross Training', category = 'FITNESS & GYM' WHERE name = 'Cross Training';

-- WALKING & HIKING
UPDATE public.sports SET name = 'Brisk Walking', category = 'WALKING & HIKING' WHERE name = 'Tempolu Yürüyüş';
UPDATE public.sports SET name = 'Trekking', category = 'WALKING & HIKING' WHERE name = 'Trekking';
UPDATE public.sports SET name = 'Nature Walk', category = 'WALKING & HIKING' WHERE name = 'Doğa Yürüyüşü';

-- WATER SPORTS
UPDATE public.sports SET name = 'Swimming', category = 'WATER SPORTS' WHERE name = 'Yüzme';
UPDATE public.sports SET name = 'Rowing / Paddle', category = 'WATER SPORTS' WHERE name = 'Kürek / Paddle';
UPDATE public.sports SET name = 'Surf / SUP', category = 'WATER SPORTS' WHERE name = 'Sörf / SUP';

-- COMBAT SPORTS
UPDATE public.sports SET name = 'Boxing', category = 'COMBAT SPORTS' WHERE name = 'Boks';
UPDATE public.sports SET name = 'Kickboxing / MMA', category = 'COMBAT SPORTS' WHERE name = 'Kick Boks / MMA';
UPDATE public.sports SET name = 'Jiu Jitsu / Grappling', category = 'COMBAT SPORTS' WHERE name = 'Jiu Jitsu / Grappling';

-- MIND & BALANCE
UPDATE public.sports SET name = 'Yoga', category = 'MIND & BALANCE' WHERE name = 'Yoga';
UPDATE public.sports SET name = 'Pilates', category = 'MIND & BALANCE' WHERE name = 'Pilates';
UPDATE public.sports SET name = 'Meditation Movement', category = 'MIND & BALANCE' WHERE name = 'Meditasyon Hareketi';

-- WINTER & EXTREME
UPDATE public.sports SET name = 'Skiing / Snowboard', category = 'WINTER & EXTREME' WHERE name = 'Kayak / Snowboard';
UPDATE public.sports SET name = 'Climbing / Boulder', category = 'WINTER & EXTREME' WHERE name = 'Tırmanış / Boulder';
UPDATE public.sports SET name = 'Skate / Roller', category = 'WINTER & EXTREME' WHERE name = 'Skate / Roller';

-- YOUTH & URBAN SPORTS
UPDATE public.sports SET name = 'Calisthenics', category = 'YOUTH & URBAN SPORTS' WHERE name = 'Calisthenics';
UPDATE public.sports SET name = 'Street Workout', category = 'YOUTH & URBAN SPORTS' WHERE name = 'Street Workout';
UPDATE public.sports SET name = 'Parkour', category = 'YOUTH & URBAN SPORTS' WHERE name = 'Parkour';

-- MOTOR SPORTS
UPDATE public.sports SET name = 'Motocross', category = 'MOTOR SPORTS' WHERE name = 'Motocross';
UPDATE public.sports SET name = 'ATV Ride', category = 'MOTOR SPORTS' WHERE name = 'ATV Ride';
UPDATE public.sports SET name = 'Enduro Group Ride', category = 'MOTOR SPORTS' WHERE name = 'Enduro Grup Sürüşü';
