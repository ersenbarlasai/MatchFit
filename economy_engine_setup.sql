-- ==============================================================================
-- @EconomyEngine Agent Veritabanı Kurulumu (Supabase SQL Editor)
-- Bu SQL kodlarını kopyalayıp Supabase panelinizdeki "SQL Editor" kısmına
-- yapıştırarak çalıştırın.
-- ==============================================================================

-- 1. KULLANICI MF POINTS CÜZDANI VE LEDGER (mf_point_ledger)
CREATE TABLE IF NOT EXISTS public.mf_point_ledger (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL, -- Pozitif (kazanç) veya negatif (harcama)
  balance_after INTEGER NOT NULL, -- İşlem sonrası bakiye
  source TEXT NOT NULL, -- Örn: 'event_creation', 'daily_login', 'reward_redemption'
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.mf_point_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own ledger"
ON public.mf_point_ledger FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Kullanıcıların toplam MF Point bakiyesini hızlıca alabilmek için profile veya ayrı bir tabloya ekleyebiliriz.
-- Performans için `user_mf_balance` tablosu oluşturalım.
CREATE TABLE IF NOT EXISTS public.user_mf_balance (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance INTEGER NOT NULL DEFAULT 0,
  total_earned INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.user_mf_balance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all mf balances"
ON public.user_mf_balance FOR SELECT
TO authenticated
USING (true);

-- 2. MF POINTS EKLEME/HARCAMA FONKSİYONU (RPC)
CREATE OR REPLACE FUNCTION public.add_mf_points(p_user_id UUID, p_amount INTEGER, p_source TEXT, p_description TEXT DEFAULT '')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_balance INTEGER;
    v_new_balance INTEGER;
    v_total_earned INTEGER;
BEGIN
    -- Kullanıcının mevcut bakiyesini al
    SELECT balance, total_earned
    INTO v_current_balance, v_total_earned
    FROM public.user_mf_balance
    WHERE user_id = p_user_id;

    -- Eğer kayıt yoksa oluştur
    IF NOT FOUND THEN
        v_current_balance := 0;
        v_total_earned := 0;
        
        INSERT INTO public.user_mf_balance (user_id, balance, total_earned)
        VALUES (p_user_id, 0, 0);
    END IF;

    -- Yeni bakiye hesapla
    v_new_balance := v_current_balance + p_amount;
    
    -- Yetersiz bakiye kontrolü (Eğer harcama işlemiyse)
    IF v_new_balance < 0 THEN
        RAISE EXCEPTION 'Yetersiz MF Points bakiyesi.';
    END IF;

    -- Toplam kazanımı güncelle (sadece pozitif ise)
    IF p_amount > 0 THEN
        v_total_earned := v_total_earned + p_amount;
    END IF;

    -- Ledger'a kaydet
    INSERT INTO public.mf_point_ledger (user_id, amount, balance_after, source, description)
    VALUES (p_user_id, p_amount, v_new_balance, p_source, p_description);

    -- Bakiyeyi güncelle
    UPDATE public.user_mf_balance
    SET balance = v_new_balance,
        total_earned = v_total_earned,
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_user_id;
END;
$$;
