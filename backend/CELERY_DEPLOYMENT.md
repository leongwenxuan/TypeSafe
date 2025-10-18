# Celery + Redis Deployment Guide

This guide covers deploying the Celery task queue infrastructure for TypeSafe's MCP agent orchestration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Testing](#testing)
4. [Docker Deployment](#docker-deployment)
5. [Production Deployment](#production-deployment)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software
- Python 3.11+
- Redis 7.x
- Docker & Docker Compose (for containerized deployment)

### Environment Variables
Create a `.env` file in the `backend/` directory:

```bash
# Required for existing API
GROQ_API_KEY=your_groq_key
GEMINI_API_KEY=your_gemini_key
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
BACKEND_API_KEY=your_backend_key

# Redis & Celery Configuration
REDIS_URL=redis://localhost:6379
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1

# Optional
ENVIRONMENT=development
```

---

## Local Development Setup

### Step 1: Install Dependencies

```bash
cd backend/

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Step 2: Start Redis

**Option A: Using Docker**
```bash
docker-compose up redis -d
```

**Option B: Using Homebrew (macOS)**
```bash
brew install redis
brew services start redis
```

**Option C: Using apt (Linux)**
```bash
sudo apt-get update
sudo apt-get install redis-server
sudo systemctl start redis
```

**Verify Redis is running:**
```bash
redis-cli ping
# Should return: PONG
```

### Step 3: Start Celery Worker

```bash
# From backend/ directory
celery -A app.agents.worker worker --loglevel=info
```

**Expected output:**
```
[2025-01-18 10:30:00,000: INFO/MainProcess] Connected to redis://localhost:6379/0
[2025-01-18 10:30:00,100: INFO/MainProcess] mingle: searching for neighbors
[2025-01-18 10:30:01,200: INFO/MainProcess] mingle: all alone
[2025-01-18 10:30:01,300: INFO/MainProcess] celery@hostname ready.
```

### Step 4: Start FastAPI Server

**In a new terminal:**
```bash
cd backend/
source venv/bin/activate
uvicorn app.main:app --reload --port 8000
```

### Step 5: Start Flower (Optional Monitoring UI)

**In a new terminal:**
```bash
cd backend/
source venv/bin/activate
celery -A app.agents.worker flower --port=5555
```

Access Flower at: http://localhost:5555

---

## Testing

### Unit Tests

```bash
# Run all unit tests
pytest tests/test_celery_infrastructure.py -v

# Run specific test class
pytest tests/test_celery_infrastructure.py::TestCeleryConfiguration -v
```

### Integration Tests

**Prerequisites:**
- Redis must be running
- At least one Celery worker must be active

```bash
# Run integration tests
pytest tests/test_celery_integration.py -v -m integration

# Skip integration tests
pytest -v -m "not integration"
```

### Load Testing

```bash
# Run load test with 100 tasks
python tests/load_test_celery.py --tasks 100 --concurrent 10

# Custom parameters
python tests/load_test_celery.py --tasks 500 --concurrent 20
```

**Success criteria:**
- ≥95% task completion rate
- No worker crashes
- Average task duration < 5 seconds

### Manual API Testing

**1. Enqueue a task:**
```bash
curl -X POST http://localhost:8000/tasks/enqueue \
  -H "Content-Type: application/json" \
  -d '{"data": {"key": "value"}}'
```

**Response:**
```json
{
  "task_id": "abc-123-def-456",
  "status": "pending",
  "message": "Task enqueued successfully"
}
```

**2. Check task status:**
```bash
curl http://localhost:8000/tasks/status/abc-123-def-456
```

**Response:**
```json
{
  "task_id": "abc-123-def-456",
  "status": "SUCCESS",
  "result": {
    "task_id": "abc-123-def-456",
    "status": "completed",
    "result": "Success",
    "attempts": 1
  },
  "error": null,
  "meta": null
}
```

**3. Check Celery health:**
```bash
curl http://localhost:8000/health/celery
```

**Response:**
```json
{
  "status": "healthy",
  "workers": ["celery@hostname"],
  "active_tasks": 3
}
```

---

## Docker Deployment

### Build and Run with Docker Compose

```bash
cd backend/

# Build images
docker-compose build

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f celery-worker
docker-compose logs -f api

# Stop all services
docker-compose down
```

### Services Overview

| Service | Port | Description |
|---------|------|-------------|
| redis | 6379 | Message broker and result backend |
| celery-worker | - | Task processor (background) |
| flower | 5555 | Celery monitoring UI |
| api | 8000 | FastAPI REST API |

### Scaling Workers

```bash
# Scale to 4 worker instances
docker-compose up -d --scale celery-worker=4

# View all workers
docker-compose ps
```

### Health Checks

```bash
# Check Redis
docker-compose exec redis redis-cli ping

# Check Celery workers
curl http://localhost:8000/health/celery

# Check API
curl http://localhost:8000/health
```

---

## Production Deployment

### Architecture Overview

```
Internet → Load Balancer → FastAPI Servers (multiple)
                              ↓
                         Redis Cluster
                              ↓
                    Celery Workers (multiple)
```

### Option 1: Systemd (Linux)

**1. Create systemd service for Celery worker:**

File: `/etc/systemd/system/typesafe-celery.service`

```ini
[Unit]
Description=TypeSafe Celery Worker
After=network.target redis.service

[Service]
Type=forking
User=typesafe
Group=typesafe
WorkingDirectory=/opt/typesafe/backend
Environment="PATH=/opt/typesafe/backend/venv/bin"
Environment="CELERY_BROKER_URL=redis://localhost:6379/0"
Environment="CELERY_RESULT_BACKEND=redis://localhost:6379/1"

ExecStart=/opt/typesafe/backend/venv/bin/celery \
  -A app.agents.worker worker \
  --loglevel=info \
  --concurrency=4 \
  --detach \
  --pidfile=/var/run/typesafe-celery.pid \
  --logfile=/var/log/typesafe/celery-worker.log

ExecStop=/opt/typesafe/backend/venv/bin/celery \
  -A app.agents.worker control shutdown

Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

**2. Enable and start service:**

```bash
# Create log directory
sudo mkdir -p /var/log/typesafe
sudo chown typesafe:typesafe /var/log/typesafe

# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable typesafe-celery

# Start service
sudo systemctl start typesafe-celery

# Check status
sudo systemctl status typesafe-celery

# View logs
sudo journalctl -u typesafe-celery -f
```

### Option 2: Supervisor

**1. Create supervisor config:**

File: `/etc/supervisor/conf.d/typesafe-celery.conf`

```ini
[program:typesafe-celery-worker]
command=/opt/typesafe/backend/venv/bin/celery -A app.agents.worker worker --loglevel=info --concurrency=4
directory=/opt/typesafe/backend
user=typesafe
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
redirect_stderr=true
stdout_logfile=/var/log/typesafe/celery-worker.log
stderr_logfile=/var/log/typesafe/celery-worker-error.log
environment=CELERY_BROKER_URL="redis://localhost:6379/0",CELERY_RESULT_BACKEND="redis://localhost:6379/1"
```

**2. Start with supervisor:**

```bash
# Update supervisor
sudo supervisorctl reread
sudo supervisorctl update

# Start worker
sudo supervisorctl start typesafe-celery-worker

# Check status
sudo supervisorctl status typesafe-celery-worker

# View logs
sudo tail -f /var/log/typesafe/celery-worker.log
```

### Option 3: Kubernetes

**1. Redis Deployment:**

File: `k8s/redis-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
```

**2. Celery Worker Deployment:**

File: `k8s/celery-worker-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: celery-worker
spec:
  replicas: 3
  selector:
    matchLabels:
      app: celery-worker
  template:
    metadata:
      labels:
        app: celery-worker
    spec:
      containers:
      - name: celery-worker
        image: typesafe-backend:latest
        command: ["celery", "-A", "app.agents.worker", "worker", "--loglevel=info", "--concurrency=4"]
        env:
        - name: CELERY_BROKER_URL
          value: "redis://redis:6379/0"
        - name: CELERY_RESULT_BACKEND
          value: "redis://redis:6379/1"
        - name: GROQ_API_KEY
          valueFrom:
            secretKeyRef:
              name: typesafe-secrets
              key: groq-api-key
        resources:
          limits:
            memory: "1Gi"
            cpu: "1000m"
          requests:
            memory: "512Mi"
            cpu: "500m"
```

**Deploy:**
```bash
kubectl apply -f k8s/redis-deployment.yaml
kubectl apply -f k8s/celery-worker-deployment.yaml
kubectl get pods
```

### Production Configuration Checklist

- [ ] Redis configured with persistence (AOF/RDB)
- [ ] Redis maxmemory policy set (e.g., `allkeys-lru`)
- [ ] Redis password authentication enabled
- [ ] Celery workers run as non-root user
- [ ] Worker concurrency tuned based on CPU cores
- [ ] Task time limits configured (soft: 55s, hard: 60s)
- [ ] Result expiration set (1 hour default)
- [ ] Automatic worker restart after N tasks (1000 default)
- [ ] Monitoring and alerting configured
- [ ] Log rotation enabled
- [ ] Environment variables secured (use secrets management)

### Redis Production Settings

**File: `/etc/redis/redis.conf` (excerpt)**

```conf
# Security
requirepass your_strong_password_here
bind 0.0.0.0
protected-mode yes

# Persistence
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000

# Memory Management
maxmemory 2gb
maxmemory-policy allkeys-lru

# Replication (for HA)
# slaveof master-host 6379
# masterauth master-password
```

---

## Monitoring & Maintenance

### Flower Monitoring UI

Access at: http://your-server:5555

**Features:**
- Real-time task monitoring
- Worker status and statistics
- Task history and results
- Rate limiting configuration
- Worker pool management

**Production setup:**
```bash
celery -A app.agents.worker flower \
  --port=5555 \
  --basic_auth=admin:secure_password \
  --url_prefix=flower
```

### Key Metrics to Monitor

#### Application Metrics

```python
# Custom metrics endpoint (add to main.py)
@app.get("/metrics/celery")
async def celery_metrics():
    inspect = celery_app.control.inspect()
    
    stats = inspect.stats()
    active = inspect.active()
    scheduled = inspect.scheduled()
    
    return {
        "workers": {
            "count": len(stats) if stats else 0,
            "names": list(stats.keys()) if stats else []
        },
        "tasks": {
            "active": sum(len(tasks) for tasks in active.values()) if active else 0,
            "scheduled": sum(len(tasks) for tasks in scheduled.values()) if scheduled else 0
        }
    }
```

#### Redis Metrics (CLI)

```bash
# Memory usage
redis-cli INFO memory

# Connection count
redis-cli INFO clients

# Operations per second
redis-cli INFO stats

# Key count per database
redis-cli INFO keyspace
```

### Log Aggregation

**Structured logging with JSON:**

Add to `app/agents/worker.py`:

```python
import json
import logging

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "service": "celery_worker",
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno
        }
        return json.dumps(log_data)

# Apply formatter
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger.addHandler(handler)
```

### Health Checks

**Kubernetes liveness probe:**
```yaml
livenessProbe:
  exec:
    command:
    - python
    - -c
    - "import celery; app = celery.Celery(); app.config_from_object('app.agents.worker'); inspect = app.control.inspect(); assert inspect.stats()"
  initialDelaySeconds: 30
  periodSeconds: 60
```

### Maintenance Tasks

**Weekly:**
- Review error logs for recurring failures
- Check Redis memory usage and eviction policy
- Review Flower dashboard for anomalies

**Monthly:**
- Analyze task duration trends
- Optimize worker concurrency
- Clean up expired results (automatic with `result_expires`)

**Quarterly:**
- Update dependencies (Redis, Celery, Python packages)
- Review and update time limits based on actual task durations
- Capacity planning based on growth trends

---

## Troubleshooting

### Issue: No workers active

**Symptoms:**
- `/health/celery` returns 503
- Tasks stay in PENDING state

**Solutions:**
```bash
# Check if Redis is running
redis-cli ping

# Check worker process
ps aux | grep celery

# Start worker manually
celery -A app.agents.worker worker --loglevel=info

# Check systemd status
sudo systemctl status typesafe-celery
```

### Issue: Tasks timeout

**Symptoms:**
- Tasks fail with "SoftTimeLimitExceeded"
- Workers become unresponsive

**Solutions:**
1. Increase time limits in `worker.py`:
   ```python
   task_soft_time_limit=120,  # Increase to 2 minutes
   task_time_limit=150,
   ```

2. Optimize task logic to complete faster
3. Break large tasks into smaller subtasks

### Issue: Redis connection errors

**Symptoms:**
- "ConnectionRefusedError: [Errno 111] Connection refused"
- Workers fail to start

**Solutions:**
```bash
# Check Redis is running
sudo systemctl status redis

# Check Redis port
netstat -tulpn | grep 6379

# Test connection
redis-cli -h localhost -p 6379 ping

# Check firewall
sudo ufw allow 6379
```

### Issue: Memory leaks

**Symptoms:**
- Worker memory grows over time
- Server runs out of memory

**Solutions:**
1. Enable worker restart after N tasks (already configured):
   ```python
   worker_max_tasks_per_child=1000
   ```

2. Monitor with:
   ```bash
   # Check worker memory
   ps aux | grep celery
   
   # Check Redis memory
   redis-cli INFO memory
   ```

3. Set Redis maxmemory and eviction policy

### Issue: Task result not found

**Symptoms:**
- `/tasks/status/{id}` returns PENDING for completed task
- Results disappear after 1 hour

**Expected behavior:**
- Results expire after `result_expires` (default: 3600s)
- This is intentional to prevent Redis memory bloat

**Solutions:**
- Store important results in PostgreSQL/Supabase before expiration
- Increase `result_expires` if needed
- Implement result persistence in task completion handler

### Issue: Worker crashes on startup

**Symptoms:**
- Worker exits immediately after starting
- Import errors in logs

**Solutions:**
```bash
# Check Python path
cd backend/
python -c "from app.agents.worker import celery_app; print('OK')"

# Check dependencies
pip install -r requirements.txt

# Check environment variables
printenv | grep CELERY
```

### Debug Mode

**Enable verbose logging:**
```bash
celery -A app.agents.worker worker --loglevel=debug
```

**Enable task events:**
```bash
celery -A app.agents.worker worker --loglevel=info -E
```

---

## Performance Tuning

### Worker Concurrency

**CPU-bound tasks:**
```bash
# Set concurrency = number of CPU cores
celery -A app.agents.worker worker --concurrency=4
```

**I/O-bound tasks:**
```bash
# Set concurrency = 2-3x CPU cores
celery -A app.agents.worker worker --concurrency=12
```

### Redis Optimization

```conf
# Increase max connections
maxclients 10000

# Tune save frequency based on durability needs
save 900 1
save 300 10

# Disable RDB if using AOF
save ""
appendonly yes
```

### Task Rate Limiting

Add to `worker.py`:
```python
celery_app.conf.task_default_rate_limit = '100/m'  # 100 tasks per minute
```

---

## Additional Resources

- [Celery Documentation](https://docs.celeryproject.org/)
- [Redis Documentation](https://redis.io/documentation)
- [Flower Documentation](https://flower.readthedocs.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

---

**Last Updated:** 2025-01-18  
**Version:** 1.0  
**Maintainer:** TypeSafe Backend Team

