-- ==============================================================================
-- MATCHFIT COACH & VERIFICATION SYSTEM SCHEMA
-- ==============================================================================

-- 1. ENUMS FOR COACH SYSTEM
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'coach_verification_level') THEN
        CREATE TYPE coach_verification_level AS ENUM ('none', 'pending', 'basic', 'certified', 'elite');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_status') THEN
        CREATE TYPE document_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_type') THEN
        CREATE TYPE document_type AS ENUM ('id_card_front', 'id_card_back', 'selfie', 'certificate', 'diploma');
    END IF;
END $$;

-- 2. COACHES TABLE (Extends profiles)
CREATE TABLE IF NOT EXISTS public.coaches (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    sport_id UUID REFERENCES public.sports(id),
    sub_branch TEXT,
    experience_years INTEGER DEFAULT 0,
    bio TEXT,
    work_location TEXT, -- Facility or general area
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    intro_video_url TEXT,
    
    -- Verification & Trust
    verification_level coach_verification_level DEFAULT 'none',
    is_active BOOLEAN DEFAULT false,
    
    -- Performance Metrics
    reliability_score NUMERIC DEFAULT 100.0, -- 0-100
    rating_avg NUMERIC DEFAULT 0.0,          -- 1-5
    total_reviews INTEGER DEFAULT 0,
    total_sessions INTEGER DEFAULT 0,
    session_success_rate NUMERIC DEFAULT 100.0,
    
    -- Monetization Hooks
    commission_rate NUMERIC DEFAULT 15.0,    -- Platform commission %
    is_featured BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.coaches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active coaches" ON public.coaches;
CREATE POLICY "Anyone can view active coaches" 
    ON public.coaches FOR SELECT 
    USING (is_active = true OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Coaches can update their own profile" ON public.coaches;
CREATE POLICY "Coaches can update their own profile" 
    ON public.coaches FOR UPDATE 
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Coaches can insert their own profile" ON public.coaches;
CREATE POLICY "Coaches can insert their own profile" 
    ON public.coaches FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- 3. COACH DOCUMENTS (For Verification Agent)
CREATE TABLE IF NOT EXISTS public.coach_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coach_id UUID REFERENCES public.coaches(user_id) ON DELETE CASCADE,
    doc_type document_type NOT NULL,
    file_url TEXT NOT NULL,
    document_hash TEXT, -- To prevent duplicate document reuse (Guardian Agent check)
    status document_status DEFAULT 'pending',
    rejection_reason TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by UUID REFERENCES auth.users(id) -- Can be admin or Agent ID
);

ALTER TABLE public.coach_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Coaches can view their own documents" ON public.coach_documents;
CREATE POLICY "Coaches can view their own documents" 
    ON public.coach_documents FOR SELECT 
    USING (auth.uid() = coach_id);

DROP POLICY IF EXISTS "Coaches can upload documents" ON public.coach_documents;
CREATE POLICY "Coaches can upload documents" 
    ON public.coach_documents FOR INSERT 
    WITH CHECK (auth.uid() = coach_id);

-- 4. VERIFICATION LOGS (Memory for Agents)
CREATE TABLE IF NOT EXISTS public.coach_verification_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coach_id UUID REFERENCES public.coaches(user_id) ON DELETE CASCADE,
    agent_name TEXT NOT NULL, -- '@CoachVerificationAgent', '@GuardianAgent'
    action_type TEXT NOT NULL, -- 'document_approved', 'fraud_detected', 'level_upgraded'
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.coach_verification_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Coaches can view their own logs" ON public.coach_verification_logs;
CREATE POLICY "Coaches can view their own logs" ON public.coach_verification_logs FOR SELECT USING (auth.uid() = coach_id);

-- 5. COACH REVIEWS & ATTENDANCE
CREATE TABLE IF NOT EXISTS public.coach_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coach_id UUID REFERENCES public.coaches(user_id) ON DELETE CASCADE,
    student_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(student_id, event_id)
);

ALTER TABLE public.coach_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read reviews" ON public.coach_reviews;
CREATE POLICY "Anyone can read reviews" ON public.coach_reviews FOR SELECT USING (true);

DROP POLICY IF EXISTS "Students can leave reviews" ON public.coach_reviews;
CREATE POLICY "Students can leave reviews" ON public.coach_reviews FOR INSERT WITH CHECK (auth.uid() = student_id);

-- 6. EXTENDING EVENTS FOR COACHING
-- (Assuming events table exists, we add columns instead of a new table)
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS is_coach_session BOOLEAN DEFAULT false;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS price NUMERIC DEFAULT 0;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS required_checkin BOOLEAN DEFAULT false;

-- 7. TRIGGERS & FUNCTIONS
-- Auto-update coach rating when a new review is added
CREATE OR REPLACE FUNCTION public.update_coach_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.coaches
    SET rating_avg = (
            SELECT ROUND(AVG(rating)::numeric, 2)
            FROM public.coach_reviews
            WHERE coach_id = NEW.coach_id
        ),
        total_reviews = total_reviews + 1
    WHERE user_id = NEW.coach_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_coach_rating ON public.coach_reviews;
CREATE TRIGGER trigger_update_coach_rating
AFTER INSERT OR UPDATE ON public.coach_reviews
FOR EACH ROW EXECUTE FUNCTION public.update_coach_rating();

-- ==============================================================================
-- 8. CREATE STORAGE BUCKET FOR DOCUMENTS (If not exists)
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documents', 'documents', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing policies if any to avoid errors on rerun
DROP POLICY IF EXISTS "Anyone can view documents" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload documents" ON storage.objects;

-- Create Storage Policies
CREATE POLICY "Anyone can view documents" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'documents');

CREATE POLICY "Authenticated users can upload documents" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'documents' AND auth.role() = 'authenticated');

-- ==============================================================================
-- 9. DYNAMIC COACH LANDING CONTENT (Manageable from Dashboard)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.coach_landing_content (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    benefits JSONB NOT NULL,
    requirements JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

INSERT INTO public.coach_landing_content (id, title, description, benefits, requirements)
VALUES (
    1, 
    'Profesyonel Koç Ağına Katılın', 
    'Yüzlerce sporcuya ulaşın, deneyiminizi güvenli bir şekilde kazanca dönüştürün ve kariyerinizi bir üst seviyeye taşıyın.', 
    '["Kendi çalışma saatlerini ve fiyatını belirle", "Platform güvencesiyle garanti ödeme al", "Liderlik tablosunda premium görünürlük kazan", "İstatistiklerini ve öğrenci gelişimini takip et"]'::jsonb,
    '["Uzmanlık belgesi veya Antrenörlük sertifikası", "30-60 saniyelik tanıtım videosu", "Resmi kimlik ve yüz doğrulaması"]'::jsonb
)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.coach_landing_content ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view coach landing content" ON public.coach_landing_content;
CREATE POLICY "Anyone can view coach landing content" ON public.coach_landing_content FOR SELECT USING (true);

-- ==============================================================================
-- 10. VERIFICATION LOGS RLS
-- ==============================================================================
ALTER TABLE public.coach_verification_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Coaches can insert their own logs" ON public.coach_verification_logs;
CREATE POLICY "Coaches can insert their own logs" 
    ON public.coach_verification_logs FOR INSERT 
    WITH CHECK (auth.uid() = coach_id);

DROP POLICY IF EXISTS "Coaches can view their own logs" ON public.coach_verification_logs;
CREATE POLICY "Coaches can view their own logs" 
    ON public.coach_verification_logs FOR SELECT 
    USING (auth.uid() = coach_id);


