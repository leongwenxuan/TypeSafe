-- Migration: Create text_analyses table
-- Description: Stores text analysis results from OpenAI
-- Author: Dev Agent
-- Date: 2025-01-18

create table if not exists text_analyses (
  id bigserial primary key,
  session_id uuid references sessions(session_id),
  app_bundle text,
  snippet text,
  risk_level text check (risk_level in ('low','medium','high')),
  confidence numeric,
  category text,
  explanation text,
  created_at timestamptz default now()
);

-- Add indexes for efficient queries
create index if not exists idx_text_analyses_session_id on text_analyses(session_id);
create index if not exists idx_text_analyses_created_at on text_analyses(created_at);

-- Disable RLS (backend-only access)
alter table text_analyses disable row level security;

