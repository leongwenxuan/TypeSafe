# Kubernetes Deployment for TypeSafe Celery

This directory contains Kubernetes manifests for deploying TypeSafe Celery workers, Redis, and Flower monitoring.

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Kubernetes Cluster                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────┐    ┌─────────────────┐           │
│  │  Redis   │◄───┤ Celery Workers  │           │
│  │  (1 pod) │    │    (3+ pods)    │           │
│  └────┬─────┘    └─────────────────┘           │
│       │                                         │
│       │          ┌─────────────────┐           │
│       └──────────┤     Flower      │           │
│                  │   (1 pod)       │           │
│                  └────────┬────────┘           │
│                           │                     │
│                     ┌─────▼──────┐             │
│                     │  Ingress   │             │
│                     └────────────┘             │
└─────────────────────────────────────────────────┘
```

## Prerequisites

1. **Kubernetes Cluster** (1.20+)
   - Minikube (local)
   - GKE, EKS, AKS (cloud)
   - Self-managed cluster

2. **kubectl** configured to access your cluster

3. **Container Registry**
   - Docker Hub
   - Google Container Registry (GCR)
   - Amazon ECR
   - GitHub Container Registry (GHCR)

4. **Ingress Controller** (optional, for Flower access)
   - nginx-ingress
   - traefik
   - Ambassador

## Quick Start

### 1. Build and Push Docker Image

```bash
cd /path/to/TypeSafe/backend

# Build image
docker build -t typesafe-backend:latest .

# Tag for registry
docker tag typesafe-backend:latest your-registry/typesafe-backend:latest

# Push to registry
docker push your-registry/typesafe-backend:latest
```

### 2. Create Namespace

```bash
kubectl apply -f namespace.yaml
```

### 3. Create Secrets

```bash
# Copy example file
cp secrets.yaml.example secrets.yaml

# Edit with your actual secrets
nano secrets.yaml

# Apply secrets
kubectl apply -f secrets.yaml

# Verify
kubectl get secrets -n typesafe
```

### 4. Deploy Redis

```bash
kubectl apply -f redis-deployment.yaml

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l app=redis -n typesafe --timeout=60s

# Verify
kubectl get pods -n typesafe -l app=redis
```

### 5. Deploy Celery Workers

```bash
# Update image name in celery-worker-deployment.yaml
nano celery-worker-deployment.yaml
# Change: image: typesafe-backend:latest
# To:     image: your-registry/typesafe-backend:latest

# Apply deployment
kubectl apply -f celery-worker-deployment.yaml

# Wait for workers to be ready
kubectl wait --for=condition=ready pod -l app=celery-worker -n typesafe --timeout=120s

# Verify
kubectl get pods -n typesafe -l app=celery-worker
```

### 6. Deploy Flower (Optional)

```bash
# Update image name in flower-deployment.yaml
nano flower-deployment.yaml

# Apply deployment
kubectl apply -f flower-deployment.yaml

# Verify
kubectl get pods -n typesafe -l app=flower
```

### 7. Access Flower

**Option A: Port Forward (Development)**
```bash
kubectl port-forward -n typesafe svc/flower 5555:5555
```
Access at: http://localhost:5555

**Option B: Ingress (Production)**
```bash
# Edit flower-deployment.yaml with your domain
nano flower-deployment.yaml

# Apply ingress
kubectl apply -f flower-deployment.yaml

# Check ingress
kubectl get ingress -n typesafe
```
Access at: http://flower.typesafe.example.com

## Verification

### Check All Resources

```bash
# View all resources
kubectl get all -n typesafe

# Expected output:
# - 1 Redis pod
# - 3+ Celery worker pods
# - 1 Flower pod (if deployed)
# - Services and deployments
```

### Check Pod Logs

```bash
# Redis logs
kubectl logs -n typesafe -l app=redis

# Celery worker logs
kubectl logs -n typesafe -l app=celery-worker --tail=50

# Follow logs
kubectl logs -n typesafe -l app=celery-worker -f

# Specific pod
kubectl logs -n typesafe <pod-name>
```

### Check Pod Status

```bash
# Get pod status
kubectl get pods -n typesafe

# Describe pod (for troubleshooting)
kubectl describe pod -n typesafe <pod-name>

# Check events
kubectl get events -n typesafe --sort-by='.lastTimestamp'
```

### Test Celery Workers

```bash
# Port-forward API service (if you have FastAPI deployed)
kubectl port-forward -n typesafe svc/api 8000:8000

# Test task enqueue
curl -X POST http://localhost:8000/tasks/enqueue \
  -H "Content-Type: application/json" \
  -d '{"data": {"test": "kubernetes"}}'

# Check task status
curl http://localhost:8000/tasks/status/<task-id>

# Check Celery health
curl http://localhost:8000/health/celery
```

## Scaling

### Manual Scaling

```bash
# Scale workers to 5 replicas
kubectl scale deployment celery-worker -n typesafe --replicas=5

# Verify
kubectl get pods -n typesafe -l app=celery-worker
```

### Auto-scaling (HPA)

The deployment includes a HorizontalPodAutoscaler:

```bash
# Check HPA status
kubectl get hpa -n typesafe

# Describe HPA
kubectl describe hpa celery-worker-hpa -n typesafe
```

HPA will automatically scale workers based on:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)
- Min replicas: 2
- Max replicas: 10

## Monitoring

### Resource Usage

```bash
# Check resource usage
kubectl top pods -n typesafe

# Check node usage
kubectl top nodes
```

### Flower Monitoring

Access Flower UI to monitor:
- Active tasks
- Task history
- Worker status
- Queue depth
- Success/failure rates

### Kubernetes Dashboard

```bash
# Install dashboard (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Get token
kubectl -n kubernetes-dashboard create token admin-user

# Start proxy
kubectl proxy

# Access dashboard
# http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## Maintenance

### Update Application

```bash
# Build and push new image
docker build -t your-registry/typesafe-backend:v1.1 .
docker push your-registry/typesafe-backend:v1.1

# Update deployment
kubectl set image deployment/celery-worker -n typesafe \
  celery-worker=your-registry/typesafe-backend:v1.1

# Check rollout status
kubectl rollout status deployment/celery-worker -n typesafe

# View rollout history
kubectl rollout history deployment/celery-worker -n typesafe
```

### Rollback Deployment

```bash
# Rollback to previous version
kubectl rollout undo deployment/celery-worker -n typesafe

# Rollback to specific revision
kubectl rollout undo deployment/celery-worker -n typesafe --to-revision=2
```

### Restart Workers

```bash
# Rolling restart
kubectl rollout restart deployment/celery-worker -n typesafe

# Delete specific pod (will be recreated)
kubectl delete pod -n typesafe <pod-name>
```

### Update Secrets

```bash
# Edit secrets
kubectl edit secret typesafe-secrets -n typesafe

# Or delete and recreate
kubectl delete secret typesafe-secrets -n typesafe
kubectl apply -f secrets.yaml

# Restart workers to pick up new secrets
kubectl rollout restart deployment/celery-worker -n typesafe
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n typesafe <pod-name>

# Common issues:
# 1. Image pull error - check image name and registry access
# 2. Secret not found - ensure secrets exist
# 3. Resource limits - check node resources

# Check events
kubectl get events -n typesafe --sort-by='.lastTimestamp'
```

### Redis Connection Issues

```bash
# Check Redis pod
kubectl get pod -n typesafe -l app=redis

# Test Redis connection
kubectl exec -n typesafe -it <redis-pod-name> -- redis-cli ping

# Check Redis logs
kubectl logs -n typesafe -l app=redis

# Check service
kubectl get svc -n typesafe redis
kubectl describe svc -n typesafe redis
```

### Worker Not Processing Tasks

```bash
# Check worker logs
kubectl logs -n typesafe -l app=celery-worker --tail=100

# Exec into worker pod
kubectl exec -n typesafe -it <worker-pod-name> -- bash

# Inside pod, test Celery
celery -A app.agents.worker inspect active
celery -A app.agents.worker inspect ping

# Check Redis connection
redis-cli -h redis ping
```

### High Memory Usage

```bash
# Check memory usage
kubectl top pods -n typesafe

# If workers using too much memory:
# 1. Check worker_max_tasks_per_child in worker.py
# 2. Reduce concurrency
# 3. Increase memory limits
# 4. Scale horizontally (more workers, less concurrency each)
```

### Debug Mode

```bash
# Run worker with debug logging
kubectl set env deployment/celery-worker -n typesafe CELERY_LOG_LEVEL=DEBUG

# Revert
kubectl set env deployment/celery-worker -n typesafe CELERY_LOG_LEVEL-
```

## Advanced Configuration

### Resource Requests and Limits

Edit deployments to tune resources:

```yaml
resources:
  requests:
    memory: "512Mi"   # Guaranteed
    cpu: "500m"
  limits:
    memory: "1Gi"     # Maximum
    cpu: "1000m"
```

### Persistent Storage for Redis

For production, use persistent storage:

```yaml
# redis-deployment.yaml already includes PVC
# Ensure your cluster has a StorageClass

# Check available storage classes
kubectl get storageclass

# Update redis-deployment.yaml if needed
storageClassName: gp2  # AWS
storageClassName: pd-standard  # GCP
storageClassName: managed-premium  # Azure
```

### Multiple Environments

Create separate namespaces:

```bash
# Development
kubectl create namespace typesafe-dev

# Staging
kubectl create namespace typesafe-staging

# Production
kubectl create namespace typesafe-prod

# Deploy to specific environment
kubectl apply -f . -n typesafe-dev
```

### Network Policies

Restrict traffic between pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: celery-worker-netpol
  namespace: typesafe
spec:
  podSelector:
    matchLabels:
      app: celery-worker
  policyTypes:
  - Ingress
  - Egress
  ingress: []  # No ingress allowed
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
```

## Production Checklist

- [ ] Container images pushed to private registry
- [ ] Secrets stored securely (not in git)
- [ ] Resource limits configured appropriately
- [ ] HPA enabled and tested
- [ ] Persistent storage configured for Redis
- [ ] Monitoring and alerting configured
- [ ] Ingress with TLS for Flower
- [ ] Network policies applied
- [ ] Backup strategy for Redis data
- [ ] Disaster recovery plan documented
- [ ] Log aggregation configured (e.g., ELK, Loki)
- [ ] Cost monitoring enabled

## Cleanup

```bash
# Delete all resources in namespace
kubectl delete namespace typesafe

# Or delete individually
kubectl delete -f flower-deployment.yaml
kubectl delete -f celery-worker-deployment.yaml
kubectl delete -f redis-deployment.yaml
kubectl delete -f secrets.yaml
kubectl delete -f namespace.yaml
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Celery on Kubernetes](https://docs.celeryproject.org/en/stable/userguide/deployment.html)
- [Redis on Kubernetes](https://redis.io/docs/getting-started/install-stack/kubernetes/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

**Last Updated:** 2025-01-18  
**Version:** 1.0  
**Maintainer:** TypeSafe Backend Team

