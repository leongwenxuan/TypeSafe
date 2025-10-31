# Story 8.12: Cron Job Setup Guide

**Quick guide for setting up automated scam database maintenance**

---

## Overview

This guide covers setting up cron jobs for:
1. **Daily PhishTank Updates** (2 AM daily)
2. **Weekly Scam Archival** (3 AM Sundays)
3. **Monthly Archive Cleanup** (4 AM first Sunday)

---

## Prerequisites

- Python virtual environment activated
- Supabase credentials configured
- Log directory created: `/var/log/typesafe/`
- Scripts tested manually

---

## Step 1: Create Log Directory

```bash
# Create log directory
sudo mkdir -p /var/log/typesafe

# Set ownership (replace typesafe-user with your user)
sudo chown typesafe-user:typesafe-user /var/log/typesafe

# Set permissions
sudo chmod 755 /var/log/typesafe
```

---

## Step 2: Test Scripts Manually

Before setting up cron jobs, test each script:

```bash
# Activate virtual environment
cd /path/to/TypeSafe/backend
source venv/bin/activate

# Test PhishTank update (dry run)
python scripts/update_phishtank.py --dry-run

# Test archival (dry run)
python scripts/archive_old_scams.py --dry-run

# Verify logs
ls -lh /tmp/phishtank_update.log
ls -lh /tmp/scam_archival.log
```

---

## Step 3: Create Cron Configuration

Create file: `/etc/cron.d/typesafe-scam-maintenance`

```bash
# TypeSafe Scam Database Maintenance Cron Jobs
# Story 8.12 - Database Seeding & Maintenance

SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=admin@yourdomain.com

# Environment variables (replace with your values)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key

# Daily PhishTank update at 2 AM
0 2 * * * typesafe-user /path/to/venv/bin/python /path/to/backend/scripts/update_phishtank.py >> /var/log/typesafe/phishtank_updates.log 2>&1

# Weekly archival at 3 AM every Sunday
0 3 * * 0 typesafe-user /path/to/venv/bin/python /path/to/backend/scripts/archive_old_scams.py >> /var/log/typesafe/scam_archival.log 2>&1

# Monthly cleanup of very old archives (first Sunday of month at 4 AM)
0 4 1-7 * 0 typesafe-user [ "$(date +\%u)" = "7" ] && /path/to/venv/bin/python /path/to/backend/scripts/archive_old_scams.py --cleanup-years 2 >> /var/log/typesafe/archive_cleanup.log 2>&1
```

**Important:** Replace:
- `typesafe-user` with your actual system user
- `/path/to/venv` with your actual venv path
- `/path/to/backend` with your actual backend path
- `admin@yourdomain.com` with your email for alerts
- Supabase credentials with your actual values

---

## Step 4: Set Permissions

```bash
# Set file ownership
sudo chown root:root /etc/cron.d/typesafe-scam-maintenance

# Set permissions (must be 644 or cron won't run it)
sudo chmod 644 /etc/cron.d/typesafe-scam-maintenance
```

---

## Step 5: Verify Cron Installation

```bash
# Restart cron service
sudo systemctl restart cron

# Verify cron is running
sudo systemctl status cron

# Check cron logs for errors
sudo tail -f /var/log/syslog | grep CRON
```

---

## Alternative: User Crontab

If you prefer user-level crontab instead of `/etc/cron.d/`:

```bash
# Edit user crontab
crontab -e

# Add these lines:
# Daily PhishTank update at 2 AM
0 2 * * * /path/to/venv/bin/python /path/to/backend/scripts/update_phishtank.py >> /var/log/typesafe/phishtank_updates.log 2>&1

# Weekly archival at 3 AM every Sunday
0 3 * * 0 /path/to/venv/bin/python /path/to/backend/scripts/archive_old_scams.py >> /var/log/typesafe/scam_archival.log 2>&1

# Save and exit
```

---

## Monitoring & Maintenance

### Check Cron Job Status

```bash
# View active cron jobs
crontab -l

# Or for system-wide cron
ls -la /etc/cron.d/typesafe*

# Check recent cron executions
grep "typesafe" /var/log/syslog | tail -20
```

### Monitor Log Files

```bash
# PhishTank updates
tail -f /var/log/typesafe/phishtank_updates.log

# Archival
tail -f /var/log/typesafe/scam_archival.log

# Check log sizes
du -sh /var/log/typesafe/*
```

### Log Rotation

Create `/etc/logrotate.d/typesafe-scam-maintenance`:

```
/var/log/typesafe/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0644 typesafe-user typesafe-user
}
```

---

## Troubleshooting

### Cron Job Not Running

**Check cron service:**
```bash
sudo systemctl status cron
sudo systemctl restart cron
```

**Check file permissions:**
```bash
ls -la /etc/cron.d/typesafe-scam-maintenance
# Should be: -rw-r--r-- 1 root root
```

**Check for errors in syslog:**
```bash
sudo tail -50 /var/log/syslog | grep CRON
```

### Script Execution Errors

**Test script directly:**
```bash
sudo -u typesafe-user /path/to/venv/bin/python /path/to/backend/scripts/update_phishtank.py
```

**Check environment variables:**
```bash
# Add debug output to script
export SUPABASE_URL=...
export SUPABASE_KEY=...
python scripts/update_phishtank.py --dry-run
```

**Check Python path:**
```bash
which python
/path/to/venv/bin/python --version
```

### No Logs Generated

**Check log directory permissions:**
```bash
ls -ld /var/log/typesafe/
# Should be: drwxr-xr-x typesafe-user typesafe-user
```

**Test log writing:**
```bash
sudo -u typesafe-user touch /var/log/typesafe/test.log
ls -la /var/log/typesafe/test.log
```

### Email Alerts Not Working

**Install mail utility:**
```bash
sudo apt-get install mailutils
```

**Test email:**
```bash
echo "Test email from cron" | mail -s "Test" admin@yourdomain.com
```

**Check MAILTO in cron file:**
```bash
grep MAILTO /etc/cron.d/typesafe-scam-maintenance
```

---

## Manual Execution

For testing or one-off runs:

```bash
# Activate venv
cd /path/to/TypeSafe/backend
source venv/bin/activate

# Manual PhishTank update
python scripts/update_phishtank.py

# Manual archival
python scripts/archive_old_scams.py

# Dry run to see what would happen
python scripts/update_phishtank.py --dry-run
python scripts/archive_old_scams.py --dry-run
```

---

## Cron Schedule Reference

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday=0)
│ │ │ │ │
│ │ │ │ │
* * * * * command to execute
```

**Examples:**
- `0 2 * * *` - Daily at 2:00 AM
- `0 3 * * 0` - Sundays at 3:00 AM
- `0 4 1-7 * 0` - First Sunday of month at 4:00 AM
- `*/30 * * * *` - Every 30 minutes
- `0 */6 * * *` - Every 6 hours

---

## Docker/Kubernetes Alternative

If running in containers, use these alternatives:

### Docker Compose

Add to `docker-compose.yml`:

```yaml
services:
  cron:
    build: .
    command: cron -f
    volumes:
      - ./scripts:/app/scripts
      - ./logs:/var/log/typesafe
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_KEY=${SUPABASE_KEY}
```

Create `Dockerfile.cron`:

```dockerfile
FROM python:3.12-slim

# Install cron
RUN apt-get update && apt-get install -y cron

# Copy scripts
COPY scripts/ /app/scripts/
COPY requirements.txt /app/

# Install dependencies
RUN pip install -r /app/requirements.txt

# Add cron jobs
COPY crontab /etc/cron.d/typesafe-cron
RUN chmod 0644 /etc/cron.d/typesafe-cron
RUN crontab /etc/cron.d/typesafe-cron

CMD ["cron", "-f"]
```

### Kubernetes CronJob

Create `kubernetes/phishtank-cronjob.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: phishtank-update
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: update-phishtank
            image: typesafe-backend:latest
            command:
            - python
            - scripts/update_phishtank.py
            env:
            - name: SUPABASE_URL
              valueFrom:
                secretKeyRef:
                  name: supabase-secrets
                  key: url
            - name: SUPABASE_KEY
              valueFrom:
                secretKeyRef:
                  name: supabase-secrets
                  key: service-role-key
          restartPolicy: OnFailure
```

---

## Health Checks

Create a simple health check endpoint:

```python
# Add to main.py
@app.get("/health/maintenance")
async def maintenance_health():
    """Check last successful maintenance run."""
    from datetime import datetime, timedelta
    import os.path
    
    health = {
        "phishtank_update": "unknown",
        "archival": "unknown"
    }
    
    # Check PhishTank log
    log_path = "/var/log/typesafe/phishtank_updates.log"
    if os.path.exists(log_path):
        mtime = os.path.getmtime(log_path)
        last_update = datetime.fromtimestamp(mtime)
        age = datetime.now() - last_update
        
        health["phishtank_update"] = {
            "last_run": last_update.isoformat(),
            "age_hours": age.total_seconds() / 3600,
            "status": "ok" if age < timedelta(hours=26) else "warning"
        }
    
    return health
```

---

## Summary

✅ **Cron Jobs Configured:**
- Daily PhishTank updates (2 AM)
- Weekly archival (Sunday 3 AM)
- Monthly cleanup (First Sunday 4 AM)

✅ **Monitoring Enabled:**
- Log files in `/var/log/typesafe/`
- Email alerts on errors
- Health check endpoint

✅ **Tested:**
- Manual script execution
- Dry run mode
- Log rotation

---

**Setup Complete!** Your scam database will now be maintained automatically.

For questions or issues, refer to the main implementation summary: `STORY_8_12_IMPLEMENTATION_SUMMARY.md`

