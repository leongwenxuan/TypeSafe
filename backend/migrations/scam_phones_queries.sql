-- Scam Phones - Common SQL Queries Reference
-- These queries can be run directly in Supabase SQL Editor

-- ============================================================
-- LOOKUP QUERIES
-- ============================================================

-- Check if specific number exists
SELECT * FROM scam_phones 
WHERE phone_number = '+1 (734) 733-6172';

-- Search for partial number
SELECT * FROM scam_phones 
WHERE phone_number LIKE '%734%';

-- Get all US scam numbers
SELECT * FROM scam_phones 
WHERE country_code = '+1'
ORDER BY report_count DESC;

-- Get all UK scam numbers
SELECT * FROM scam_phones 
WHERE country_code = '+44'
ORDER BY report_count DESC;


-- ============================================================
-- STATISTICS QUERIES
-- ============================================================

-- Count total scam numbers
SELECT COUNT(*) as total_scam_numbers FROM scam_phones;

-- Count by country
SELECT country_code, COUNT(*) as count
FROM scam_phones
GROUP BY country_code
ORDER BY count DESC;

-- Count by scam type
SELECT scam_type, COUNT(*) as count
FROM scam_phones
GROUP BY scam_type
ORDER BY count DESC;

-- Top 10 most reported scam numbers
SELECT phone_number, scam_type, report_count
FROM scam_phones
ORDER BY report_count DESC
LIMIT 10;

-- Average report count
SELECT AVG(report_count) as avg_reports,
       MIN(report_count) as min_reports,
       MAX(report_count) as max_reports
FROM scam_phones;


-- ============================================================
-- TEMPORAL QUERIES
-- ============================================================

-- Recently added scam numbers (last 7 days)
SELECT phone_number, scam_type, created_at
FROM scam_phones
WHERE created_at > now() - interval '7 days'
ORDER BY created_at DESC;

-- Recently reported (last 30 days)
SELECT phone_number, scam_type, last_reported_at, report_count
FROM scam_phones
WHERE last_reported_at > now() - interval '30 days'
ORDER BY last_reported_at DESC;

-- Old entries (over 1 year)
SELECT phone_number, scam_type, report_count, created_at
FROM scam_phones
WHERE created_at < now() - interval '1 year'
ORDER BY created_at ASC;


-- ============================================================
-- INSERT/UPDATE OPERATIONS
-- ============================================================

-- Add a new scam number
INSERT INTO scam_phones (
  phone_number, 
  country_code, 
  scam_type, 
  notes, 
  report_count
) VALUES (
  '+1 (555) 999-8888',
  '+1',
  'Fake IRS',
  'Claims unpaid taxes',
  1
)
ON CONFLICT (phone_number) DO NOTHING;

-- Update report count for existing number
UPDATE scam_phones
SET report_count = report_count + 1,
    last_reported_at = now()
WHERE phone_number = '+1 (734) 733-6172'
RETURNING *;

-- Update scam type and notes
UPDATE scam_phones
SET scam_type = 'Updated Scam Type',
    notes = 'Updated notes with more details'
WHERE phone_number = '+1 (734) 733-6172';

-- Bulk insert (with conflict handling)
INSERT INTO scam_phones (phone_number, country_code, scam_type, notes, report_count) 
VALUES
  ('+1 (555) 111-1111', '+1', 'Type A', 'Notes A', 5),
  ('+1 (555) 222-2222', '+1', 'Type B', 'Notes B', 3),
  ('+1 (555) 333-3333', '+1', 'Type C', 'Notes C', 8)
ON CONFLICT (phone_number) 
DO UPDATE SET 
  report_count = scam_phones.report_count + EXCLUDED.report_count,
  last_reported_at = now();


-- ============================================================
-- ANALYSIS QUERIES
-- ============================================================

-- Find high-confidence scams (many reports)
SELECT phone_number, scam_type, report_count
FROM scam_phones
WHERE report_count >= 10
ORDER BY report_count DESC;

-- Find potential false positives (low reports, old)
SELECT phone_number, scam_type, report_count, created_at
FROM scam_phones
WHERE report_count <= 2 
  AND created_at < now() - interval '6 months'
ORDER BY created_at ASC;

-- Scam type distribution
SELECT 
  scam_type,
  COUNT(*) as number_count,
  SUM(report_count) as total_reports,
  AVG(report_count) as avg_reports_per_number,
  MIN(first_reported_at) as earliest_report,
  MAX(last_reported_at) as latest_report
FROM scam_phones
GROUP BY scam_type
ORDER BY total_reports DESC;

-- Country-wise statistics
SELECT 
  country_code,
  COUNT(*) as unique_numbers,
  SUM(report_count) as total_reports,
  AVG(report_count) as avg_reports
FROM scam_phones
GROUP BY country_code
ORDER BY total_reports DESC;


-- ============================================================
-- MAINTENANCE QUERIES
-- ============================================================

-- Find duplicates (should be none due to UNIQUE constraint)
SELECT phone_number, COUNT(*) as count
FROM scam_phones
GROUP BY phone_number
HAVING COUNT(*) > 1;

-- Clean up old low-confidence entries (use with caution!)
-- DELETE FROM scam_phones 
-- WHERE report_count < 3 
--   AND created_at < now() - interval '1 year';

-- Archive old entries to another table (example)
-- CREATE TABLE scam_phones_archive AS
-- SELECT * FROM scam_phones 
-- WHERE created_at < now() - interval '2 years';

-- Reset a test entry
DELETE FROM scam_phones 
WHERE phone_number = '+1 (555) 123-4567';


-- ============================================================
-- EXPORT QUERIES
-- ============================================================

-- Export for backup (CSV format)
COPY (
  SELECT phone_number, country_code, scam_type, report_count, notes
  FROM scam_phones
  ORDER BY report_count DESC
) TO '/tmp/scam_phones_backup.csv' WITH CSV HEADER;

-- Export high-priority scams only
COPY (
  SELECT phone_number, country_code, scam_type, report_count, notes
  FROM scam_phones
  WHERE report_count >= 10
  ORDER BY report_count DESC
) TO '/tmp/high_priority_scams.csv' WITH CSV HEADER;


-- ============================================================
-- PERFORMANCE QUERIES
-- ============================================================

-- Check index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename = 'scam_phones';

-- Table statistics
SELECT 
  n_tup_ins as inserts,
  n_tup_upd as updates,
  n_tup_del as deletes,
  n_live_tup as live_rows,
  n_dead_tup as dead_rows,
  last_vacuum,
  last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'scam_phones';

-- Check table size
SELECT 
  pg_size_pretty(pg_total_relation_size('scam_phones')) as total_size,
  pg_size_pretty(pg_relation_size('scam_phones')) as table_size,
  pg_size_pretty(pg_indexes_size('scam_phones')) as indexes_size;


-- ============================================================
-- VALIDATION QUERIES
-- ============================================================

-- Check for NULL values in important fields
SELECT 
  COUNT(*) FILTER (WHERE phone_number IS NULL) as null_phone_numbers,
  COUNT(*) FILTER (WHERE country_code IS NULL) as null_country_codes,
  COUNT(*) FILTER (WHERE scam_type IS NULL) as null_scam_types,
  COUNT(*) FILTER (WHERE report_count IS NULL) as null_report_counts
FROM scam_phones;

-- Find invalid report counts
SELECT phone_number, report_count
FROM scam_phones
WHERE report_count < 1;

-- Find entries with future dates (should be none)
SELECT phone_number, created_at, first_reported_at, last_reported_at
FROM scam_phones
WHERE created_at > now() 
   OR first_reported_at > now() 
   OR last_reported_at > now();


-- ============================================================
-- SEARCH PATTERNS
-- ============================================================

-- Case-insensitive search in notes
SELECT phone_number, scam_type, notes
FROM scam_phones
WHERE LOWER(notes) LIKE '%irs%'
   OR LOWER(scam_type) LIKE '%irs%';

-- Find tech support scams
SELECT phone_number, country_code, scam_type, report_count
FROM scam_phones
WHERE LOWER(scam_type) LIKE '%tech%'
   OR LOWER(scam_type) LIKE '%support%'
ORDER BY report_count DESC;

-- Find tax-related scams
SELECT phone_number, country_code, scam_type, notes
FROM scam_phones
WHERE LOWER(scam_type) LIKE '%tax%'
   OR LOWER(scam_type) LIKE '%irs%'
   OR LOWER(scam_type) LIKE '%hmrc%'
   OR LOWER(scam_type) LIKE '%ato%'
ORDER BY report_count DESC;

-- Find financial scams
SELECT phone_number, country_code, scam_type, notes
FROM scam_phones
WHERE LOWER(scam_type) LIKE '%bank%'
   OR LOWER(scam_type) LIKE '%fraud%'
   OR LOWER(scam_type) LIKE '%credit%'
ORDER BY report_count DESC;


