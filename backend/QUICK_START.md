# Quick Start: Celery + Redis (Local Development)

Get the MCP agent infrastructure running on your Mac in **5 minutes**.

## What You're Setting Up

- **Redis**: Message broker (stores tasks)
- **Celery Worker**: Processes tasks asynchronously
- **FastAPI**: Your existing API (handles requests)
- **Flower**: Optional monitoring UI

## Step-by-Step Setup

### 1. Install Redis (One-time)

```bash
brew install redis
brew services start redis
```

Verify:
```bash
redis-cli ping
# Should return: PONG ✅
```

### 2. Install Python Dependencies

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate
pip install celery[redis]==5.3.4 redis==5.0.1 flower==2.0.1
```

### 3. Start Celery Worker (Terminal 1)

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate
celery -A app.agents.worker worker --loglevel=info
```

You should see:
```
✅ Connected to redis://localhost:6379/0
✅ celery@YourMac ready.
```

Leave this terminal running.

### 4. Start FastAPI (Terminal 2)

Open a **new terminal**:

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate
uvicorn app.main:app --reload --port 8000
```

Leave this terminal running too.

### 5. (Optional) Start Flower (Terminal 3)

Open **another terminal**:

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate
celery -A app.agents.worker flower --port=5555
```

Open browser: **http://localhost:5555** 🌸

---

## Test It Works

### Check Health
```bash
curl http://localhost:8000/health/celery
```

Expected:
```json
{
  "status": "healthy",
  "workers": ["celery@YourMac"],
  "active_tasks": 0
}
```

### Enqueue a Test Task
```bash
curl -X POST http://localhost:8000/tasks/enqueue \
  -H "Content-Type: application/json" \
  -d '{"data": {"test": "hello"}}'
```

Expected:
```json
{
  "task_id": "abc-123...",
  "status": "pending",
  "message": "Task enqueued successfully"
}
```

### Check Task Status
```bash
# Replace <task-id> with actual task_id from above
curl http://localhost:8000/tasks/status/<task-id>
```

Expected:
```json
{
  "task_id": "abc-123...",
  "status": "SUCCESS",
  "result": {
    "status": "completed",
    "result": "Success"
  }
}
```

✅ **It works!** You now have async task processing.

---

## Daily Workflow

### Starting Your Dev Session

**Option A: Manual (3 terminals)**
```bash
# Terminal 1: Celery Worker
cd backend && source venv/bin/activate
celery -A app.agents.worker worker --loglevel=info

# Terminal 2: FastAPI
cd backend && source venv/bin/activate
uvicorn app.main:app --reload

# Terminal 3: Flower (optional)
cd backend && source venv/bin/activate
celery -A app.agents.worker flower
```

**Option B: Quick Script**

Create `backend/dev.sh`:
```bash
#!/bin/bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate

# Start worker in background
celery -A app.agents.worker worker --loglevel=info &
WORKER_PID=$!

# Start FastAPI (foreground)
uvicorn app.main:app --reload

# Kill worker when FastAPI stops
kill $WORKER_PID
```

Make executable and run:
```bash
chmod +x backend/dev.sh
./backend/dev.sh
```

Press `Ctrl+C` to stop everything.

---

## Running Tests

```bash
cd backend
source venv/bin/activate

# Unit tests (fast, no worker needed)
pytest tests/test_celery_infrastructure.py -v

# Integration tests (requires worker running)
pytest tests/test_celery_integration.py -v -m integration

# Load test
python tests/load_test_celery.py --tasks 50
```

---

## Stopping Services

- **Celery/FastAPI**: Press `Ctrl+C` in their terminals
- **Redis**: `brew services stop redis` (or leave it running, it's lightweight)

---

## Troubleshooting

### "Connection refused" Error

Redis isn't running:
```bash
brew services start redis
redis-cli ping  # Should return PONG
```

### "No module named 'celery'"

Dependencies not installed:
```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
```

### "No active Celery workers"

Worker isn't running. Start it in Terminal 1:
```bash
cd backend
source venv/bin/activate
celery -A app.agents.worker worker --loglevel=info
```

### Port 5555 Already in Use

Something else is using Flower's port:
```bash
# Use different port
celery -A app.agents.worker flower --port=5556
```

---

## What's Next?

Now that the infrastructure is running, you can:

1. **Story 8.2-8.7**: Add MCP tools (entity extraction, web search, etc.)
2. **Story 8.12**: Build the agent orchestration logic
3. **Test**: Run load tests to verify performance
4. **Deploy**: When ready, use Docker/Kubernetes for production

---

## Quick Reference

| What | Command | Port |
|------|---------|------|
| Redis | `brew services start redis` | 6379 |
| Worker | `celery -A app.agents.worker worker` | - |
| API | `uvicorn app.main:app --reload` | 8000 |
| Flower | `celery -A app.agents.worker flower` | 5555 |

| Endpoint | URL |
|----------|-----|
| API Health | http://localhost:8000/health |
| Celery Health | http://localhost:8000/health/celery |
| Enqueue Task | POST http://localhost:8000/tasks/enqueue |
| Task Status | GET http://localhost:8000/tasks/status/{id} |
| Flower UI | http://localhost:5555 |

---

**Need more details?** See `LOCAL_DEVELOPMENT.md` for advanced topics.

**Ready to deploy?** See `CELERY_DEPLOYMENT.md` and `deployment/` folder.

