# Supabase Database Setup Guide

This guide walks through setting up the Supabase database for TypeSafe.

## Prerequisites

- Supabase account (free tier is sufficient for development)
- Backend dependencies installed (`pip install -r requirements.txt`)

## Step 1: Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign in or create an account
3. Click "New Project"
4. Fill in project details:
   - **Name**: TypeSafe (or your preferred name)
   - **Database Password**: Choose a strong password (save this securely)
   - **Region**: Select closest to you or your target users
   - **Pricing Plan**: Free (sufficient for development)
5. Click "Create new project"
6. Wait for project to finish setting up (~2 minutes)

## Step 2: Get API Credentials

1. In your Supabase project dashboard, go to **Settings** (gear icon) → **API**
2. Find and copy these values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **service_role key** (NOT anon key): This is the secret key with full access

## Step 3: Configure Backend Environment

1. Create a `.env` file in the `backend/` directory:
   ```bash
   cd backend
   cp .env.example .env  # If .env.example exists
   ```

2. Edit `.env` and add your Supabase credentials:
   ```env
   # Supabase Configuration
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_KEY=your-service-role-key-here
   
   # Other required settings
   BACKEND_ENV=development
   BACKEND_HOST=0.0.0.0
   BACKEND_PORT=8000
   BACKEND_API_KEY=dev-key-change-in-production
   
   # AI APIs (can be added later)
   OPENAI_API_KEY=your-openai-key-here
   GEMINI_API_KEY=your-gemini-key-here
   ```

3. **Important**: Never commit `.env` to git! It's already in `.gitignore`.

## Step 4: Run Database Migrations

Execute the SQL migrations in the Supabase SQL Editor in this order:

### 4.1 Open SQL Editor
1. In Supabase dashboard, go to **SQL Editor** (left sidebar)
2. Click **New Query**

### 4.2 Run Migration 001 - Create Sessions Table
Copy and paste the content from `migrations/001_create_sessions.sql` and click **Run**.

Expected output: "Success. No rows returned"

### 4.3 Run Migration 002 - Create Text Analyses Table
Copy and paste the content from `migrations/002_create_text_analyses.sql` and click **Run**.

Expected output: "Success. No rows returned"

### 4.4 Run Migration 003 - Create Scan Results Table
Copy and paste the content from `migrations/003_create_scan_results.sql` and click **Run**.

Expected output: "Success. No rows returned"

### 4.5 Run Migration 004 - Setup Retention Policy
Copy and paste the content from `migrations/004_setup_retention.sql` and click **Run**.

Expected output: "Success. No rows returned"

### 4.6 Schedule Cleanup Cron Job
After running migration 004, schedule the daily cleanup job:

```sql
select cron.schedule('cleanup-old-data', '0 2 * * *', 'select cleanup_old_data()');
```

This runs the cleanup function daily at 2:00 AM UTC.

## Step 5: Verify Database Setup

Run these verification queries in the SQL Editor:

### Check Tables Exist
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;
```

Expected output: `scan_results`, `sessions`, `text_analyses`

### Check Indexes
```sql
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

Should show indexes for `session_id` and `created_at` on relevant tables.

### Check RLS Status
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;
```

All tables should show `rowsecurity = false` (RLS disabled for backend-only access).

### Check Cron Job
```sql
SELECT * FROM cron.job WHERE jobname = 'cleanup-old-data';
```

Should show the scheduled cleanup job.

## Step 6: Test Backend Connection

1. Start the backend server:
   ```bash
   cd backend
   source venv/bin/activate
   uvicorn app.main:app --reload
   ```

2. In another terminal, test the health endpoint:
   ```bash
   curl http://localhost:8000/health
   ```

3. Check logs for database connection success.

## Step 7: Run Integration Tests

Run the database integration tests:

```bash
cd backend
source venv/bin/activate
pytest tests/test_db_operations.py -v
```

**Important**: Tests will create real data in your database. Use a test project or test tables for this.

## Troubleshooting

### Error: "SUPABASE_URL and SUPABASE_KEY must be set"
- Check that `.env` file exists in `backend/` directory
- Verify environment variables are set correctly
- Try restarting the backend server

### Error: "relation 'sessions' does not exist"
- Run the migrations in the correct order (001 → 002 → 003 → 004)
- Verify migrations completed successfully in SQL Editor

### Error: "violates foreign key constraint"
- Ensure you've created a session before inserting analyses
- Check that `session_id` exists in the `sessions` table

### Error: "new row violates check constraint"
- For `text_analyses`, `risk_level` must be exactly: 'low', 'medium', or 'high'
- Check for typos or different casing

### Tests Failing
- Ensure migrations have been run
- Check that SUPABASE_URL and SUPABASE_KEY are set correctly
- Verify you're using the service_role key (not anon key)
- Consider using a separate test Supabase project

## Security Notes

1. **Service Role Key**: The service_role key bypasses RLS and has full database access. Keep it secure!
2. **Never expose in client code**: This key should ONLY be used in the backend server
3. **Environment variables**: Always use environment variables, never hardcode credentials
4. **Production**: In production, use more restrictive permissions and consider enabling RLS with service role bypass

## Next Steps

After database setup is complete:
- ✅ Database schema created
- ✅ Retention policy configured
- ✅ Backend can connect to Supabase
- ✅ Integration tests passing

You're now ready to implement the analysis endpoints (Stories 1.6-1.8).

