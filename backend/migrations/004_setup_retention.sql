-- Migration: Setup 7-day data retention policy
-- Description: Creates cleanup function and schedules daily cron job
-- Author: Dev Agent
-- Date: 2025-01-18

-- Create cleanup function
create or replace function cleanup_old_data()
returns void as $$
begin
  -- Delete text analyses older than 7 days
  delete from text_analyses where created_at < now() - interval '7 days';
  
  -- Delete scan results older than 7 days
  delete from scan_results where created_at < now() - interval '7 days';
  
  -- Delete orphaned sessions (sessions with no related data and older than 7 days)
  delete from sessions 
  where created_at < now() - interval '7 days'
  and session_id not in (
    select distinct session_id from text_analyses
    union
    select distinct session_id from scan_results
  );
end;
$$ language plpgsql;

-- Note: Schedule the cron job manually in Supabase SQL editor:
-- select cron.schedule('cleanup-old-data', '0 2 * * *', 'select cleanup_old_data()');
-- This runs daily at 2:00 AM UTC

