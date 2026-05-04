# Database migration notes

The repository currently contains several root-level SQL scripts that appear to
represent incremental Supabase schema changes. Apply them deliberately and keep
the production database at a known version before releasing app changes.

Suggested consolidation path:

1. Move new schema changes into timestamped files under `supabase/migrations/`.
2. Keep one migration responsible for one behavior or table change.
3. Avoid app-side fallbacks for missing columns after a migration is released.
4. Record which migration has been applied to each environment.

Current loose SQL files to reconcile:

- `avatar_storage_setup.sql`
- `event_participants_update.sql`
- `fix_rejoin_notifications.sql`
- `join_approval_setup.sql`
- `location_setup.sql`
- `matchfit_full_migration.sql`
- `matchmaker_setup.sql`
- `notifications_rls_fix.sql`
- `partnership_setup.sql`
- `referee_setup.sql`
- `registration_update.sql`
- `rejoin_flow_fix.sql`
- `remaining_agents_setup.sql`
- `sports_structure_overhaul.sql`
- `sports_translation_en.sql`
- `sports_translation_tr.sql`
- `trust_system_2.sql`
- `trust_system_reset.sql`
