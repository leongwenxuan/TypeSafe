# Database Migrations

This directory contains SQL migration files for the TypeSafe Supabase database.

## Execution Order

Run these migrations in order using the Supabase SQL Editor:

1. **001_create_sessions.sql** - Creates the sessions table
2. **002_create_text_analyses.sql** - Creates the text_analyses table with foreign key to sessions
3. **003_create_scan_results.sql** - Creates the scan_results table with foreign key to sessions
4. **004_setup_retention.sql** - Creates the 7-day retention cleanup function
5. **005_create_scam_phones.sql** - Creates the scam_phones table with example scam numbers
6. **006_create_scam_reports.sql** - Creates the scam_reports table for MCP agent (Story 8.3)
7. **007_create_agent_scan_results.sql** - Creates the agent_scan_results table for MCP agent (Story 8.7)

## Manual Steps After Running Migrations

After running all migrations, schedule the cleanup cron job in Supabase SQL Editor:

```sql
select cron.schedule('cleanup-old-data', '0 2 * * *', 'select cleanup_old_data()');
```

This schedules the cleanup to run daily at 2:00 AM UTC.

## Verification

To verify all tables are created correctly:

```sql
-- List all tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';

-- Check sessions table structure
\d sessions

-- Check text_analyses table structure
\d text_analyses

-- Check scan_results table structure
\d scan_results

-- Check scam_phones table structure
\d scam_phones

-- Check scam_reports table structure
\d scam_reports

-- Check agent_scan_results table structure
\d agent_scan_results

-- Verify cron job is scheduled
SELECT * FROM cron.job;
```

## Testing the Cleanup Function

To manually test the cleanup function:

```sql
-- Run cleanup manually
SELECT cleanup_old_data();

-- Check what would be deleted (without actually deleting)
SELECT count(*) FROM text_analyses WHERE created_at < now() - interval '7 days';
SELECT count(*) FROM scan_results WHERE created_at < now() - interval '7 days';
```

## Rollback

If you need to rollback these migrations:

```sql
-- Drop in reverse order
DROP TABLE IF EXISTS agent_scan_results;
DROP TABLE IF EXISTS scam_reports;
DROP TABLE IF EXISTS scam_phones;
DROP FUNCTION IF EXISTS cleanup_old_data();
DROP TABLE IF EXISTS scan_results;
DROP TABLE IF EXISTS text_analyses;
DROP TABLE IF EXISTS sessions;
```

