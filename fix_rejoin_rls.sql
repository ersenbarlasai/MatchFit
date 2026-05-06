-- ============================================================
-- MatchFit: Fix Re-Join RLS Policy
-- ============================================================
-- Etkinliğe tekrar başvurmak (rejected -> pending) isteyen
-- katılımcının kendi satırını güncelleyebilmesi için
-- UPDATE yetkisi verilmelidir. Aksi halde Supabase RLS bunu 
-- sessizce (hata vermeden) engeller ve durum güncellenmez.

-- Katılımcıların kendi satırlarını güncelleyebilmesini sağlayan kural:
CREATE POLICY "Users can update their own participant record"
ON public.event_participants
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- EĞER SADECE STATUS 'pending' YAPABİLSİN İSTİYORSAK DAHA GÜVENLİ BİR KURAL:
-- (Yukarıdakini daha güvenli hale getiriyoruz)
DROP POLICY IF EXISTS "Users can update their own participant record" ON public.event_participants;

CREATE POLICY "Users can update own status to pending"
ON public.event_participants
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id 
  AND status = 'pending'
);
