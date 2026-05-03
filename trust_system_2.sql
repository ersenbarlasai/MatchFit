-- ==============================================================================
-- MATCHFIT TRUST SYSTEM 2.0 — Veritabanı Migrasyonu
-- Supabase SQL Editor'a yapıştırarak çalıştırın.
-- ==============================================================================

-- 1. PROFILES tablosuna yeni alt skor sütunları ekle
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS reliability_score  INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS social_score       INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS activity_score     INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS trust_score        INTEGER DEFAULT 0,  -- Hesaplanmış toplam (0–100)
  ADD COLUMN IF NOT EXISTS no_show_count      INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS streak_count       INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_active_at     TIMESTAMP WITH TIME ZONE DEFAULT now();

-- 2. TRUST EVENTS TABLOSU — Her puan hareketini logla
CREATE TABLE IF NOT EXISTS public.trust_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type    TEXT NOT NULL, -- 'checkin', 'early_checkin', 'no_show', 'late_cancel', 'last_min_cancel',
                               -- 'pos_review', 'great_review', 'neg_review', 'complaint',
                               -- 'event_create', 'event_join', 'streak_bonus', 'decay'
  category      TEXT NOT NULL, -- 'reliability', 'social', 'activity'
  delta         INTEGER NOT NULL, -- Pozitif veya negatif puan değişimi
  note          TEXT,
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE public.trust_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own trust events"
  ON public.trust_events FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- 3. USER BADGES TABLOSU — Kullanıcının kazandığı rozetler
CREATE TABLE IF NOT EXISTS public.user_badges (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_key   TEXT NOT NULL,  -- 'iron_reliability', 'solid_partner', 'crowd_favorite' vs.
  earned_at   TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE (user_id, badge_key)
);

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own badges"
  ON public.user_badges FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view others badges"
  ON public.user_badges FOR SELECT TO authenticated
  USING (true);

-- 4. TRUST SCORE HESAPLAMA FONKSİYONU (DB tarafında da tutarlılık için)
-- Trust Score = (0.5 × Reliability) + (0.3 × Social) + (0.2 × Activity)
-- Her alt skor 0–100 aralığında normalize edilmeli
CREATE OR REPLACE FUNCTION public.recalculate_trust_score(p_user_id UUID)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  r_score INTEGER;
  s_score INTEGER;
  a_score INTEGER;
  total   INTEGER;
BEGIN
  SELECT
    GREATEST(0, LEAST(100, COALESCE(reliability_score, 0))),
    GREATEST(0, LEAST(100, COALESCE(social_score, 0))),
    GREATEST(0, LEAST(100, COALESCE(activity_score, 0)))
  INTO r_score, s_score, a_score
  FROM public.profiles WHERE id = p_user_id;

  total := ROUND((0.5 * r_score) + (0.3 * s_score) + (0.2 * a_score));

  UPDATE public.profiles
    SET trust_score = GREATEST(0, LEAST(100, total))
    WHERE id = p_user_id;
END;
$$;
