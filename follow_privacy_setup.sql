-- ==============================================================================
-- MatchFit: Privacy Settings for Follow Requests
-- ==============================================================================
-- Add an option to user profiles to disable incoming follow requests.

-- 1. Add accepts_follow_requests column to profiles if it doesn't exist.
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='accepts_follow_requests') THEN
    ALTER TABLE public.profiles ADD COLUMN accepts_follow_requests BOOLEAN DEFAULT TRUE;
  END IF;
END $$;

-- 2. Modify follow trigger or function, or simply handle it via app logic.
-- Actually, the app logic in SocialRepository can check this before inserting, 
-- or we can enforce it via a database trigger to be completely bulletproof.

CREATE OR REPLACE FUNCTION check_accepts_follow_requests()
RETURNS TRIGGER AS $$
DECLARE
    v_accepts BOOLEAN;
BEGIN
    -- Sadece yeni bir takip isteği (pending veya following) atıldığında kontrol et
    IF NEW.status IN ('pending', 'following') THEN
        SELECT accepts_follow_requests INTO v_accepts FROM public.profiles WHERE id = NEW.receiver_id;
        
        -- Eğer kullanıcı takip isteklerini kapattıysa hata fırlat
        IF v_accepts = FALSE THEN
            RAISE EXCEPTION 'Bu kullanıcı yeni takip isteklerini kabul etmiyor.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_check_follow_requests ON public.user_relationships;

CREATE TRIGGER tr_check_follow_requests
BEFORE INSERT OR UPDATE ON public.user_relationships
FOR EACH ROW
EXECUTE FUNCTION check_accepts_follow_requests();
