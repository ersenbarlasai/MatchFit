-- ==============================================================================
-- @Referee Agent Veritabanı Kurulumu (Supabase SQL Editor)
-- Bu SQL kodlarını kopyalayıp Supabase panelinizdeki "SQL Editor" kısmına
-- yapıştırarak çalıştırın.
-- ==============================================================================

-- 1. CEZA VE GÖZLEM TABLOSU (User Penalties)
-- Kullanıcıların uyarılarını, sarı kartlarını ve shadow ban durumlarını tutar.
CREATE TABLE IF NOT EXISTS public.user_penalties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  offense_level INTEGER NOT NULL, -- 1: Uyarı, 2: Kısıtlama (48s), 3: Uzaklaştırma (1 Hafta)
  status TEXT NOT NULL DEFAULT 'active', -- 'active' veya 'expired'
  reason TEXT NOT NULL, -- Örneğin: "Etkinliğe mazeretsiz katılmama"
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  expires_at TIMESTAMP WITH TIME ZONE
);

-- RLS (Güvenlik) Ayarları
ALTER TABLE public.user_penalties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own penalties"
ON public.user_penalties FOR SELECT
TO authenticated
USING (auth.uid() = user_id);


-- 2. CHECK-IN VE DOĞRULAMA TABLOSU (Event Check-ins)
-- Kullanıcıların sahaya gidip gitmediğini GPS ve zaman damgasıyla kaydeder.
CREATE TABLE IF NOT EXISTS public.event_checkins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  checkin_time TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  location_lat DOUBLE PRECISION,
  location_lng DOUBLE PRECISION,
  status TEXT NOT NULL, -- 'successful' (başarılı), 'failed' (başarısız), 'force_majeure' (mücbir sebep)
  UNIQUE(event_id, user_id) -- Bir kullanıcı bir etkinliğe sadece 1 kez check-in yapabilir
);

-- RLS (Güvenlik) Ayarları
ALTER TABLE public.event_checkins ENABLE ROW LEVEL SECURITY;

-- Herkes check-in'leri okuyabilir (etkinlik geçmişi için)
CREATE POLICY "Users can view checkins"
ON public.event_checkins FOR SELECT
TO authenticated
USING (true);

-- Kullanıcılar kendi check-in verilerini ekleyebilir
CREATE POLICY "Users can insert own checkins"
ON public.event_checkins FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 3. GÜVEN SKORU GÜNCELLEMESİ (Profiles Tablosuna)
-- Eğer profiles tablosunda trust_score yoksa ekler (Varsayılan 100).
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS trust_score INTEGER DEFAULT 100;
