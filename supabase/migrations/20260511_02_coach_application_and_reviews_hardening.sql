-- Coach Application & Reviews Hardening Migration
-- Date: 2026-05-11
-- Description: RPCs for coach application, document submission, and coach reviews with automatic rating aggregation.

-- 1. Create coach_reviews table
CREATE TABLE IF NOT EXISTS public.coach_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES public.coach_sessions(id) ON DELETE CASCADE,
    coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    idempotency_key TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Schema drift protection: Ensure all columns exist
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES public.coach_sessions(id) ON DELETE CASCADE;
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS rating INTEGER;
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS comment TEXT;
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.coach_reviews ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Safe check for rating constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'coach_reviews_rating_check'
  ) THEN
    ALTER TABLE public.coach_reviews
    ADD CONSTRAINT coach_reviews_rating_check CHECK (rating BETWEEN 1 AND 5);
  END IF;
END $$;

-- Indices for performance and constraints
CREATE UNIQUE INDEX IF NOT EXISTS idx_coach_reviews_idempotency_key ON public.coach_reviews (idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_coach_reviews_session_student ON public.coach_reviews (session_id, student_id);
CREATE INDEX IF NOT EXISTS idx_coach_reviews_coach_id ON public.coach_reviews (coach_id);

-- 2. RLS for coach_reviews
ALTER TABLE public.coach_reviews ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Everyone can view coach reviews') THEN
        CREATE POLICY "Everyone can view coach reviews" ON public.coach_reviews FOR SELECT USING (true);
    END IF;
END $$;

-- (No direct insert/update/delete policies - only via RPC)

-- 3. RPC: Submit Coach Application (Hardened)
CREATE OR REPLACE FUNCTION submit_coach_application(
    p_full_name TEXT DEFAULT NULL,
    p_sub_branch TEXT DEFAULT NULL,
    p_experience_years INTEGER DEFAULT NULL,
    p_bio TEXT DEFAULT NULL,
    p_work_location TEXT DEFAULT NULL,
    p_intro_video_url TEXT DEFAULT NULL,
    p_price_min NUMERIC DEFAULT NULL,
    p_price_max NUMERIC DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_coach_id UUID;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Oturum açılmamış.'; END IF;

    INSERT INTO public.coaches (
        user_id,
        sub_branch,
        experience_years,
        bio,
        work_location,
        intro_video_url,
        price_min,
        price_max,
        verification_level,
        is_active,
        updated_at
    ) VALUES (
        v_user_id,
        p_sub_branch,
        p_experience_years,
        p_bio,
        p_work_location,
        p_intro_video_url,
        p_price_min,
        p_price_max,
        'pending', -- Force pending on new/update apps
        false,     -- Default to inactive until verified
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        sub_branch = COALESCE(p_sub_branch, public.coaches.sub_branch),
        experience_years = COALESCE(p_experience_years, public.coaches.experience_years),
        bio = COALESCE(p_bio, public.coaches.bio),
        work_location = COALESCE(p_work_location, public.coaches.work_location),
        intro_video_url = COALESCE(p_intro_video_url, public.coaches.intro_video_url),
        price_min = COALESCE(p_price_min, public.coaches.price_min),
        price_max = COALESCE(p_price_max, public.coaches.price_max),
        -- Do NOT allow users to update verification_level or is_active directly
        updated_at = now()
    RETURNING user_id INTO v_coach_id;

    -- Update profiles.is_coach to false until verified (if needed)
    UPDATE public.profiles SET is_coach = false WHERE id = v_user_id AND is_coach IS NULL;

    RETURN v_coach_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. RPC: Submit Coach Document (Hardened)
CREATE OR REPLACE FUNCTION submit_coach_document(
    p_doc_type TEXT,
    p_file_url TEXT,
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_doc_id UUID;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Oturum açılmamış.'; END IF;

    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_doc_id FROM public.coach_documents WHERE idempotency_key = p_idempotency_key;
        IF v_doc_id IS NOT NULL THEN RETURN v_doc_id; END IF;
    END IF;

    INSERT INTO public.coach_documents (
        coach_id,
        doc_type,
        file_url,
        status,
        idempotency_key,
        created_at
    ) VALUES (
        v_user_id,
        p_doc_type,
        p_file_url,
        'pending',
        p_idempotency_key,
        now()
    ) RETURNING id INTO v_doc_id;

    RETURN v_doc_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 5. RPC: Submit Coach Review
CREATE OR REPLACE FUNCTION submit_coach_review(
    p_session_id UUID,
    p_rating INTEGER,
    p_comment TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_session RECORD;
    v_review_id UUID;
    v_avg_rating NUMERIC;
    v_rating_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Oturum açılmamış.'; END IF;

    -- Fetch session and validate
    SELECT * INTO v_session FROM public.coach_sessions WHERE id = p_session_id;
    IF v_session IS NULL THEN RAISE EXCEPTION 'Seans bulunamadı.'; END IF;
    IF v_session.student_id != v_user_id THEN RAISE EXCEPTION 'Bu seans için değerlendirme yapamazsınız.'; END IF;
    IF v_session.status != 'completed' THEN RAISE EXCEPTION 'Sadece tamamlanmış seanslar için değerlendirme yapılabilir.'; END IF;

    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_review_id FROM public.coach_reviews WHERE idempotency_key = p_idempotency_key;
        IF v_review_id IS NOT NULL THEN RETURN v_review_id; END IF;
    END IF;

    -- Check if already reviewed for this session
    SELECT id INTO v_review_id FROM public.coach_reviews WHERE session_id = p_session_id AND student_id = v_user_id;
    IF v_review_id IS NOT NULL THEN RAISE EXCEPTION 'Bu seans için zaten bir değerlendirme yapılmış.'; END IF;

    -- Insert Review
    INSERT INTO public.coach_reviews (
        session_id,
        coach_id,
        student_id,
        rating,
        comment,
        idempotency_key
    ) VALUES (
        p_session_id,
        v_session.coach_id,
        v_user_id,
        p_rating,
        p_comment,
        p_idempotency_key
    ) RETURNING id INTO v_review_id;

    -- Update Coach Aggregates
    SELECT 
        AVG(rating), 
        COUNT(*) 
    INTO v_avg_rating, v_rating_count 
    FROM public.coach_reviews 
    WHERE coach_id = v_session.coach_id;

    UPDATE public.coaches 
    SET rating_avg = ROUND(v_avg_rating, 2),
        rating_count = v_rating_count,
        updated_at = now()
    WHERE user_id = v_session.coach_id;

    -- Optional: Log for Analytics (Safe attempt)
    BEGIN
        PERFORM public.log_analytics_event(
            v_user_id,
            'coach_review_submitted',
            jsonb_build_object(
                'coach_id', v_session.coach_id,
                'rating', p_rating,
                'session_id', p_session_id
            )
        );
    EXCEPTION WHEN OTHERS THEN
        -- Ignore analytics errors to not block the review
    END;

    RETURN v_review_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6. RPC: Get Coach Reviews
CREATE OR REPLACE FUNCTION get_coach_reviews(p_coach_id UUID)
RETURNS TABLE (
    id UUID,
    rating INTEGER,
    comment TEXT,
    created_at TIMESTAMPTZ,
    student_name TEXT,
    student_avatar TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id, r.rating, r.comment, r.created_at,
        p.full_name, p.avatar_url
    FROM public.coach_reviews r
    JOIN public.profiles p ON p.id = r.student_id
    WHERE r.coach_id = p_coach_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
