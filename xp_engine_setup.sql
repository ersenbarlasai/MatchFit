-- ==============================================================================
-- @XPEngine Agent Veritabanı Kurulumu (Supabase SQL Editor)
-- ==============================================================================

-- 1. KULLANICI XP VE SEVİYE TABLOSU (User XP)
CREATE TABLE IF NOT EXISTS public.user_xp (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  xp_amount INTEGER NOT NULL DEFAULT 0,
  current_level INTEGER NOT NULL DEFAULT 1,
  current_streak INTEGER NOT NULL DEFAULT 0,
  last_activity_date DATE,
  weekly_xp INTEGER DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.user_xp ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all xp profiles" ON public.user_xp;
CREATE POLICY "Users can view all xp profiles"
ON public.user_xp FOR SELECT
TO authenticated
USING (true);

-- 2. XP GEÇMİŞİ TABLOSU (XP Events)
-- details kolonu eklendi (bonus ve kalite detaylarını tutmak için)
CREATE TABLE IF NOT EXISTS public.xp_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  xp_earned INTEGER NOT NULL,
  source TEXT NOT NULL, 
  details JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.xp_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own xp events" ON public.xp_events;
CREATE POLICY "Users can view their own xp events"
ON public.xp_events FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 3. EARNED XP MODELİ - GELİŞMİŞ XP EKLEME FONKSİYONU
CREATE OR REPLACE FUNCTION public.add_user_xp(
    p_user_id UUID, 
    p_amount INTEGER, 
    p_source TEXT,
    p_quality_tier TEXT DEFAULT 'B',        -- 'S', 'A', 'B', 'C'
    p_event_quality TEXT DEFAULT 'normal',  -- 'perfect', 'good', 'normal', 'bad'
    p_is_first_event BOOLEAN DEFAULT false,
    p_new_person_count INTEGER DEFAULT 0,
    p_is_new_branch BOOLEAN DEFAULT false,
    p_friend_invite_count INTEGER DEFAULT 0,
    p_is_weekend BOOLEAN DEFAULT false,
    p_is_no_show BOOLEAN DEFAULT false,
    p_abuse_status TEXT DEFAULT 'clean'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_xp INTEGER;
    v_new_xp INTEGER;
    v_new_level INTEGER;
    v_last_activity DATE;
    v_current_streak INTEGER;
    v_today DATE := CURRENT_DATE;
    
    -- Calculation Variables
    v_final_amount NUMERIC := p_amount;
    v_daily_earned INTEGER := 0;
    v_events_today INTEGER := 0;
    
    v_streak_multiplier NUMERIC := 1.0;
    v_quality_multiplier NUMERIC := 1.0;
    v_tier_multiplier NUMERIC := 1.0;
    v_diminishing_multiplier NUMERIC := 1.0;
    v_soft_cap_multiplier NUMERIC := 1.0;
    
    v_bonus_xp INTEGER := 0;
    v_details JSONB;
BEGIN
    -- Kullanıcının mevcut XP durumunu al
    SELECT xp_amount, current_streak, last_activity_date
    INTO v_current_xp, v_current_streak, v_last_activity
    FROM public.user_xp
    WHERE user_id = p_user_id;

    -- Kayıt yoksa varsayılanları belirle
    IF NOT FOUND THEN
        v_current_xp := 0;
        v_current_streak := 0;
        v_last_activity := v_today - INTERVAL '2 days'; -- Streak sıfırdan başlasın
    END IF;

    -- 1. NO-SHOW VEYA ABUSE DURUMU (XP FREEZE & STREAK RESET)
    IF p_is_no_show THEN
        v_current_streak := 0; -- Ceza: Streak reset!
        v_final_amount := 0;
        v_bonus_xp := 0;
    ELSIF p_abuse_status IN ('suspicious', 'confirmed_abuse') THEN
        v_final_amount := 0; -- Ceza: XP Freeze!
        v_bonus_xp := 0;
    ELSE
        -- 2. STREAK HESAPLAMA VE ÇARPANI (Yumuşatılmış)
        IF v_last_activity = v_today - INTERVAL '1 day' THEN
            v_current_streak := v_current_streak + 1;
        ELSIF v_last_activity < v_today - INTERVAL '1 day' THEN
            v_current_streak := 1;
        END IF;

        IF v_current_streak >= 30 THEN v_streak_multiplier := 1.25;
        ELSIF v_current_streak >= 10 THEN v_streak_multiplier := 1.12;
        ELSIF v_current_streak >= 5 THEN v_streak_multiplier := 1.07;
        ELSIF v_current_streak >= 2 THEN v_streak_multiplier := 1.03;
        END IF;

        -- 3. QUALITY & TIER MULTIPLIERS
        IF p_event_quality = 'perfect' THEN v_quality_multiplier := 1.4;
        ELSIF p_event_quality = 'good' THEN v_quality_multiplier := 1.2;
        ELSIF p_event_quality = 'bad' THEN v_quality_multiplier := 0.7;
        END IF;

        IF p_quality_tier = 'S' THEN v_tier_multiplier := 1.4;
        ELSIF p_quality_tier = 'A' THEN v_tier_multiplier := 1.2;
        ELSIF p_quality_tier = 'C' THEN v_tier_multiplier := 0.7;
        END IF;

        -- 4. BONUS XP HESAPLAMALARI
        IF p_is_first_event THEN v_bonus_xp := v_bonus_xp + 20; END IF;
        IF p_is_new_branch THEN v_bonus_xp := v_bonus_xp + 10; END IF;
        IF p_is_weekend THEN v_bonus_xp := v_bonus_xp + 5; END IF;
        v_bonus_xp := v_bonus_xp + (p_new_person_count * 8);
        v_bonus_xp := v_bonus_xp + (p_friend_invite_count * 15);

        -- Sadece Event katılımlarında (app_open hariç) Diminishing ve Soft Cap uygulanır
        IF p_source IN ('event_completed', 'event_creation') THEN
            -- 5. DIMINISHING RETURNS (Günlük Event Sayısına Göre)
            SELECT COUNT(*) INTO v_events_today 
            FROM public.xp_events 
            WHERE user_id = p_user_id 
              AND created_at >= CURRENT_DATE 
              AND source IN ('event_completed', 'event_creation');

            IF v_events_today = 0 THEN v_diminishing_multiplier := 1.0;
            ELSIF v_events_today = 1 THEN v_diminishing_multiplier := 0.90;
            ELSIF v_events_today = 2 THEN v_diminishing_multiplier := 0.75;
            ELSE v_diminishing_multiplier := 0.60;
            END IF;
            
            -- 6. DAILY SOFT CAP
            SELECT COALESCE(SUM(xp_earned), 0) INTO v_daily_earned
            FROM public.xp_events
            WHERE user_id = p_user_id AND created_at >= CURRENT_DATE;

            IF v_daily_earned >= 120 THEN
                v_soft_cap_multiplier := 0.5;
            END IF;
        END IF;

        -- 7. NİHAİ HESAPLAMA
        v_final_amount := ROUND((v_final_amount * v_quality_multiplier * v_tier_multiplier * v_streak_multiplier * v_diminishing_multiplier * v_soft_cap_multiplier) + (v_bonus_xp * v_soft_cap_multiplier));
    END IF;

    -- Detayları JSON olarak kaydet
    v_details := jsonb_build_object(
        'base_amount', p_amount,
        'bonus_xp', v_bonus_xp,
        'streak', v_current_streak,
        'streak_multiplier', v_streak_multiplier,
        'quality_multiplier', v_quality_multiplier,
        'tier_multiplier', v_tier_multiplier,
        'diminishing_multiplier', v_diminishing_multiplier,
        'soft_cap_multiplier', v_soft_cap_multiplier,
        'is_no_show', p_is_no_show,
        'abuse_status', p_abuse_status
    );

    -- XP olayını kaydet (0 bile olsa loglarız, ceza analizleri için)
    INSERT INTO public.xp_events (user_id, xp_earned, source, details)
    VALUES (p_user_id, v_final_amount::INTEGER, p_source, v_details);

    -- User XP tablosunu güncelle
    v_new_xp := v_current_xp + v_final_amount::INTEGER;
    v_new_level := (v_new_xp / 1000) + 1;

    -- Record exist check
    IF NOT EXISTS (SELECT 1 FROM public.user_xp WHERE user_id = p_user_id) THEN
        INSERT INTO public.user_xp (user_id, xp_amount, current_level, current_streak, last_activity_date, weekly_xp)
        VALUES (p_user_id, v_new_xp, v_new_level, v_current_streak, v_today, v_final_amount::INTEGER);
    ELSE
        UPDATE public.user_xp
        SET xp_amount = v_new_xp,
            current_level = v_new_level,
            current_streak = v_current_streak,
            last_activity_date = v_today,
            weekly_xp = COALESCE(weekly_xp, 0) + v_final_amount::INTEGER,
            updated_at = timezone('utc'::text, now())
        WHERE user_id = p_user_id;
    END IF;
END;
$$;
