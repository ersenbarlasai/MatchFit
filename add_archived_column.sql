-- Add is_archived column to events table
ALTER TABLE events ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_events_is_archived ON events(is_archived);
