-- Migration: Create scan_results table
-- Description: Stores screenshot scan analysis results from Gemini
-- Author: Dev Agent
-- Date: 2025-01-18

create table if not exists scan_results (
  id bigserial primary key,
  session_id uuid references sessions(session_id),
  ocr_text text,
  risk_level text,
  confidence numeric,
  category text,
  explanation text,
  created_at timestamptz default now()
);

-- Add indexes for efficient queries
create index if not exists idx_scan_results_session_id on scan_results(session_id);
create index if not exists idx_scan_results_created_at on scan_results(created_at);

-- Disable RLS (backend-only access)
alter table scan_results disable row level security;

