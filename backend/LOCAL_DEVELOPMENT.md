# Local Development Setup for Celery + Redis

This guide shows you how to run the Celery task queue infrastructure locally on your Mac **without Docker or Kubernetes**.

## Prerequisites

- Python 3.11+
- Homebrew (for Redis)
- Terminal/iTerm2

## Quick Start (5 minutes)

### Step 1: Install Redis

```bash
# Install Redis via Homebrew
brew install redis

# Start Redis
brew services start redis

# Verify it's running
redis-cli ping
# Should return: PONG
```

### Step 2: Install Python Dependencies

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend

# Activate your existing virtual environment (or create one)
source venv/bin/activate

# Install the new Celery dependencies
pip install celery[redis]==5.3.4 redis==5.0.1 flower==2.0.1
```

### Step 3: Start Celery Worker

Open a **new terminal window** and run:

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate

# Start Celery worker
celery -A app.agents.worker worker --loglevel=info
```

You should see:
```
[2025-01-18 10:30:00,000: INFO/MainProcess] Connected to redis://localhost:6379/0
[2025-01-18 10:30:00,100: INFO/MainProcess] celery@YourMac ready.
```

### Step 4: Start FastAPI (Existing)

Open **another terminal window** and run:

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate

# Start FastAPI server
uvicorn app.main:app --reload --port 8000
```

### Step 5: Start Flower (Optional Monitoring)

Open **another terminal window** and run:

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate

# Start Flower
celery -A app.agents.worker flower --port=5555
```

Then open your browser to: **http://localhost:5555**

---

## Terminal Layout

You'll have **3 terminal windows** running:

```
┌─────────────────────────┬─────────────────────────┐
│   Terminal 1            │   Terminal 2            │
│   Celery Worker         │   FastAPI Server        │
│                         │                         │
│   celery -A ...worker   │   uvicorn app.main:app  │
│   [Worker logs here]    │   [API logs here]       │
└─────────────────────────┴─────────────────────────┘
┌─────────────────────────────────────────────────────┐
│   Terminal 3 (Optional)                             │
│   Flower Monitoring                                 │
│                                                     │
│   celery -A ...flower                              │
│   Open: http://localhost:5555                      │
└─────────────────────────────────────────────────────┘
```

---

## Test It Works

### 1. Check Health

```bash
curl http://localhost:8000/health/celery
```

Expected response:
```json
{
  "status": "healthy",
  "workers": ["celery@YourMac"],
  "active_tasks": 0
}
```

### 2. Enqueue a Task

```bash
curl -X POST http://localhost:8000/tasks/enqueue \
  -H "Content-Type: application/json" \
  -d '{"data": {"test": "local development"}}'
```

Expected response:
```json
{
  "task_id": "abc-123-def-456",
  "status": "pending",
  "message": "Task enqueued successfully"
}
```

### 3. Check Task Status

```bash
# Replace <task-id> with the task_id from step 2
curl http://localhost:8000/tasks/status/<task-id>
```

Expected response:
```json
{
  "task_id": "abc-123-def-456",
  "status": "SUCCESS",
  "result": {
    "task_id": "abc-123-def-456",
    "status": "completed",
    "result": "Success",
    "attempts": 1
  }
}
```

### 4. View in Flower

Open http://localhost:5555 to see:
- Active tasks
- Completed tasks
- Worker status
- Task history

---

## Running Tests Locally

### Unit Tests (No Worker Required)

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
source venv/bin/activate

# Run unit tests
pytest tests/test_celery_infrastructure.py -v
```

### Integration Tests (Worker Required)

Make sure Redis and at least one Celery worker are running, then:

```bash
# Run integration tests
pytest tests/test_celery_integration.py -v -m integration
```

### Load Test

```bash
# Run load test with 50 tasks
python tests/load_test_celery.py --tasks 50 --concurrent 5
```

---

## Development Workflow

### Typical Development Session

1. **Start Redis** (once per boot, or runs automatically)
   ```bash
   brew services start redis
   ```

2. **Start Celery Worker** (Terminal 1)
   ```bash
   cd backend && source venv/bin/activate
   celery -A app.agents.worker worker --loglevel=info
   ```

3. **Start FastAPI** (Terminal 2)
   ```bash
   cd backend && source venv/bin/activate
   uvicorn app.main:app --reload
   ```

4. **Start Flower** (Terminal 3, optional)
   ```bash
   cd backend && source venv/bin/activate
   celery -A app.agents.worker flower
   ```

5. **Code and test!** 
   - Make changes to task code
   - Worker auto-reloads on code changes (when using `--autoreload`)
   - Test via API or Flower UI

### Auto-reload Worker on Code Changes

To make the worker restart when you change task code:

```bash
celery -A app.agents.worker worker --loglevel=info --autoreload
```

**Note:** This is for development only, not for production.

---

## Stopping Services

### Stop Celery Worker
- Press `Ctrl+C` in the worker terminal

### Stop FastAPI
- Press `Ctrl+C` in the API terminal

### Stop Flower
- Press `Ctrl+C` in the Flower terminal

### Stop Redis
```bash
# Temporary stop
brew services stop redis

# Or keep running (it's lightweight)
```

---

## Troubleshooting

### Redis Not Starting

```bash
# Check if Redis is running
brew services list | grep redis

# Start it
brew services start redis

# Test connection
redis-cli ping
```

### Worker Can't Connect to Redis

```bash
# Check Redis is running on port 6379
lsof -i :6379

# Check environment variables
echo $CELERY_BROKER_URL
# Should be: redis://localhost:6379/0

# If not set, Redis defaults to localhost:6379 anyway
```

### Import Errors

```bash
# Make sure you're in the backend directory
cd /Users/leongwenxuan/Desktop/TypeSafe/backend

# Make sure venv is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

### Port Already in Use

```bash
# Check what's using port 5555 (Flower)
lsof -i :5555

# Kill the process
kill -9 <PID>

# Or use a different port
celery -A app.agents.worker flower --port=5556
```

### Task Not Found

Make sure you're in the `backend/` directory when starting the worker:

```bash
cd /Users/leongwenxuan/Desktop/TypeSafe/backend
celery -A app.agents.worker worker --loglevel=info
```

---

## Performance Tips

### Adjust Worker Concurrency

Default is 4 concurrent tasks. Adjust based on your Mac's CPU:

```bash
# For M1/M2 with 8 cores
celery -A app.agents.worker worker --concurrency=8

# For lighter load
celery -A app.agents.worker worker --concurrency=2
```

### Monitor System Resources

```bash
# Check CPU/Memory usage
top -o cpu

# Or use Activity Monitor (GUI)
open -a "Activity Monitor"
```

---

## Environment Variables (Optional)

Create `.env` file in `backend/` directory:

```bash
# backend/.env

# Redis (defaults work fine for local)
REDIS_URL=redis://localhost:6379
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1

# Your existing API keys
GROQ_API_KEY=your_key
GEMINI_API_KEY=your_key
SUPABASE_URL=your_url
SUPABASE_KEY=your_key
BACKEND_API_KEY=your_key

# Environment
ENVIRONMENT=development
```

---

## VS Code Integration (Optional)

If you use VS Code, you can configure tasks to start everything:

Create `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start Celery Worker",
      "type": "shell",
      "command": "source venv/bin/activate && celery -A app.agents.worker worker --loglevel=info",
      "options": {
        "cwd": "${workspaceFolder}/backend"
      },
      "isBackground": true,
      "problemMatcher": []
    },
    {
      "label": "Start Flower",
      "type": "shell",
      "command": "source venv/bin/activate && celery -A app.agents.worker flower --port=5555",
      "options": {
        "cwd": "${workspaceFolder}/backend"
      },
      "isBackground": true,
      "problemMatcher": []
    },
    {
      "label": "Start All Services",
      "dependsOn": ["Start Celery Worker", "Start Flower"]
    }
  ]
}
```

Then: `Command+Shift+P` → "Run Task" → "Start All Services"

---

## Next Steps

Once you're comfortable running locally:

1. **Story 8.2-8.7**: Add MCP tools (entity extraction, web search, etc.)
2. **Story 8.12**: Add agent orchestration logic
3. **Docker**: Package everything for production
4. **Kubernetes**: Scale for production loads

---

## Summary: What You Need Running

For **local development**, you need:

| Service | Command | Terminal | Required? |
|---------|---------|----------|-----------|
| Redis | `brew services start redis` | Background | ✅ Yes |
| Celery Worker | `celery -A app.agents.worker worker` | Terminal 1 | ✅ Yes |
| FastAPI | `uvicorn app.main:app --reload` | Terminal 2 | ✅ Yes |
| Flower | `celery -A app.agents.worker flower` | Terminal 3 | ⭐ Optional |

That's it! Simple and fast for development.

---

**Pro Tip:** Create a shell script to start everything:

```bash
# backend/start_dev.sh
#!/bin/bash

# Start Redis (if not running)
brew services start redis

# Start Celery worker in background
celery -A app.agents.worker worker --loglevel=info &
CELERY_PID=$!

# Start Flower in background
celery -A app.agents.worker flower --port=5555 &
FLOWER_PID=$!

# Start FastAPI (foreground)
uvicorn app.main:app --reload

# Cleanup on exit
trap "kill $CELERY_PID $FLOWER_PID" EXIT
```

Make it executable:
```bash
chmod +x backend/start_dev.sh
```

Run it:
```bash
cd backend
./start_dev.sh
```

Press `Ctrl+C` to stop everything.

