# Systemd Deployment for TypeSafe Celery

This directory contains systemd service files for deploying TypeSafe Celery workers and Flower monitoring on Linux systems.

## Installation

### 1. Prerequisites

```bash
# Create user
sudo useradd -r -s /bin/bash -d /opt/typesafe -m typesafe

# Create directories
sudo mkdir -p /opt/typesafe/backend
sudo mkdir -p /var/log/typesafe
sudo mkdir -p /var/run/typesafe

# Set permissions
sudo chown -R typesafe:typesafe /opt/typesafe
sudo chown -R typesafe:typesafe /var/log/typesafe
sudo chown -R typesafe:typesafe /var/run/typesafe
```

### 2. Deploy Application

```bash
# Copy application files
sudo cp -r /path/to/backend/* /opt/typesafe/backend/
sudo chown -R typesafe:typesafe /opt/typesafe/backend

# Create virtual environment as typesafe user
sudo -u typesafe bash -c "cd /opt/typesafe/backend && python3 -m venv venv"
sudo -u typesafe bash -c "cd /opt/typesafe/backend && venv/bin/pip install -r requirements.txt"
```

### 3. Configure Environment

Create `/opt/typesafe/backend/.env`:

```bash
# API Keys
GROQ_API_KEY=your_key
GEMINI_API_KEY=your_key
SUPABASE_URL=your_url
SUPABASE_KEY=your_key
BACKEND_API_KEY=your_key

# Redis
REDIS_URL=redis://localhost:6379
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1

# Environment
ENVIRONMENT=production
```

Secure the file:
```bash
sudo chmod 600 /opt/typesafe/backend/.env
sudo chown typesafe:typesafe /opt/typesafe/backend/.env
```

### 4. Install Service Files

```bash
# Copy service files
sudo cp typesafe-celery.service /etc/systemd/system/
sudo cp typesafe-flower.service /etc/systemd/system/

# Set permissions
sudo chmod 644 /etc/systemd/system/typesafe-celery.service
sudo chmod 644 /etc/systemd/system/typesafe-flower.service

# Reload systemd
sudo systemctl daemon-reload
```

### 5. Enable and Start Services

```bash
# Enable services to start on boot
sudo systemctl enable typesafe-celery
sudo systemctl enable typesafe-flower

# Start services
sudo systemctl start typesafe-celery
sudo systemctl start typesafe-flower

# Check status
sudo systemctl status typesafe-celery
sudo systemctl status typesafe-flower
```

## Management

### Start/Stop/Restart

```bash
# Start
sudo systemctl start typesafe-celery
sudo systemctl start typesafe-flower

# Stop
sudo systemctl stop typesafe-celery
sudo systemctl stop typesafe-flower

# Restart
sudo systemctl restart typesafe-celery
sudo systemctl restart typesafe-flower

# Reload configuration
sudo systemctl reload typesafe-celery
```

### View Logs

```bash
# View service logs
sudo journalctl -u typesafe-celery -f
sudo journalctl -u typesafe-flower -f

# View application logs
sudo tail -f /var/log/typesafe/celery-worker.log

# View logs from specific date
sudo journalctl -u typesafe-celery --since "2025-01-18 10:00:00"
```

### Health Checks

```bash
# Check service status
sudo systemctl is-active typesafe-celery
sudo systemctl is-active typesafe-flower

# Check if worker is running
ps aux | grep celery

# Check worker via API
curl http://localhost:8000/health/celery
```

## Troubleshooting

### Service fails to start

```bash
# Check status and errors
sudo systemctl status typesafe-celery
sudo journalctl -u typesafe-celery -n 50

# Check permissions
ls -la /var/log/typesafe
ls -la /var/run/typesafe

# Test command manually
sudo -u typesafe bash
cd /opt/typesafe/backend
source venv/bin/activate
celery -A app.agents.worker worker --loglevel=info
```

### Worker crashes frequently

```bash
# Check system resources
free -h
df -h

# Check Redis connection
redis-cli ping

# Increase restart delay
sudo systemctl edit typesafe-celery
# Add:
# [Service]
# RestartSec=30s
```

### Update service configuration

```bash
# Edit service file
sudo systemctl edit typesafe-celery

# Or edit directly
sudo nano /etc/systemd/system/typesafe-celery.service

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart typesafe-celery
```

## Monitoring

### Enable persistent logging

```bash
# Ensure journald persistence
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

### Log rotation

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
        systemctl reload typesafe-celery > /dev/null 2>&1 || true
    endscript
}
```

## Scaling

### Multiple workers

To run multiple worker instances:

```bash
# Copy service file
sudo cp /etc/systemd/system/typesafe-celery.service \
       /etc/systemd/system/typesafe-celery@.service

# Edit to use instance name
sudo nano /etc/systemd/system/typesafe-celery@.service
# Change hostname to: --hostname=worker-%i@%%h

# Start multiple instances
sudo systemctl start typesafe-celery@1
sudo systemctl start typesafe-celery@2
sudo systemctl start typesafe-celery@3
```

## Security

### Harden service

The service files include security hardening options:
- `NoNewPrivileges=true` - Prevents privilege escalation
- `PrivateTmp=true` - Isolated /tmp directory
- `ProtectSystem=strict` - Read-only filesystem
- `ProtectHome=true` - No access to home directories

### Use secrets management

Instead of `.env` file, use systemd credentials:

```bash
# Store secrets
sudo systemd-creds encrypt --name=groq-api-key - /etc/credstore/groq-api-key

# Update service file
[Service]
LoadCredential=groq-api-key:/etc/credstore/groq-api-key
Environment="GROQ_API_KEY=%d/groq-api-key"
```

## Uninstall

```bash
# Stop and disable services
sudo systemctl stop typesafe-celery typesafe-flower
sudo systemctl disable typesafe-celery typesafe-flower

# Remove service files
sudo rm /etc/systemd/system/typesafe-celery.service
sudo rm /etc/systemd/system/typesafe-flower.service

# Reload systemd
sudo systemctl daemon-reload

# Optional: Remove application files
sudo rm -rf /opt/typesafe
sudo rm -rf /var/log/typesafe
sudo rm -rf /var/run/typesafe
sudo userdel typesafe
```

