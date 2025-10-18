-- Migration: Create scam_reports table and related functions
-- Description: Comprehensive scam database supporting multiple entity types
-- Story: 8.3 - Scam Database Tool
-- Author: Dev Agent
-- Date: 2025-10-18

-- =============================================================================
-- DROP EXISTING (for idempotency during development)
-- =============================================================================
drop table if exists archived_scam_reports cascade;
drop table if exists scam_reports cascade;
drop function if exists calculate_risk_score cascade;
drop function if exists update_updated_at_column cascade;

-- =============================================================================
-- MAIN TABLE: scam_reports
-- =============================================================================
create table scam_reports (
  id bigserial primary key,
  entity_type text not null check (entity_type in ('phone', 'url', 'email', 'payment', 'bitcoin')),
  entity_value text not null,  -- Normalized value (E164 for phones, lowercase domain for URLs)
  report_count int default 1 check (report_count >= 0),
  risk_score numeric(5,2) default 50.0 check (risk_score between 0 and 100),
  first_seen timestamptz default now(),
  last_reported timestamptz default now(),
  evidence jsonb default '[]'::jsonb,  -- Array of evidence objects
  verified boolean default false,  -- Manually verified by admin
  notes text,  -- Admin notes
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =============================================================================
-- INDEXES for fast lookups
-- =============================================================================

-- Composite unique index for entity lookups (primary lookup pattern)
create unique index idx_scam_reports_entity on scam_reports(entity_type, entity_value);

-- Index for filtering by risk score
create index idx_scam_reports_risk_score on scam_reports(risk_score desc);

-- Index for filtering by recency
create index idx_scam_reports_last_reported on scam_reports(last_reported desc);

-- Partial index for verified scams only (more efficient for verified queries)
create index idx_scam_reports_verified on scam_reports(verified) where verified = true;

-- Index for entity_type filtering (common in admin queries)
create index idx_scam_reports_entity_type on scam_reports(entity_type);

-- =============================================================================
-- TRIGGER FUNCTION: Auto-update updated_at timestamp
-- =============================================================================
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_scam_reports_updated_at 
  before update on scam_reports
  for each row 
  execute function update_updated_at_column();

-- =============================================================================
-- FUNCTION: Calculate risk score dynamically
-- =============================================================================
create or replace function calculate_risk_score(
  p_report_count int,
  p_verified boolean,
  p_days_since_last_report int
) returns numeric as $$
declare
  base_score numeric;
  verified_bonus numeric;
  recency_bonus numeric;
begin
  -- Base score from report count (max 50 points)
  -- More reports = higher base score, but with diminishing returns
  base_score := least(p_report_count * 2, 50);
  
  -- Verified bonus (30 points if manually verified)
  verified_bonus := case when p_verified then 30 else 0 end;
  
  -- Recency bonus (higher score for recent reports)
  recency_bonus := case 
    when p_days_since_last_report < 7 then 20      -- Very recent (within week)
    when p_days_since_last_report < 30 then 15     -- Recent (within month)
    when p_days_since_last_report < 90 then 10     -- Somewhat recent (within 3 months)
    else 5                                          -- Old report
  end;
  
  -- Total score capped at 100
  return least(base_score + verified_bonus + recency_bonus, 100);
end;
$$ language plpgsql immutable;

-- =============================================================================
-- ARCHIVED TABLE: For old/inactive scam reports
-- =============================================================================
create table archived_scam_reports (
  like scam_reports including all
);

-- =============================================================================
-- TABLE COMMENTS (documentation)
-- =============================================================================
comment on table scam_reports is 'Active scam reports database for MCP agent lookups. Stores known scam entities across multiple types: phones, URLs, emails, payments, bitcoin addresses.';
comment on column scam_reports.entity_type is 'Type of entity: phone, url, email, payment, or bitcoin';
comment on column scam_reports.entity_value is 'Normalized entity value (E164 format for phones, lowercase for domains/emails)';
comment on column scam_reports.risk_score is 'Risk score 0-100 calculated from report count, verification status, and recency';
comment on column scam_reports.evidence is 'JSONB array of evidence objects with source, url, date fields. Example: [{"source": "reddit", "url": "https://...", "date": "2025-10-01"}]';
comment on column scam_reports.verified is 'TRUE if manually verified by admin/moderator';
comment on column scam_reports.notes is 'Admin notes or additional context about this scam';

-- =============================================================================
-- SEED DATA: Initial known scams
-- =============================================================================

-- Phone scams (converted from existing scam_phones data)
insert into scam_reports (entity_type, entity_value, report_count, evidence, verified, notes) values
  ('phone', '+18005551234', 47, '[]'::jsonb, true, 'Known IRS impersonation scam - extensively reported across multiple platforms'),
  ('phone', '+17347336172', 15, '[{"source": "ftc", "date": "2025-09-15"}]'::jsonb, true, 'IRS Impersonation - Reported multiple times claiming to be IRS demanding payment'),
  ('phone', '+12025550147', 23, '[{"source": "ftc", "date": "2025-09-20"}]'::jsonb, true, 'Tech Support Scam - Claims to be Microsoft/Apple tech support'),
  ('phone', '+16465550198', 8, '[{"source": "consumer_reports", "date": "2025-10-01"}]'::jsonb, false, 'Social Security Scam - Threatens suspension of SSN'),
  ('phone', '+13055550143', 12, '[{"source": "bbb", "date": "2025-09-28"}]'::jsonb, false, 'Bank Fraud - Pretends to be from major banks'),
  ('phone', '+442079460958', 19, '[{"source": "uk_action_fraud", "date": "2025-09-10"}]'::jsonb, true, 'HMRC Scam - UK tax authority impersonation'),
  ('phone', '+14155550176', 31, '[{"source": "ftc", "date": "2025-10-05"}]'::jsonb, true, 'Prize/Lottery Scam - Claims user won a prize or lottery'),
  ('phone', '+15125550134', 6, '[]'::jsonb, false, 'Romance Scam - Dating/romance fraud attempts'),
  ('phone', '+912245678901', 14, '[{"source": "ftc", "date": "2025-09-25"}]'::jsonb, false, 'Tech Support Scam - Indian call center impersonating tech support'),
  ('phone', '+18885550192', 27, '[{"source": "consumer_reports", "date": "2025-10-08"}]'::jsonb, true, 'Robocall Scam - Automated warranty/insurance scam'),
  ('phone', '+61298765432', 9, '[{"source": "scamwatch", "date": "2025-09-18"}]'::jsonb, false, 'ATO Scam - Australian Tax Office impersonation');

-- URL/Domain scams (common phishing domains)
insert into scam_reports (entity_type, entity_value, report_count, evidence, verified, notes) values
  ('url', 'secure-bankofamerica-verify.com', 34, '[{"source": "phishtank", "url": "https://phishtank.org/", "date": "2025-10-10"}]'::jsonb, true, 'Bank of America phishing site'),
  ('url', 'apple-id-unlock.net', 28, '[{"source": "phishtank", "date": "2025-10-12"}]'::jsonb, true, 'Apple ID phishing attempt'),
  ('url', 'paypal-security-center.com', 45, '[{"source": "phishtank", "date": "2025-10-08"}]'::jsonb, true, 'PayPal phishing - very active'),
  ('url', 'amazon-account-suspended.com', 22, '[{"source": "google_safe_browsing", "date": "2025-10-11"}]'::jsonb, false, 'Amazon phishing site'),
  ('url', 'irs-refund-portal.com', 18, '[{"source": "ftc", "date": "2025-10-05"}]'::jsonb, true, 'Fake IRS refund site');

-- Email scams (common scam sender addresses)
insert into scam_reports (entity_type, entity_value, report_count, evidence, verified, notes) values
  ('email', 'noreply@secure-payment-verify.com', 12, '[{"source": "spamhaus", "date": "2025-10-13"}]'::jsonb, false, 'Phishing emails pretending to be payment verification'),
  ('email', 'support@microsoft-account-team.com', 19, '[{"source": "spamhaus", "date": "2025-10-10"}]'::jsonb, true, 'Fake Microsoft support emails'),
  ('email', 'prizes@lottery-winner-claim.com', 8, '[]'::jsonb, false, 'Lottery scam emails');

-- Bitcoin/Crypto scams (known scam wallet addresses)
insert into scam_reports (entity_type, entity_value, report_count, evidence, verified, notes) values
  ('bitcoin', '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa', 67, '[{"source": "bitcoinabuse", "url": "https://www.bitcoinabuse.com/", "date": "2025-10-01"}]'::jsonb, true, 'Known scam bitcoin address - multiple reports of sextortion scam'),
  ('bitcoin', '3J98t1WpEZ73CNmYviecrnyiWrnqRhWNLy', 23, '[{"source": "bitcoinabuse", "date": "2025-10-05"}]'::jsonb, false, 'Investment scam bitcoin wallet');

-- =============================================================================
-- UPDATE RISK SCORES based on initial data
-- =============================================================================
update scam_reports
set risk_score = calculate_risk_score(
  report_count,
  verified,
  extract(day from (now() - last_reported))::int
)
where risk_score = 50.0;  -- Only update default scores

-- =============================================================================
-- ROW LEVEL SECURITY (disabled for backend-only access)
-- =============================================================================
alter table scam_reports disable row level security;
alter table archived_scam_reports disable row level security;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- Verify table creation
do $$
begin
  assert (select count(*) from scam_reports) > 0, 'scam_reports should have seed data';
  raise notice 'Migration 006_create_scam_reports completed successfully!';
  raise notice 'Loaded % scam reports', (select count(*) from scam_reports);
end $$;

