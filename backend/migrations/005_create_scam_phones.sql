-- Migration: Create scam_phones table
-- Description: Stores known scam phone numbers for validation
-- Author: Dev Agent
-- Date: 2025-10-18

create table if not exists scam_phones (
  id uuid primary key default gen_random_uuid(),
  phone_number text not null unique,
  country_code text,
  report_count integer default 1,
  first_reported_at timestamptz default now(),
  last_reported_at timestamptz default now(),
  scam_type text,
  notes text,
  created_at timestamptz default now()
);

-- Add index on phone_number for fast lookups
create index if not exists idx_scam_phones_phone_number on scam_phones(phone_number);

-- Add index on created_at for retention cleanup
create index if not exists idx_scam_phones_created_at on scam_phones(created_at);

-- Disable RLS (backend-only access)
alter table scam_phones disable row level security;

-- Insert example scam phone numbers
insert into scam_phones (phone_number, country_code, report_count, scam_type, notes) values
  ('+1 (734) 733-6172', '+1', 15, 'IRS Impersonation', 'Reported multiple times claiming to be IRS demanding payment'),
  ('+1 (202) 555-0147', '+1', 23, 'Tech Support Scam', 'Claims to be Microsoft/Apple tech support'),
  ('+1 (646) 555-0198', '+1', 8, 'Social Security Scam', 'Threatens suspension of SSN'),
  ('+1 (305) 555-0143', '+1', 12, 'Bank Fraud', 'Pretends to be from major banks'),
  ('+44 20 7946 0958', '+44', 19, 'HMRC Scam', 'UK tax authority impersonation'),
  ('+1 (415) 555-0176', '+1', 31, 'Prize/Lottery Scam', 'Claims user won a prize or lottery'),
  ('+1 (512) 555-0134', '+1', 6, 'Romance Scam', 'Dating/romance fraud attempts'),
  ('+91 22 4567 8901', '+91', 14, 'Tech Support Scam', 'Indian call center impersonating tech support'),
  ('+1 (888) 555-0192', '+1', 27, 'Robocall Scam', 'Automated warranty/insurance scam'),
  ('+61 2 9876 5432', '+61', 9, 'ATO Scam', 'Australian Tax Office impersonation')
on conflict (phone_number) do nothing;


