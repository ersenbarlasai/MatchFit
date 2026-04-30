-- ==============================================================================
-- @Guardian, @ContentManager, @Matchmaker Ajanları Veritabanı Kurulumu
-- Bu SQL kodlarını kopyalayıp Supabase panelinizdeki "SQL Editor" kısmına yapıştırın.
-- ==============================================================================

-- ==========================================
-- @GUARDIAN AGENT (Güvenlik ve Doğrulama)
-- ==========================================

-- 1. KULLANICI GİZLİLİK AYARLARI (Strava Gizli Bölge Mantığı)
CREATE TABLE IF NOT EXISTS public.privacy_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_visibility TEXT DEFAULT 'public', -- 'public', 'friends_only', 'private'
  hide_location_radius INTEGER DEFAULT 0, -- Metre cinsinden gizlenecek alan (ev çevresi vb.)
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.privacy_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their privacy" ON public.privacy_settings
  FOR ALL TO authenticated USING (auth.uid() = user_id);

-- 2. MODERASYON VE UYARI LOGLARI (Sohbet ve Davranış Taraması)
CREATE TABLE IF NOT EXISTS public.moderation_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  flag_type TEXT NOT NULL, -- 'profanity', 'scam_iban', 'harassment'
  context TEXT NOT NULL, -- "IBAN at" gibi sistemin yakaladığı metin
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.moderation_logs ENABLE ROW LEVEL SECURITY;
-- Sadece sistem/admin yazabilir, RLS policy adminlere özel olmalı veya app backend kullanmalı

-- ==========================================
-- @CONTENTMANAGER AGENT (Sosyal Akış ve Medya)
-- ==========================================

-- 3. SOSYAL DUVAR (Posts Tablosu)
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id UUID REFERENCES public.events(id) ON DELETE SET NULL, -- Opsiyonel (Etkinlik kartı için)
  media_url TEXT,
  caption TEXT,
  visibility TEXT DEFAULT 'public', -- 'public', 'friends_only'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Mevcut tablo önceden varsa sütunları güvene alalım
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'public';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_id UUID REFERENCES public.events(id) ON DELETE SET NULL;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS caption TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS media_url TEXT;

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view public posts" ON public.posts FOR SELECT USING (visibility = 'public');
CREATE POLICY "Users can insert own posts" ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 4. ETİKETLEME ONAY SİSTEMİ (Post Tags)
CREATE TABLE IF NOT EXISTS public.post_tags (
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  tagged_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (post_id, tagged_user_id)
);

ALTER TABLE public.post_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Tagged users can manage tags" ON public.post_tags
  FOR ALL TO authenticated USING (auth.uid() = tagged_user_id OR auth.uid() IN (SELECT user_id FROM public.posts WHERE id = post_id));

-- ==========================================
-- @MATCHMAKER AGENT (Eşleşme Uzmanı)
-- ==========================================

-- 5. KULLANICI SPOR TERCİHLERİ VE SEVİYELERİ
CREATE TABLE IF NOT EXISTS public.user_sports_preferences (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  sport_id UUID REFERENCES public.sports(id) ON DELETE CASCADE,
  skill_level TEXT NOT NULL, -- 'beginner', 'intermediate', 'advanced'
  preferred_radius_km INTEGER DEFAULT 10,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (user_id, sport_id)
);

ALTER TABLE public.user_sports_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their sport prefs" ON public.user_sports_preferences
  FOR ALL TO authenticated USING (auth.uid() = user_id);
