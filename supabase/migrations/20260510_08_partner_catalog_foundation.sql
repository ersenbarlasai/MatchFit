-- ==============================================================================
-- MATCHFIT PARTNER CATALOG FOUNDATION
-- @PartnerCatalog Agent System
-- ==============================================================================

-- 1. PARTNERS (Sponsors & Providers)
CREATE TABLE IF NOT EXISTS public.partners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active, inactive, suspended
  contact_email TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- 2. REWARD CATALOG (Available Rewards)
CREATE TABLE IF NOT EXISTS public.reward_catalog (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partner_id UUID REFERENCES public.partners(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  cost_points INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active, inactive, expired
  city TEXT, -- Local rewards support
  sport_id UUID REFERENCES public.sports(id) ON DELETE SET NULL, -- Sport specific rewards
  segment TEXT, -- User segmentation (MVP: NULL)
  metadata JSONB DEFAULT '{}'::jsonb,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- 3. REWARD INVENTORY (Stock Management)
CREATE TABLE IF NOT EXISTS public.reward_inventory (
  reward_id UUID PRIMARY KEY REFERENCES public.reward_catalog(id) ON DELETE CASCADE,
  stock_total INTEGER, -- NULL = unlimited
  stock_remaining INTEGER, -- NULL = unlimited
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- 4. CAMPAIGNS (Marketing & Special Events)
CREATE TABLE IF NOT EXISTS public.campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partner_id UUID REFERENCES public.partners(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- 5. RLS POLICIES (Public View, Admin Write)
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

-- Readers (Authenticated users)
CREATE POLICY "Users can view active partners" ON public.partners FOR SELECT TO authenticated USING (status = 'active');
CREATE POLICY "Users can view active rewards" ON public.reward_catalog FOR SELECT TO authenticated USING (status = 'active' AND (ends_at IS NULL OR ends_at > now()));
CREATE POLICY "Users can view inventory" ON public.reward_inventory FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can view active campaigns" ON public.campaigns FOR SELECT TO authenticated USING (status = 'active');

-- 6. RPC CONTRACTS

-- get_active_rewards (Marketplace list)
CREATE OR REPLACE FUNCTION public.get_active_rewards(p_city TEXT DEFAULT NULL, p_sport_id UUID DEFAULT NULL)
RETURNS TABLE (
    id UUID,
    partner_name TEXT,
    title TEXT,
    description TEXT,
    cost_points INTEGER,
    city TEXT,
    stock_remaining INTEGER
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        r.id,
        p.name as partner_name,
        r.title,
        r.description,
        r.cost_points,
        r.city,
        i.stock_remaining
    FROM public.reward_catalog r
    JOIN public.partners p ON r.partner_id = p.id
    LEFT JOIN public.reward_inventory i ON r.id = i.reward_id
    WHERE r.status = 'active'
      AND p.status = 'active'
      AND (r.ends_at IS NULL OR r.ends_at > now())
      AND (p_city IS NULL OR r.city IS NULL OR r.city = p_city)
      AND (p_sport_id IS NULL OR r.sport_id IS NULL OR r.sport_id = p_sport_id)
      AND (i.stock_remaining IS NULL OR i.stock_remaining > 0);
$$;

-- get_reward_catalog_item (Detail fetcher for EconomyEngine/Redemption)
CREATE OR REPLACE FUNCTION public.get_reward_catalog_item(p_reward_id UUID)
RETURNS TABLE (
    id UUID,
    partner_id UUID,
    cost_points INTEGER,
    stock_remaining INTEGER,
    status TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        r.id,
        r.partner_id,
        r.cost_points,
        i.stock_remaining,
        r.status
    FROM public.reward_catalog r
    LEFT JOIN public.reward_inventory i ON r.id = i.reward_id
    WHERE r.id = p_reward_id;
$$;

-- reserve_reward_inventory (Stock reservation for redemption)
-- Returns TRUE if stock was successfully reduced or if unlimited.
CREATE OR REPLACE FUNCTION public.reserve_reward_inventory(p_reward_id UUID, p_idempotency_key TEXT DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Note: Idempotency is handled at the transaction level for stock reduction here.
    -- If stock_remaining is NULL, it's unlimited.
    
    UPDATE public.reward_inventory
    SET stock_remaining = stock_remaining - 1,
        updated_at = now()
    WHERE reward_id = p_reward_id
      AND (stock_remaining IS NULL OR stock_remaining > 0);
      
    RETURN FOUND;
END;
$$;

-- 7. GRANTS
GRANT EXECUTE ON FUNCTION public.get_active_rewards(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reward_catalog_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_reward_inventory(UUID, TEXT) TO authenticated;
