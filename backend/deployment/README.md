# TypeSafe Celery Deployment Guide

This directory contains deployment configurations for TypeSafe's Celery + Redis infrastructure across different environments and platforms.

## Directory Structure

```
deployment/
├── systemd/              # Linux systemd service files
│   ├── typesafe-celery.service
│   ├── typesafe-flower.service
│   └── README.md
├── supervisor/           # Supervisor process manager configs
│   ├── typesafe-celery.conf
│   ├── typesafe-flower.conf
│   └── README.md
├── kubernetes/          # Kubernetes manifests
│   ├── namespace.yaml
│   ├── secrets.yaml.example
│   ├── redis-deployment.yaml
│   ├── celery-worker-deployment.yaml
│   ├── flower-deployment.yaml
│   └── README.md
└── README.md            # This file
```

## Deployment Options

Choose the deployment method that best fits your environment:

### 1. **Docker Compose** (Development & Small Deployments)

**Best for:** Local development, testing, small deployments

**Pros:**
- ✅ Simple setup
- ✅ All services in one config
- ✅ Great for development
- ✅ Easy to tear down and rebuild

**Cons:**
- ❌ Limited scaling
- ❌ Single-host only
- ❌ Manual updates

**Quick Start:**
```bash
cd backend/
docker-compose up -d
```

See: `../docker-compose.yml`

---

### 2. **Systemd** (Traditional Linux Servers)

**Best for:** Bare metal servers, VMs, traditional deployments

**Pros:**
- ✅ Native Linux integration
- ✅ Automatic restart on boot
- ✅ Advanced security options
- ✅ Resource limits
- ✅ Journald logging

**Cons:**
- ❌ Manual setup per server
- ❌ No built-in scaling
- ❌ Requires systemd (Linux only)

**Quick Start:**
```bash
cd deployment/systemd/
# Follow README.md
```

See: `systemd/README.md`

---

### 3. **Supervisor** (Cross-platform Process Manager)

**Best for:** Simple deployments, shared hosting, development

**Pros:**
- ✅ Easy to configure
- ✅ Web UI for monitoring
- ✅ Process groups
- ✅ Cross-platform (Linux, BSD)
- ✅ No root required

**Cons:**
- ❌ Less secure than systemd
- ❌ No resource limits
- ❌ Manual scaling

**Quick Start:**
```bash
cd deployment/supervisor/
# Follow README.md
```

See: `supervisor/README.md`

---

### 4. **Kubernetes** (Container Orchestration)

**Best for:** Cloud deployments, large scale, production

**Pros:**
- ✅ Auto-scaling (HPA)
- ✅ Self-healing
- ✅ Rolling updates
- ✅ Multi-host
- ✅ Cloud-native
- ✅ Advanced monitoring

**Cons:**
- ❌ Complex setup
- ❌ Requires K8s cluster
- ❌ Steep learning curve

**Quick Start:**
```bash
cd deployment/kubernetes/
# Follow README.md
```

See: `kubernetes/README.md`

---

## Comparison Matrix

| Feature | Docker Compose | Systemd | Supervisor | Kubernetes |
|---------|---------------|---------|-----------|-----------|
| **Ease of Setup** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Scaling** | ⭐ | ⭐ | ⭐ | ⭐⭐⭐⭐⭐ |
| **Auto-restart** | ✅ | ✅ | ✅ | ✅ |
| **Auto-scaling** | ❌ | ❌ | ❌ | ✅ |
| **Multi-host** | ❌ | ❌ | ❌ | ✅ |
| **Web UI** | ❌ | ❌ | ✅ | ✅ |
| **Resource Limits** | ✅ | ✅ | ❌ | ✅ |
| **Security** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Cost** | Free | Free | Free | $$$ |
| **Best for** | Dev | VMs | Simple | Cloud |

---

## General Prerequisites

All deployment methods require:

### 1. Application Setup

```bash
cd backend/

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Environment Variables

Create `.env` file:
```bash
# API Keys
GROQ_API_KEY=your_key
GEMINI_API_KEY=your_key
SUPABASE_URL=your_url
SUPABASE_KEY=your_key
BACKEND_API_KEY=your_key

# Redis & Celery
REDIS_URL=redis://localhost:6379
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1

# Environment
ENVIRONMENT=production
```

### 3. Redis

Install and start Redis:

**Docker:**
```bash
docker run -d -p 6379:6379 redis:7-alpine
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis

# CentOS/RHEL
sudo yum install redis
sudo systemctl start redis
```

**macOS:**
```bash
brew install redis
brew services start redis
```

---

## Deployment Decision Tree

```
Do you need auto-scaling?
├─ Yes → Use Kubernetes
└─ No
   │
   Do you need multi-host?
   ├─ Yes → Use Kubernetes
   └─ No
      │
      Are you using Linux with systemd?
      ├─ Yes
      │  │
      │  Do you need advanced security?
      │  ├─ Yes → Use Systemd
      │  └─ No → Use Systemd or Supervisor
      │
      └─ No
         │
         Is this for development?
         ├─ Yes → Use Docker Compose
         └─ No → Use Supervisor
```

---

## Migration Between Deployment Methods

### Docker Compose → Systemd

1. Build and test with Docker Compose
2. Export environment variables to systemd service
3. Install systemd service files
4. Migrate data (Redis)
5. Test systemd deployment
6. Switch traffic

### Systemd → Kubernetes

1. Build Docker image
2. Push to container registry
3. Create Kubernetes secrets
4. Deploy to K8s cluster
5. Verify pods are running
6. Migrate Redis data
7. Switch traffic

---

## Monitoring

All deployment methods support monitoring via:

### Flower UI
- **URL:** http://your-server:5555
- **Features:** Real-time task monitoring, worker stats, task history

### Health Checks
```bash
# Check Celery workers
curl http://your-server:8000/health/celery

# Check Redis
redis-cli ping

# Check API
curl http://your-server:8000/health
```

### Logs

**Docker Compose:**
```bash
docker-compose logs -f celery-worker
```

**Systemd:**
```bash
sudo journalctl -u typesafe-celery -f
```

**Supervisor:**
```bash
sudo supervisorctl tail -f typesafe-celery-worker
```

**Kubernetes:**
```bash
kubectl logs -n typesafe -l app=celery-worker -f
```

---

## Common Tasks

### Start Services

**Docker Compose:**
```bash
docker-compose up -d
```

**Systemd:**
```bash
sudo systemctl start typesafe-celery
```

**Supervisor:**
```bash
sudo supervisorctl start typesafe-celery-worker
```

**Kubernetes:**
```bash
kubectl apply -f kubernetes/
```

### Stop Services

**Docker Compose:**
```bash
docker-compose down
```

**Systemd:**
```bash
sudo systemctl stop typesafe-celery
```

**Supervisor:**
```bash
sudo supervisorctl stop typesafe-celery-worker
```

**Kubernetes:**
```bash
kubectl delete namespace typesafe
```

### View Logs

See Monitoring section above.

### Scale Workers

**Docker Compose:**
```bash
docker-compose up -d --scale celery-worker=5
```

**Systemd:**
Create multiple service instances (see systemd/README.md)

**Supervisor:**
Configure `numprocs` in config file

**Kubernetes:**
```bash
kubectl scale deployment celery-worker -n typesafe --replicas=5
```

---

## Security Best Practices

### All Deployments

1. **Never commit secrets to git**
   - Use `.env` files (add to `.gitignore`)
   - Use secrets management (Vault, AWS Secrets Manager)
   - Use environment-specific configs

2. **Use strong Redis authentication**
   ```conf
   # redis.conf
   requirepass your_strong_password
   ```

3. **Run as non-root user**
   - All configs use dedicated `typesafe` user

4. **Enable TLS for Redis** (production)
   ```conf
   # redis.conf
   tls-port 6380
   tls-cert-file /path/to/redis.crt
   tls-key-file /path/to/redis.key
   tls-ca-cert-file /path/to/ca.crt
   ```

5. **Restrict network access**
   - Use firewall rules
   - Bind Redis to localhost if possible
   - Use VPN for multi-host setups

### Systemd Specific

- Use `ProtectSystem=strict`
- Use `PrivateTmp=true`
- Use `NoNewPrivileges=true`
- Use systemd credentials for secrets

### Kubernetes Specific

- Use NetworkPolicies
- Use PodSecurityPolicies
- Use RBAC
- Use encrypted secrets (sealed-secrets)
- Enable audit logging

---

## Troubleshooting

### Workers Not Starting

1. Check Redis connectivity
2. Check environment variables
3. Check Python dependencies
4. Check file permissions
5. Review logs

### Tasks Not Processing

1. Verify workers are running
2. Check Redis connection
3. Verify task registration
4. Check for task exceptions
5. Review Flower UI

### High Memory Usage

1. Check `worker_max_tasks_per_child`
2. Reduce concurrency
3. Scale horizontally
4. Monitor with Flower

### Slow Task Processing

1. Increase worker concurrency
2. Add more workers
3. Optimize task code
4. Check Redis performance
5. Review task time limits

---

## Performance Tuning

### Worker Concurrency

**CPU-bound tasks:**
```
concurrency = CPU cores
```

**I/O-bound tasks:**
```
concurrency = 2-3x CPU cores
```

### Redis Memory

```conf
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
```

### Task Time Limits

Edit `app/agents/worker.py`:
```python
task_soft_time_limit=120,  # 2 minutes
task_time_limit=150,       # 2.5 minutes
```

---

## Getting Help

- **Documentation:** `../CELERY_DEPLOYMENT.md`
- **Tests:** `../tests/test_celery_*.py`
- **Load Test:** `../tests/load_test_celery.py`

---

**Last Updated:** 2025-01-18  
**Version:** 1.0  
**Maintainer:** TypeSafe Backend Team

