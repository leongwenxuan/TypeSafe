# Supervisor Deployment for TypeSafe Celery

This directory contains Supervisor configuration files for deploying TypeSafe Celery workers and Flower monitoring.

## Prerequisites

### Install Supervisor

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install supervisor
```

**CentOS/RHEL:**
```bash
sudo yum install supervisor
sudo systemctl enable supervisord
sudo systemctl start supervisord
```

**Verify installation:**
```bash
supervisorctl version
```

### Create Required Directories

```bash
# Create application directory
sudo mkdir -p /opt/typesafe/backend
sudo useradd -r -s /bin/bash -d /opt/typesafe -m typesafe
sudo chown -R typesafe:typesafe /opt/typesafe

# Create log directory
sudo mkdir -p /var/log/typesafe
sudo chown -R typesafe:typesafe /var/log/typesafe
```

## Installation

### 1. Deploy Application

```bash
# Copy application files
sudo cp -r /path/to/backend/* /opt/typesafe/backend/
sudo chown -R typesafe:typesafe /opt/typesafe/backend

# Create virtual environment
sudo -u typesafe bash -c "cd /opt/typesafe/backend && python3 -m venv venv"
sudo -u typesafe bash -c "cd /opt/typesafe/backend && venv/bin/pip install -r requirements.txt"
```

### 2. Configure Environment

Edit the configuration files to include your API keys:

**Option A: Direct in config file**
```bash
sudo nano /etc/supervisor/conf.d/typesafe-celery.conf
```

Add to environment section:
```ini
environment=
    ...existing vars...,
    GROQ_API_KEY="your_key",
    GEMINI_API_KEY="your_key",
    SUPABASE_URL="your_url",
    SUPABASE_KEY="your_key"
```

**Option B: Use wrapper script (recommended)**

Create `/opt/typesafe/backend/start_celery.sh`:
```bash
#!/bin/bash
# Load environment from .env file
set -a
source /opt/typesafe/backend/.env
set +a

# Start Celery worker
exec /opt/typesafe/backend/venv/bin/celery -A app.agents.worker worker --loglevel=info --concurrency=4
```

Make executable:
```bash
sudo chmod +x /opt/typesafe/backend/start_celery.sh
sudo chown typesafe:typesafe /opt/typesafe/backend/start_celery.sh
```

Update config to use wrapper:
```ini
[program:typesafe-celery-worker]
command=/opt/typesafe/backend/start_celery.sh
```

### 3. Install Configuration Files

```bash
# Copy config files
sudo cp typesafe-celery.conf /etc/supervisor/conf.d/
sudo cp typesafe-flower.conf /etc/supervisor/conf.d/

# Set permissions
sudo chmod 644 /etc/supervisor/conf.d/typesafe-*.conf
```

### 4. Load and Start

```bash
# Reload Supervisor configuration
sudo supervisorctl reread

# Add new programs
sudo supervisorctl update

# Start services
sudo supervisorctl start typesafe-celery-worker
sudo supervisorctl start typesafe-flower

# Check status
sudo supervisorctl status
```

## Management

### Basic Commands

```bash
# View all programs
sudo supervisorctl status

# Start a program
sudo supervisorctl start typesafe-celery-worker

# Stop a program
sudo supervisorctl stop typesafe-celery-worker

# Restart a program
sudo supervisorctl restart typesafe-celery-worker

# Stop all programs
sudo supervisorctl stop all

# Start all programs
sudo supervisorctl start all
```

### View Logs

```bash
# Tail logs in real-time
sudo supervisorctl tail -f typesafe-celery-worker

# View last 1000 lines
sudo supervisorctl tail -1000 typesafe-celery-worker

# View error logs
sudo supervisorctl tail -f typesafe-celery-worker stderr

# View log files directly
sudo tail -f /var/log/typesafe/celery-worker.log
sudo tail -f /var/log/typesafe/celery-worker-error.log
```

### Update Configuration

```bash
# Edit configuration
sudo nano /etc/supervisor/conf.d/typesafe-celery.conf

# Reload configuration
sudo supervisorctl reread
sudo supervisorctl update

# Restart affected programs
sudo supervisorctl restart typesafe-celery-worker
```

## Advanced Configuration

### Multiple Worker Instances

To run multiple worker processes:

**Edit config file:**
```ini
[program:typesafe-celery-worker]
numprocs=4
process_name=%(program_name)s-%(process_num)s
command=/opt/typesafe/backend/venv/bin/celery -A app.agents.worker worker --loglevel=info --concurrency=2 --hostname=worker-%(process_num)s@%(host_node_name)s
```

This will start 4 worker processes, each with 2 concurrent tasks.

### Process Groups

Create `/etc/supervisor/conf.d/typesafe-group.conf`:
```ini
[group:typesafe]
programs=typesafe-celery-worker,typesafe-flower
priority=999
```

Manage as group:
```bash
sudo supervisorctl start typesafe:*
sudo supervisorctl stop typesafe:*
sudo supervisorctl restart typesafe:*
```

### Auto-restart on Failure

Already configured in the config files:
```ini
autorestart=true
```

To restart only on unexpected exits:
```ini
autorestart=unexpected
exitcodes=0
```

### Resource Limits

Supervisor doesn't directly support resource limits. Use wrapper script:

Create `/opt/typesafe/backend/start_celery_limited.sh`:
```bash
#!/bin/bash
# Set resource limits
ulimit -n 65536  # Max open files
ulimit -u 4096   # Max processes

# Load environment
set -a
source /opt/typesafe/backend/.env
set +a

# Start Celery
exec /opt/typesafe/backend/venv/bin/celery -A app.agents.worker worker --loglevel=info --concurrency=4
```

## Monitoring

### Supervisor Web Interface

Edit `/etc/supervisor/supervisord.conf`:
```ini
[inet_http_server]
port = 127.0.0.1:9001
username = admin
password = changeme
```

Restart supervisor:
```bash
sudo systemctl restart supervisor
```

Access at: http://localhost:9001

**Note:** For security, only bind to localhost or use strong authentication.

### Health Checks

Create a monitoring script:

`/opt/typesafe/scripts/check_celery.sh`:
```bash
#!/bin/bash

# Check if worker is running
if ! supervisorctl status typesafe-celery-worker | grep -q RUNNING; then
    echo "ERROR: Celery worker not running"
    exit 1
fi

# Check API health
if ! curl -s http://localhost:8000/health/celery | grep -q healthy; then
    echo "ERROR: Celery health check failed"
    exit 1
fi

echo "OK: Celery is healthy"
exit 0
```

Add to crontab:
```bash
*/5 * * * * /opt/typesafe/scripts/check_celery.sh || /usr/bin/supervisorctl restart typesafe-celery-worker
```

### Log Rotation

Create `/etc/logrotate.d/typesafe`:
```
/var/log/typesafe/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    sharedscripts
    postrotate
        supervisorctl signal HUP typesafe-celery-worker > /dev/null 2>&1 || true
    endscript
}
```

## Troubleshooting

### Check Supervisor Status

```bash
# Check if supervisord is running
sudo systemctl status supervisor

# Check supervisor logs
sudo tail -f /var/log/supervisor/supervisord.log
```

### Program Won't Start

```bash
# Check status and error
sudo supervisorctl status typesafe-celery-worker
sudo supervisorctl tail typesafe-celery-worker stderr

# Try starting manually
sudo -u typesafe bash
cd /opt/typesafe/backend
source venv/bin/activate
celery -A app.agents.worker worker --loglevel=info
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R typesafe:typesafe /opt/typesafe
sudo chown -R typesafe:typesafe /var/log/typesafe

# Check log directory exists
sudo mkdir -p /var/log/typesafe
sudo chown typesafe:typesafe /var/log/typesafe
```

### Update Not Taking Effect

```bash
# Force reload
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl restart typesafe-celery-worker

# Or restart supervisor completely
sudo systemctl restart supervisor
```

## Upgrading

### Update Application Code

```bash
# Stop workers
sudo supervisorctl stop typesafe:*

# Update code
cd /path/to/source
git pull
sudo cp -r backend/* /opt/typesafe/backend/
sudo chown -R typesafe:typesafe /opt/typesafe/backend

# Update dependencies
sudo -u typesafe bash -c "cd /opt/typesafe/backend && venv/bin/pip install -r requirements.txt"

# Start workers
sudo supervisorctl start typesafe:*
```

### Zero-downtime Deployment

For zero-downtime updates:

1. Start new workers with new code
2. Stop old workers gracefully
3. Old workers finish current tasks before stopping

```bash
# Add new worker instances
sudo supervisorctl start typesafe-celery-worker-new-1
sudo supervisorctl start typesafe-celery-worker-new-2

# Wait for them to be ready (check logs)
sleep 10

# Stop old workers gracefully (they'll finish current tasks)
sudo supervisorctl stop typesafe-celery-worker-old-1
sudo supervisorctl stop typesafe-celery-worker-old-2
```

## Uninstall

```bash
# Stop all programs
sudo supervisorctl stop typesafe:*

# Remove configuration
sudo rm /etc/supervisor/conf.d/typesafe-*.conf

# Reload supervisor
sudo supervisorctl reread
sudo supervisorctl update

# Optional: Remove application
sudo rm -rf /opt/typesafe
sudo rm -rf /var/log/typesafe
sudo userdel typesafe
```

## Comparison with Systemd

| Feature | Supervisor | Systemd |
|---------|-----------|---------|
| Ease of setup | ⭐⭐⭐⭐⭐ Simple | ⭐⭐⭐ Moderate |
| Web UI | ✅ Built-in | ❌ No |
| Process groups | ✅ Yes | ⚠️ Via targets |
| Log management | ✅ Built-in | ⭐⭐⭐⭐ journald |
| Security | ⭐⭐⭐ Basic | ⭐⭐⭐⭐⭐ Advanced |
| Resource limits | ❌ No | ✅ Yes |
| Best for | Development, simple deploys | Production, enterprise |

**Recommendation:** 
- Use Supervisor for simpler deployments and development environments
- Use Systemd for production with advanced security and resource management needs

