-- ==============================================================================
-- MatchFit: Add Archive Feature to Notifications
-- ==============================================================================

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;
