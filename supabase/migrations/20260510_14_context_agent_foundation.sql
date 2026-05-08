-- ==============================================================================
-- MATCHFIT CONTEXT AGENT FOUNDATION
-- @ContextAgent Agent System
-- ==============================================================================

-- 1. CITY CONTEXT (Location metadata cache)
CREATE TABLE IF NOT EXISTS public.city_context (
  city TEXT PRIMARY KEY,
  country TEXT NOT NULL DEFAULT 'TR',
  timezone TEXT,
  latitude NUMERIC,
  longitude NUMERIC,
  metadata JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- 2. WEATHER CACHE (Environmental data cache)
CREATE TABLE IF NOT EXISTS public.weather_cache (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  city TEXT REFERENCES public.city_context(city) ON DELETE CASCADE,
  weather_code TEXT, -- e.g. 'clear-day', 'rainy'
  temperature NUMERIC, -- Celsius
  precipitation_probability NUMERIC, -- 0-100
  wind_speed NUMERIC, -- km/h
  observed_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  expires_at TIMESTAMPTZ NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  UNIQUE(city, observed_at)
);

-- 3. CONTEXT SNAPSHOTS (Point-in-time contextual state for other agents)
CREATE TABLE IF NOT EXISTS public.context_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subject_type TEXT NOT NULL, -- user, event, reward
  subject_id UUID,
  city TEXT,
  timezone TEXT,
  weather_summary JSONB DEFAULT '{}'::jsonb,
  location_summary JSONB DEFAULT '{}'::jsonb,
  indoor_outdoor_signal TEXT, -- indoor, outdoor, unknown
  created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
  idempotency_key TEXT,
  UNIQUE(idempotency_key)
);

-- 4. RLS POLICIES
ALTER TABLE public.city_context ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weather_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.context_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view city context" ON public.city_context FOR SELECT USING (true);
CREATE POLICY "Anyone can view valid weather cache" ON public.weather_cache FOR SELECT USING (expires_at > now());
CREATE POLICY "Users can view their own snapshots" ON public.context_snapshots FOR SELECT TO authenticated 
  USING (subject_id = auth.uid() OR subject_id IS NULL);

-- 5. RPC CONTRACTS

-- upsert_city_context (Admin/Service/Trusted Geocoder)
CREATE OR REPLACE FUNCTION public.upsert_city_context(
    p_city TEXT,
    p_country TEXT DEFAULT 'TR',
    p_timezone TEXT DEFAULT NULL,
    p_latitude NUMERIC DEFAULT NULL,
    p_longitude NUMERIC DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.city_context (city, country, timezone, latitude, longitude, metadata, updated_at)
    VALUES (p_city, p_country, p_timezone, p_latitude, p_longitude, p_metadata, now())
    ON CONFLICT (city) DO UPDATE
    SET 
        country = EXCLUDED.country,
        timezone = COALESCE(p_timezone, city_context.timezone),
        latitude = COALESCE(p_latitude, city_context.latitude),
        longitude = COALESCE(p_longitude, city_context.longitude),
        metadata = city_context.metadata || EXCLUDED.metadata,
        updated_at = now();
END;
$$;

-- upsert_weather_cache (Admin/Service/Weather Fetcher)
CREATE OR REPLACE FUNCTION public.upsert_weather_cache(
    p_city TEXT,
    p_weather_code TEXT,
    p_temperature NUMERIC,
    p_precipitation_probability NUMERIC,
    p_wind_speed NUMERIC,
    p_expires_in_minutes INTEGER DEFAULT 60,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.weather_cache (city, weather_code, temperature, precipitation_probability, wind_speed, expires_at, metadata)
    VALUES (p_city, p_weather_code, p_temperature, p_precipitation_probability, p_wind_speed, now() + (p_expires_in_minutes * interval '1 minute'), p_metadata)
    ON CONFLICT (city, observed_at) DO NOTHING;
END;
$$;

-- get_context_snapshot (Read current state without persisting)
CREATE OR REPLACE FUNCTION public.get_context_snapshot(
    p_subject_type TEXT,
    p_subject_id UUID DEFAULT NULL,
    p_city TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_city TEXT := p_city;
    v_weather JSONB;
    v_city_info JSONB;
BEGIN
    -- 1. Resolve city if not provided
    IF v_city IS NULL AND p_subject_type = 'user' AND p_subject_id IS NOT NULL THEN
        SELECT city INTO v_city FROM public.profiles WHERE id = p_subject_id;
    END IF;

    -- 2. Fetch city context
    SELECT jsonb_build_object('city', city, 'country', country, 'timezone', timezone, 'lat', latitude, 'lng', longitude)
    INTO v_city_info
    FROM public.city_context
    WHERE city = v_city;

    -- 3. Fetch latest active weather
    SELECT jsonb_build_object(
        'code', weather_code, 
        'temp', temperature, 
        'precip', precipitation_probability, 
        'wind', wind_speed,
        'observed_at', observed_at
    )
    INTO v_weather
    FROM public.weather_cache
    WHERE city = v_city AND expires_at > now()
    ORDER BY observed_at DESC
    LIMIT 1;

    RETURN jsonb_build_object(
        'city_context', COALESCE(v_city_info, jsonb_build_object('city', v_city)),
        'weather', COALESCE(v_weather, '{}'::jsonb),
        'timestamp', now()
    );
END;
$$;

-- create_context_snapshot (Persist state for audit/processing)
CREATE OR REPLACE FUNCTION public.create_context_snapshot(
    p_subject_type TEXT,
    p_subject_id UUID,
    p_city TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_snapshot_id UUID;
    v_context JSONB;
BEGIN
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_snapshot_id FROM public.context_snapshots WHERE idempotency_key = p_idempotency_key;
        IF v_snapshot_id IS NOT NULL THEN
            RETURN v_snapshot_id;
        END IF;
    END IF;

    v_context := public.get_context_snapshot(p_subject_type, p_subject_id, p_city);

    INSERT INTO public.context_snapshots (
        subject_type, subject_id, city, timezone, weather_summary, location_summary, idempotency_key
    )
    VALUES (
        p_subject_type, 
        p_subject_id, 
        v_context->'city_context'->>'city',
        v_context->'city_context'->>'timezone',
        v_context->'weather',
        v_context->'city_context',
        p_idempotency_key
    )
    RETURNING id INTO v_snapshot_id;

    RETURN v_snapshot_id;
END;
$$;

-- 6. GRANTS
GRANT EXECUTE ON FUNCTION public.get_context_snapshot(TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_context_snapshot(TEXT, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_city_context(TEXT, TEXT, TEXT, NUMERIC, NUMERIC, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_weather_cache(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, INTEGER, JSONB) TO authenticated;
