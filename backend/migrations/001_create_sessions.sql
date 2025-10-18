-- Migration: Create sessions table
-- Description: Stores session identifiers for tracking user sessions
-- Author: Dev Agent
-- Date: 2025-01-18

create table if not exists sessions (
  session_id uuid primary key,
  created_at timestamptz default now()
);

-- Add index on created_at for efficient queries
create index if not exists idx_sessions_created_at on sessions(created_at);

-- Disable RLS (backend-only access)
alter table sessions disable row level security;

