# Data Model (Supabase / Postgres)

```sql
create table sessions (
  session_id uuid primary key,
  created_at timestamptz default now()
);

create table text_analyses (
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

create table scan_results (
  id bigserial primary key,
  session_id uuid references sessions(session_id),
  ocr_text text,
  risk_level text,
  confidence numeric,
  category text,
  explanation text,
  created_at timestamptz default now()
);
```

**Retention**
```sql
-- daily job: delete older than 7 days
delete from text_analyses where created_at < now() - interval '7 days';
delete from scan_results where created_at < now() - interval '7 days';
```

