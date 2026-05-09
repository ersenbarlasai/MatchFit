-- Partner Catalog Foundation Migration
-- Date: 2026-05-12
-- Description: Adds tables and RPCs for the PartnerCatalog module (Phase 1).

-- 1. Partners Table
CREATE TABLE IF NOT EXISTS public.partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    logo_url TEXT,
    category TEXT,
    tier TEXT DEFAULT 'basic',
    status TEXT DEFAULT 'pending',
    city TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    contact_email TEXT,
    contact_name TEXT,
    tax_number TEXT,
    billing_model TEXT,
    cpm_rate NUMERIC,
    cpa_rate NUMERIC,
    commission_percent NUMERIC,
    metadata JSONB DEFAULT '{}'::jsonb,
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT 'Bilinmeyen Partner';
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS slug TEXT UNIQUE;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'basic';
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS latitude NUMERIC;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS longitude NUMERIC;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS contact_email TEXT;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS contact_name TEXT;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS tax_number TEXT;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS billing_model TEXT;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS cpm_rate NUMERIC;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS cpa_rate NUMERIC;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS commission_percent NUMERIC;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES auth.users(id);
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.partners ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 2. Reward Catalog Table
CREATE TABLE IF NOT EXISTS public.reward_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID REFERENCES public.partners(id) ON DELETE CASCADE,
    sponsor_tier TEXT DEFAULT 'interactive',
    name TEXT NOT NULL,
    short_description TEXT,
    description TEXT,
    category TEXT,
    sport_tags TEXT[] DEFAULT '{}',
    eligibility_tier TEXT DEFAULT 'standard',
    trust_minimum INTEGER DEFAULT 0,
    cost_points INTEGER,
    is_free BOOLEAN DEFAULT false,
    discount_percent NUMERIC,
    transaction_url TEXT,
    image_url TEXT,
    valid_from TIMESTAMPTZ DEFAULT now(),
    valid_until TIMESTAMPTZ,
    city TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    radius_km NUMERIC DEFAULT 30,
    boost_active BOOLEAN DEFAULT false,
    boost_multiplier NUMERIC DEFAULT 1.0,
    show_remaining_stock BOOLEAN DEFAULT false,
    show_expiry_countdown BOOLEAN DEFAULT false,
    city_exclusive_label TEXT,
    limited_badge BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'active',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES public.partners(id) ON DELETE CASCADE;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS sponsor_tier TEXT DEFAULT 'interactive';
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT 'İsimsiz Ödül';
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS short_description TEXT;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS sport_tags TEXT[] DEFAULT '{}';
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS eligibility_tier TEXT DEFAULT 'standard';
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS trust_minimum INTEGER DEFAULT 0;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS cost_points INTEGER;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS is_free BOOLEAN DEFAULT false;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS discount_percent NUMERIC;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS transaction_url TEXT;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS valid_from TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS latitude NUMERIC;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS longitude NUMERIC;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS radius_km NUMERIC DEFAULT 30;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS boost_active BOOLEAN DEFAULT false;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS boost_multiplier NUMERIC DEFAULT 1.0;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS show_remaining_stock BOOLEAN DEFAULT false;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS show_expiry_countdown BOOLEAN DEFAULT false;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS city_exclusive_label TEXT;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS limited_badge BOOLEAN DEFAULT false;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.reward_catalog ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 3. Reward Inventory Table
CREATE TABLE IF NOT EXISTS public.reward_inventory (
    reward_id UUID PRIMARY KEY REFERENCES public.reward_catalog(id) ON DELETE CASCADE,
    stock_total INTEGER,
    stock_remaining INTEGER,
    is_unlimited BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.reward_inventory ADD COLUMN IF NOT EXISTS stock_total INTEGER;
ALTER TABLE public.reward_inventory ADD COLUMN IF NOT EXISTS stock_remaining INTEGER;
ALTER TABLE public.reward_inventory ADD COLUMN IF NOT EXISTS is_unlimited BOOLEAN DEFAULT false;
ALTER TABLE public.reward_inventory ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- 4. Reward Inventory Reservations Table
CREATE TABLE IF NOT EXISTS public.reward_inventory_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reward_id UUID REFERENCES public.reward_catalog(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    idempotency_key TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.reward_inventory_reservations ADD COLUMN IF NOT EXISTS reward_id UUID REFERENCES public.reward_catalog(id) ON DELETE CASCADE;
ALTER TABLE public.reward_inventory_reservations ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE public.reward_inventory_reservations ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE public.reward_inventory_reservations ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.reward_inventory_reservations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- 5. Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_partners_slug ON public.partners (slug);
CREATE UNIQUE INDEX IF NOT EXISTS idx_reward_inventory_res_idem_key ON public.reward_inventory_reservations (idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reward_catalog_status_dates ON public.reward_catalog (status, valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_reward_catalog_partner_id ON public.reward_catalog (partner_id);
CREATE INDEX IF NOT EXISTS idx_reward_catalog_city ON public.reward_catalog (city);
CREATE INDEX IF NOT EXISTS idx_reward_catalog_sport_tags ON public.reward_catalog USING GIN (sport_tags);

-- 6. RLS Policies
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_inventory_reservations ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    -- Partners
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view active partners') THEN
        CREATE POLICY "Anyone can view active partners" ON public.partners FOR SELECT USING (status = 'active');
    END IF;

    -- Reward Catalog
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view active rewards') THEN
        CREATE POLICY "Anyone can view active rewards" ON public.reward_catalog FOR SELECT USING (status = 'active');
    END IF;

    -- Reward Inventory
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view reward inventory') THEN
        CREATE POLICY "Anyone can view reward inventory" ON public.reward_inventory FOR SELECT USING (true);
    END IF;
    
    -- Reward Inventory Reservations (Users can see their own, but not write directly)
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own reservations') THEN
        CREATE POLICY "Users can view their own reservations" ON public.reward_inventory_reservations FOR SELECT USING (auth.uid() = user_id);
    END IF;
END $$;

-- 7. RPCs

-- RPC: Get Active Rewards
DROP FUNCTION IF EXISTS public.get_active_rewards(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.get_active_rewards(
    p_city TEXT DEFAULT NULL,
    p_sport_tag TEXT DEFAULT NULL
) RETURNS TABLE (
    id UUID,
    partner_id UUID,
    partner_name TEXT,
    partner_logo TEXT,
    sponsor_tier TEXT,
    name TEXT,
    short_description TEXT,
    category TEXT,
    cost_points INTEGER,
    is_free BOOLEAN,
    image_url TEXT,
    city TEXT,
    limited_badge BOOLEAN,
    stock_total INTEGER,
    stock_remaining INTEGER,
    is_unlimited BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.partner_id,
        p.name AS partner_name,
        p.logo_url AS partner_logo,
        r.sponsor_tier,
        r.name,
        r.short_description,
        r.category,
        r.cost_points,
        r.is_free,
        r.image_url,
        r.city,
        r.limited_badge,
        i.stock_total,
        i.stock_remaining,
        i.is_unlimited
    FROM public.reward_catalog r
    JOIN public.partners p ON r.partner_id = p.id
    JOIN public.reward_inventory i ON r.id = i.reward_id
    WHERE r.status = 'active'
      AND p.status = 'active'
      AND r.valid_from <= now()
      AND (r.valid_until IS NULL OR r.valid_until >= now())
      AND (i.is_unlimited = TRUE OR i.stock_remaining > 0)
      AND (p_city IS NULL OR r.city = p_city OR r.city IS NULL)
      AND (p_sport_tag IS NULL OR p_sport_tag = ANY(r.sport_tags));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Get Reward Catalog Item
DROP FUNCTION IF EXISTS public.get_reward_catalog_item(UUID);
CREATE OR REPLACE FUNCTION public.get_reward_catalog_item(p_reward_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'reward', to_jsonb(r),
        'partner', to_jsonb(p),
        'inventory', to_jsonb(i)
    ) INTO v_result
    FROM public.reward_catalog r
    JOIN public.partners p ON r.partner_id = p.id
    JOIN public.reward_inventory i ON r.id = i.reward_id
    WHERE r.id = p_reward_id;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: Reserve Reward Inventory
DROP FUNCTION IF EXISTS public.reserve_reward_inventory(UUID, TEXT, JSONB);
CREATE OR REPLACE FUNCTION public.reserve_reward_inventory(
    p_reward_id UUID,
    p_idempotency_key TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS BOOLEAN AS $$
DECLARE
    v_inventory RECORD;
    v_reservation_id UUID;
BEGIN
    -- 1. Idempotency Check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_reservation_id
        FROM public.reward_inventory_reservations
        WHERE idempotency_key = p_idempotency_key;

        IF v_reservation_id IS NOT NULL THEN
            RETURN TRUE; -- Already reserved, return success (Idempotent)
        END IF;
    END IF;

    -- 2. Lock the inventory row (FOR UPDATE prevents race conditions)
    SELECT * INTO v_inventory 
    FROM public.reward_inventory 
    WHERE reward_id = p_reward_id 
    FOR UPDATE;

    IF v_inventory IS NULL THEN
        RAISE EXCEPTION 'Reward inventory not found.';
    END IF;

    -- 3. Stock deduction
    IF NOT v_inventory.is_unlimited THEN
        IF v_inventory.stock_remaining <= 0 THEN
            RETURN FALSE; -- Out of stock
        END IF;
        
        UPDATE public.reward_inventory 
        SET stock_remaining = stock_remaining - 1,
            updated_at = now()
        WHERE reward_id = p_reward_id;
    END IF;

    -- 4. Log reservation
    INSERT INTO public.reward_inventory_reservations (
        reward_id, 
        user_id, 
        idempotency_key, 
        metadata
    ) VALUES (
        p_reward_id, 
        auth.uid(), 
        p_idempotency_key, 
        p_metadata
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
