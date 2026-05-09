-- Sponsor Onboarding MVP
-- Date: 2026-05-12
-- Description: Partner application table and RPC-driven workflow for sponsor onboarding.

-- ── 1. Table ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.partner_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    applicant_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    business_name TEXT NOT NULL,
    category TEXT,
    city TEXT,
    contact_name TEXT,
    contact_email TEXT,
    tax_number TEXT,
    desired_tier TEXT DEFAULT 'basic',
    desired_billing_model TEXT,
    proposed_reward_types TEXT[] DEFAULT '{}',
    notes TEXT,
    status TEXT DEFAULT 'pending',
    admin_note TEXT,
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    idempotency_key TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pa_applicant ON public.partner_applications (applicant_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pa_status ON public.partner_applications (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pa_partner_id ON public.partner_applications (partner_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pa_idempotency ON public.partner_applications (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- RLS
ALTER TABLE public.partner_applications ENABLE ROW LEVEL SECURITY;

-- Users can read their own applications
CREATE POLICY "users_read_own_applications" ON public.partner_applications
    FOR SELECT USING (applicant_user_id = auth.uid());

-- No client writes; all via RPC
CREATE POLICY "no_client_write_applications" ON public.partner_applications
    AS RESTRICTIVE FOR INSERT WITH CHECK (false);
CREATE POLICY "no_client_update_applications" ON public.partner_applications
    AS RESTRICTIVE FOR UPDATE USING (false);
CREATE POLICY "no_client_delete_applications" ON public.partner_applications
    AS RESTRICTIVE FOR DELETE USING (false);


-- ── 2. Submit Application RPC ─────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.submit_partner_application(
    p_business_name TEXT,
    p_category TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL,
    p_contact_name TEXT DEFAULT NULL,
    p_contact_email TEXT DEFAULT NULL,
    p_tax_number TEXT DEFAULT NULL,
    p_desired_tier TEXT DEFAULT 'basic',
    p_desired_billing_model TEXT DEFAULT NULL,
    p_proposed_reward_types TEXT[] DEFAULT '{}',
    p_notes TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_app_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_app_id
        FROM public.partner_applications
        WHERE idempotency_key = p_idempotency_key;
        
        IF v_app_id IS NOT NULL THEN
            RETURN v_app_id;
        END IF;
    END IF;

    INSERT INTO public.partner_applications (
        applicant_user_id, business_name, category, city, contact_name,
        contact_email, tax_number, desired_tier, desired_billing_model,
        proposed_reward_types, notes, status, metadata, idempotency_key
    ) VALUES (
        auth.uid(), p_business_name, p_category, p_city, p_contact_name,
        p_contact_email, p_tax_number, p_desired_tier, p_desired_billing_model,
        p_proposed_reward_types, p_notes, 'pending', p_metadata, p_idempotency_key
    )
    RETURNING id INTO v_app_id;

    RETURN v_app_id;
END;
$$;


-- ── 3. Get My Applications RPC ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_my_partner_applications()
RETURNS TABLE (
    id UUID,
    business_name TEXT,
    category TEXT,
    city TEXT,
    status TEXT,
    admin_note TEXT,
    partner_id UUID,
    created_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT 
        pa.id, pa.business_name, pa.category, pa.city, pa.status,
        pa.admin_note, pa.partner_id, pa.created_at, pa.reviewed_at
    FROM public.partner_applications pa
    WHERE pa.applicant_user_id = auth.uid()
    ORDER BY pa.created_at DESC;
END;
$$;


-- ── 4. Admin List Applications RPC ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_partner_application_admin_list(
    p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    applicant_user_id UUID,
    business_name TEXT,
    category TEXT,
    city TEXT,
    contact_name TEXT,
    contact_email TEXT,
    desired_tier TEXT,
    status TEXT,
    admin_note TEXT,
    partner_id UUID,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    RETURN QUERY
    SELECT 
        pa.id, pa.applicant_user_id, pa.business_name, pa.category, pa.city,
        pa.contact_name, pa.contact_email, pa.desired_tier, pa.status,
        pa.admin_note, pa.partner_id, pa.created_at
    FROM public.partner_applications pa
    WHERE p_status IS NULL OR pa.status = p_status
    ORDER BY pa.created_at DESC;
END;
$$;


-- ── 5. Admin Handle Application RPC ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_partner_application_admin(
    p_application_id UUID,
    p_action TEXT,
    p_admin_note TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_app RECORD;
    v_partner_id UUID;
    v_slug TEXT;
    v_base_slug TEXT;
    v_slug_exists BOOLEAN;
    v_allowed_actions TEXT[] := ARRAY['approve', 'reject', 'request_revision'];
BEGIN
    IF NOT public.is_user_admin() THEN
        RAISE EXCEPTION 'Bu işlem için admin yetkisi gerekiyor.';
    END IF;

    IF NOT (p_action = ANY(v_allowed_actions)) THEN
        RAISE EXCEPTION 'Invalid action: %. Allowed: approve, reject, request_revision', p_action;
    END IF;

    SELECT * INTO v_app FROM public.partner_applications WHERE id = p_application_id;
    IF v_app IS NULL THEN
        RAISE EXCEPTION 'Application not found: %', p_application_id;
    END IF;

    IF p_action = 'approve' THEN
        -- Generate slug from business_name
        v_base_slug := LOWER(REGEXP_REPLACE(TRIM(v_app.business_name), '\s+', '-', 'g'));
        v_base_slug := REGEXP_REPLACE(v_base_slug, '[^a-z0-9\-]', '', 'g');
        v_slug := v_base_slug;

        -- Check slug uniqueness, append suffix if needed
        SELECT EXISTS (SELECT 1 FROM public.partners WHERE slug = v_slug) INTO v_slug_exists;
        IF v_slug_exists THEN
            v_slug := v_base_slug || '-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6);
        END IF;

        -- Create partner record
        INSERT INTO public.partners (
            name, slug, category, tier, status, city,
            contact_name, contact_email, billing_model,
            metadata
        ) VALUES (
            v_app.business_name, v_slug, v_app.category,
            COALESCE(v_app.desired_tier, 'basic'), 'active',
            v_app.city, v_app.contact_name, v_app.contact_email,
            v_app.desired_billing_model, v_app.metadata
        )
        RETURNING id INTO v_partner_id;

        -- Update application
        UPDATE public.partner_applications SET
            status = 'approved',
            partner_id = v_partner_id,
            admin_note = p_admin_note,
            reviewed_by = auth.uid(),
            reviewed_at = now(),
            updated_at = now()
        WHERE id = p_application_id;

        RETURN jsonb_build_object(
            'status', 'approved',
            'partner_id', v_partner_id,
            'slug', v_slug
        );

    ELSE
        -- reject or request_revision
        UPDATE public.partner_applications SET
            status = CASE p_action
                WHEN 'reject' THEN 'rejected'
                ELSE 'revision_requested'
            END,
            admin_note = p_admin_note,
            reviewed_by = auth.uid(),
            reviewed_at = now(),
            updated_at = now()
        WHERE id = p_application_id;

        RETURN jsonb_build_object('status', p_action, 'application_id', p_application_id);
    END IF;
END;
$$;
