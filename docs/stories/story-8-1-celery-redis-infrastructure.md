# Story 8.1: Celery & Redis Infrastructure Setup

**Story ID:** 8.1  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P0 (Foundation)  
**Effort:** 16 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As a** backend developer,  
**I want** Celery task queue and Redis message broker configured,  
**so that** I can run long-running agent tasks asynchronously.

---

## Description

This story establishes the foundational infrastructure for asynchronous task processing in TypeSafe. We need a robust task queue system to handle complex, multi-step MCP agent operations that may take 10-30 seconds to complete. Celery + Redis provides the battle-tested, Python-native solution for this requirement.

**Why This Matters:**
- Agent scans are too slow for synchronous HTTP requests (30s+ timeout issues)
- Need progress tracking and updates during long-running operations
- Enables horizontal scaling of worker processes
- Provides automatic retry logic for failed tasks

---

## Acceptance Criteria

### Infrastructure Setup
- [ ] 1. Redis server running locally (port 6379) and configured for production
- [ ] 2. Redis accessible via `redis://localhost:6379/0` (broker) and `redis://localhost:6379/1` (backend)
- [ ] 3. Celery installed with Redis as broker and result backend
- [ ] 4. Celery worker can be started: `celery -A app.agents.worker worker --loglevel=info`
- [ ] 5. Worker process remains stable under load (no crashes after 100+ tasks)

### Task Management
- [ ] 6. Tasks can be enqueued from FastAPI endpoints using `.delay()` or `.apply_async()`
- [ ] 7. Task status tracking works: PENDING → STARTED → SUCCESS/FAILURE
- [ ] 8. Task results stored in Redis with configurable TTL (default: 1 hour)
- [ ] 9. Task IDs are UUID format for security and uniqueness

### Reliability & Error Handling
- [ ] 10. Automatic retry logic: 3 retries with exponential backoff (2s, 4s, 8s)
- [ ] 11. Failed tasks log errors with full stack traces
- [ ] 12. Task timeout handling: Tasks exceeding 60 seconds are terminated
- [ ] 13. Graceful worker shutdown on SIGTERM (finish current tasks)

### Monitoring & Health
- [ ] 14. Health check endpoint: `GET /health/celery` returns worker status
- [ ] 15. Celery monitoring with Flower (optional): `celery -A app.agents.worker flower --port=5555`
- [ ] 16. Logging integration: All task events logged to stdout (JSON format)
- [ ] 17. Metrics tracking: Task count, success/failure rates, average duration

### Testing
- [ ] 18. Unit tests verify task enqueue/dequeue flow
- [ ] 19. Integration test: End-to-end task execution with result retrieval
- [ ] 20. Load test: 100 concurrent tasks complete successfully
- [ ] 21. Failure test: Worker restart doesn't lose queued tasks

### Deployment
- [ ] 22. Docker Compose config includes Redis and Celery worker services
- [ ] 23. Environment variables: `REDIS_URL`, `CELERY_BROKER_URL`, `CELERY_RESULT_BACKEND`
- [ ] 24. Production deployment guide documented
- [ ] 25. Supervisor/systemd config for worker auto-restart

---

## Technical Implementation

### File Structure
```
backend/
├── app/
│   ├── agents/
│   │   ├── __init__.py
│   │   ├── worker.py          # Celery app configuration
│   │   └── tasks/
│   │       ├── __init__.py
│   │       └── example_task.py
│   └── main.py                # FastAPI app
├── docker-compose.yml         # Add Redis + Celery worker
└── requirements.txt           # Add Celery dependencies
```

### Core Implementation

**1. Celery Worker Configuration (`app/agents/worker.py`):**

```python
"""Celery worker configuration for TypeSafe MCP agent."""

import os
from celery import Celery
from celery.signals import task_prerun, task_postrun, task_failure
import logging

# Configure logging
logger = logging.getLogger(__name__)

# Initialize Celery app
celery_app = Celery(
    'typesafe_agent',
    broker=os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/0'),
    backend=os.getenv('CELERY_RESULT_BACKEND', 'redis://localhost:6379/1'),
    include=['app.agents.tasks']
)

# Celery configuration
celery_app.conf.update(
    # Serialization
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    
    # Timezone
    timezone='UTC',
    enable_utc=True,
    
    # Task execution
    task_track_started=True,
    task_time_limit=60,  # 60 second hard limit
    task_soft_time_limit=55,  # 55 second soft limit (raises exception)
    task_acks_late=True,  # Acknowledge after task completes (prevents loss on crash)
    worker_prefetch_multiplier=1,  # Disable prefetching for better task distribution
    
    # Result backend
    result_expires=3600,  # Results expire after 1 hour
    result_extended=True,  # Store additional metadata
    
    # Retry configuration
    task_default_max_retries=3,
    task_default_retry_delay=2,  # 2 seconds base delay
    
    # Worker configuration
    worker_max_tasks_per_child=1000,  # Restart worker after 1000 tasks (prevent memory leaks)
    worker_disable_rate_limits=False,
    
    # Broker configuration
    broker_connection_retry_on_startup=True,
    broker_connection_retry=True,
    broker_connection_max_retries=10,
)

# Signal handlers for logging
@task_prerun.connect
def task_prerun_handler(sender=None, task_id=None, task=None, args=None, kwargs=None, **extra):
    """Log when task starts."""
    logger.info(f"Task starting: {task.name} [id={task_id}]")

@task_postrun.connect
def task_postrun_handler(sender=None, task_id=None, task=None, retval=None, state=None, **extra):
    """Log when task completes."""
    logger.info(f"Task completed: {task.name} [id={task_id}] [state={state}]")

@task_failure.connect
def task_failure_handler(sender=None, task_id=None, exception=None, traceback=None, **extra):
    """Log when task fails."""
    logger.error(f"Task failed: {sender.name} [id={task_id}] [error={str(exception)}]", 
                 exc_info=True)

# Auto-discover tasks
celery_app.autodiscover_tasks(['app.agents.tasks'])
```

**2. Example Task (`app/agents/tasks/example_task.py`):**

```python
"""Example Celery task for testing infrastructure."""

from app.agents.worker import celery_app
from celery import Task
import time
import random

@celery_app.task(bind=True, max_retries=3, default_retry_delay=2)
def example_agent_task(self: Task, task_id: str, data: dict) -> dict:
    """
    Example task demonstrating Celery infrastructure.
    
    Args:
        task_id: Unique identifier for this task
        data: Input data dictionary
    
    Returns:
        dict: Result dictionary
    
    Raises:
        self.retry: If task needs to be retried
    """
    try:
        # Simulate processing
        print(f"Processing task {task_id} with data: {data}")
        time.sleep(2)  # Simulate work
        
        # Simulate random failure (10% chance)
        if random.random() < 0.1:
            raise ValueError("Simulated random failure")
        
        return {
            "task_id": task_id,
            "status": "completed",
            "result": "Success",
            "attempts": self.request.retries + 1
        }
    
    except Exception as exc:
        # Retry with exponential backoff
        print(f"Task {task_id} failed (attempt {self.request.retries + 1}/3): {exc}")
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)
```

**3. FastAPI Integration (`app/main.py`):**

```python
"""FastAPI endpoints for task management."""

from fastapi import APIRouter, HTTPException
from app.agents.worker import celery_app
from app.agents.tasks.example_task import example_agent_task
import uuid

router = APIRouter(prefix="/tasks", tags=["tasks"])

@router.post("/enqueue")
async def enqueue_task(data: dict):
    """Enqueue a new agent task."""
    task_id = str(uuid.uuid4())
    
    # Enqueue task
    result = example_agent_task.apply_async(
        args=[task_id, data],
        task_id=task_id
    )
    
    return {
        "task_id": result.id,
        "status": "pending",
        "message": "Task enqueued successfully"
    }

@router.get("/status/{task_id}")
async def get_task_status(task_id: str):
    """Get status of a task."""
    result = celery_app.AsyncResult(task_id)
    
    response = {
        "task_id": task_id,
        "status": result.state,
        "result": None,
        "error": None
    }
    
    if result.successful():
        response["result"] = result.result
    elif result.failed():
        response["error"] = str(result.info)
    
    return response

@router.get("/health/celery")
async def celery_health_check():
    """Check Celery worker health."""
    try:
        # Check if workers are active
        inspect = celery_app.control.inspect()
        active_workers = inspect.active()
        
        if not active_workers:
            raise HTTPException(status_code=503, detail="No active Celery workers")
        
        return {
            "status": "healthy",
            "workers": list(active_workers.keys()),
            "active_tasks": sum(len(tasks) for tasks in active_workers.values())
        }
    
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Celery health check failed: {str(e)}")
```

**4. Docker Compose Configuration (`docker-compose.yml`):**

```yaml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: typesafe-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
    restart: unless-stopped

  celery-worker:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: typesafe-celery-worker
    command: celery -A app.agents.worker worker --loglevel=info --concurrency=4
    environment:
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/1
      - PYTHONUNBUFFERED=1
    depends_on:
      redis:
        condition: service_healthy
    volumes:
      - ./backend:/app
    restart: unless-stopped

  flower:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: typesafe-flower
    command: celery -A app.agents.worker flower --port=5555
    ports:
      - "5555:5555"
    environment:
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/1
    depends_on:
      - redis
      - celery-worker
    restart: unless-stopped

volumes:
  redis-data:
```

**5. Dependencies (`requirements.txt`):**

```txt
# Existing dependencies...

# Celery & Redis
celery[redis]==5.3.4
redis==5.0.1
flower==2.0.1  # Optional monitoring UI
```

---

## Testing Strategy

### Unit Tests (`tests/test_celery_infrastructure.py`)

```python
"""Unit tests for Celery infrastructure."""

import pytest
from app.agents.worker import celery_app
from app.agents.tasks.example_task import example_agent_task
import time

@pytest.fixture
def celery_config():
    """Configure Celery for testing."""
    return {
        'broker_url': 'memory://',
        'result_backend': 'cache+memory://',
        'task_always_eager': True,  # Execute tasks synchronously in tests
        'task_eager_propagates': True
    }

def test_task_enqueue():
    """Test task can be enqueued."""
    result = example_agent_task.delay("test-123", {"key": "value"})
    assert result.id is not None
    assert result.state in ['PENDING', 'SUCCESS']

def test_task_success():
    """Test successful task execution."""
    result = example_agent_task.apply_async(
        args=["test-456", {"key": "value"}]
    )
    result.get(timeout=5)  # Wait for completion
    assert result.successful()
    assert result.result['status'] == 'completed'

def test_task_retry_on_failure():
    """Test task retries on failure."""
    # This would need mock to force failure
    # Implementation depends on test setup
    pass

def test_worker_health():
    """Test worker health check."""
    inspect = celery_app.control.inspect()
    stats = inspect.stats()
    # In test environment, may not have active workers
    # This is more of an integration test
    pass
```

### Integration Tests

```python
"""Integration tests for Celery with real Redis."""

import pytest
import time
from app.agents.worker import celery_app
from app.agents.tasks.example_task import example_agent_task

@pytest.mark.integration
def test_real_task_execution():
    """Test task execution with real Redis backend."""
    task_id = "integration-test-123"
    result = example_agent_task.apply_async(
        args=[task_id, {"test": "data"}],
        task_id=task_id
    )
    
    # Wait for task to complete
    max_wait = 10
    elapsed = 0
    while not result.ready() and elapsed < max_wait:
        time.sleep(0.5)
        elapsed += 0.5
    
    assert result.ready()
    assert result.successful()
    assert result.result['task_id'] == task_id

@pytest.mark.integration
def test_task_result_retrieval():
    """Test retrieving task results from Redis."""
    result = example_agent_task.delay("test-789", {"key": "value"})
    task_id = result.id
    
    # Wait for completion
    result.get(timeout=10)
    
    # Retrieve result using task_id
    retrieved = celery_app.AsyncResult(task_id)
    assert retrieved.successful()
    assert retrieved.result['status'] == 'completed'
```

### Load Testing

```python
"""Load test for Celery infrastructure."""

import concurrent.futures
from app.agents.tasks.example_task import example_agent_task
import time

def run_load_test(num_tasks=100):
    """Run load test with multiple concurrent tasks."""
    start_time = time.time()
    
    # Enqueue tasks
    results = []
    for i in range(num_tasks):
        result = example_agent_task.delay(f"load-test-{i}", {"index": i})
        results.append(result)
    
    # Wait for all to complete
    completed = 0
    failed = 0
    for result in results:
        try:
            result.get(timeout=30)
            completed += 1
        except Exception:
            failed += 1
    
    elapsed = time.time() - start_time
    
    print(f"Load Test Results:")
    print(f"  Total tasks: {num_tasks}")
    print(f"  Completed: {completed}")
    print(f"  Failed: {failed}")
    print(f"  Duration: {elapsed:.2f}s")
    print(f"  Tasks/sec: {num_tasks/elapsed:.2f}")
    
    assert failed < num_tasks * 0.05  # Less than 5% failure rate

if __name__ == "__main__":
    run_load_test(100)
```

---

## Deployment Guide

### Local Development

```bash
# 1. Start Redis
docker-compose up redis -d

# 2. Start Celery worker
celery -A app.agents.worker worker --loglevel=info

# 3. (Optional) Start Flower monitoring
celery -A app.agents.worker flower --port=5555
# Open http://localhost:5555

# 4. Start FastAPI
uvicorn app.main:app --reload
```

### Production Deployment

**Using Supervisor (Linux):**

```ini
; /etc/supervisor/conf.d/typesafe-celery.conf

[program:typesafe-celery-worker]
command=/path/to/venv/bin/celery -A app.agents.worker worker --loglevel=info --concurrency=4
directory=/path/to/backend
user=typesafe
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
redirect_stderr=true
stdout_logfile=/var/log/typesafe/celery-worker.log
stderr_logfile=/var/log/typesafe/celery-worker-error.log
```

**Using systemd:**

```ini
# /etc/systemd/system/typesafe-celery.service

[Unit]
Description=TypeSafe Celery Worker
After=network.target redis.service

[Service]
Type=forking
User=typesafe
Group=typesafe
WorkingDirectory=/path/to/backend
Environment="PATH=/path/to/venv/bin"
ExecStart=/path/to/venv/bin/celery -A app.agents.worker worker --loglevel=info --concurrency=4 --detach
ExecStop=/path/to/venv/bin/celery -A app.agents.worker control shutdown
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

---

## Monitoring & Observability

### Key Metrics to Track

1. **Task Metrics:**
   - Tasks enqueued per minute
   - Tasks completed per minute
   - Task success/failure rate
   - Average task duration
   - Task queue depth

2. **Worker Metrics:**
   - Active workers count
   - Worker CPU usage
   - Worker memory usage
   - Tasks per worker

3. **Redis Metrics:**
   - Memory usage
   - Connection count
   - Command latency

### Logging Format

```python
{
  "timestamp": "2025-10-18T10:30:45Z",
  "level": "INFO",
  "service": "celery_worker",
  "task_id": "abc-123",
  "task_name": "example_agent_task",
  "event": "task_started",
  "worker": "worker-1@hostname"
}
```

---

## Success Criteria

- [ ] Celery worker starts without errors
- [ ] Tasks can be enqueued and executed successfully
- [ ] Health check endpoint returns 200 OK
- [ ] Load test passes: 100 concurrent tasks, >95% success rate
- [ ] Worker auto-restarts after crash (supervisor/systemd)
- [ ] Flower monitoring accessible at http://localhost:5555
- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] Documentation complete

---

## Dependencies

- **Upstream:** None (foundation story)
- **Downstream:** Stories 8.2-8.12 (all require this infrastructure)

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|---------|------------|
| Redis connection failures | High | Automatic reconnection, connection pooling |
| Worker crashes | High | Supervisor/systemd auto-restart, task acks_late |
| Memory leaks | Medium | Worker restarts after 1000 tasks, monitoring |
| Task queue congestion | Medium | Horizontal scaling, multiple workers |

---

## Notes

- This is a **foundational story** - all other agent stories depend on it
- Start simple: 1 worker locally, scale to multiple workers in production
- Flower is optional but highly recommended for debugging
- Consider using Redis Sentinel for high availability in production

---

**Estimated Effort:** 16 hours  
**Sprint:** Week 8, Days 1-2

