# MCP Agent Quick Reference

**Story 8.7** - Fast reference guide for using the MCP agent orchestration system.

---

## Quick Start

### 1. Run Agent Analysis (Async)

```python
from app.agents.mcp_agent import analyze_with_mcp_agent

# Submit task to Celery
task = analyze_with_mcp_agent.delay(
    task_id="scan-123",
    ocr_text="Call 1-800-SCAM-NOW for urgent payment!",
    session_id="user-session-456"
)

# Get result (blocks until complete)
result = task.get(timeout=60)

print(f"Risk: {result['risk_level']}")
print(f"Confidence: {result['confidence']}%")
print(f"Reasoning: {result['reasoning']}")
```

### 2. Run Agent Analysis (Sync)

```python
from app.agents.mcp_agent import MCPAgentOrchestrator, ProgressPublisher
import asyncio

async def analyze():
    orchestrator = MCPAgentOrchestrator()
    progress = ProgressPublisher("task-123")
    
    result = await orchestrator.analyze(
        task_id="task-123",
        ocr_text="Visit http://phishing-site.tk",
        progress_publisher=progress
    )
    
    return result.to_dict()

result = asyncio.run(analyze())
```

---

## Tool Routing Rules

| Entity Type | Tools Used | Execution Mode |
|------------|------------|----------------|
| **Phone** | Scam DB + Exa Search + Phone Validator | Parallel |
| **URL** | Scam DB + Domain Reputation + Exa Search | Parallel |
| **Email** | Scam DB + Exa Search | Parallel |
| **Payment** | Scam DB + Exa Search | Parallel |

---

## Result Structure

```python
{
    "task_id": "scan-123",
    "risk_level": "high",              # low, medium, high
    "confidence": 85.0,                # 0-100
    "entities_found": {
        "phones": ["+18005551234"],
        "urls": ["https://scam-site.com"],
        "emails": ["scammer@evil.com"],
        "payments": [],
        "amounts": [{"amount": "500", "currency": "USD"}]
    },
    "evidence": [
        {
            "tool_name": "scam_db",
            "entity_type": "phone",
            "entity_value": "+18005551234",
            "result": {"found": True, "report_count": 47},
            "success": True,
            "execution_time_ms": 45.2
        },
        # ... more evidence
    ],
    "reasoning": "Evidence collected: Verified scam in database (47 reports); Found 12 web complaints",
    "processing_time_ms": 3247,
    "tools_used": ["scam_db", "exa_search", "phone_validator"]
}
```

---

## Progress Monitoring

```python
import redis
import json

# Subscribe to progress updates
redis_client = redis.from_url('redis://localhost:6379', decode_responses=True)
pubsub = redis_client.pubsub()
pubsub.subscribe('agent_progress:task-123')

for message in pubsub.listen():
    if message['type'] == 'message':
        data = json.loads(message['data'])
        print(f"{data['percent']}% - {data['message']}")
        
        if data['percent'] == 100:
            break
```

**Progress Messages:**
```
10%  - "Extracting entities from text..."
20%  - "Found 3 entities: 1 phones, 2 URLs, 0 emails"
30%  - "Investigating entities with tools..."
50%  - "Checking phone: +18005551234"
80%  - "Collected 6 pieces of evidence from 4 tools"
90%  - "Agent analyzing evidence..."
100% - "Analysis complete!"
```

---

## Database Queries

### Get Result by Task ID

```python
from app.db.client import get_supabase_client

supabase = get_supabase_client()

response = supabase.table('agent_scan_results').select('*').eq(
    'task_id', 'scan-123'
).single().execute()

result = response.data
```

### Get All Results for Session

```python
response = supabase.table('agent_scan_results').select('*').eq(
    'session_id', 'user-session-456'
).order('created_at', desc=True).execute()

results = response.data
```

### Get High-Risk Results

```python
response = supabase.table('agent_scan_results').select('*').eq(
    'risk_level', 'high'
).order('confidence', desc=True).limit(10).execute()

high_risk_scans = response.data
```

### Search by Entity

```python
# Find all scans that detected a specific phone number
response = supabase.table('agent_scan_results').select('*').filter(
    'entities_found', 'cs', '{"phones": ["+18005551234"]}'
).execute()
```

---

## Risk Scoring

### Score Breakdown

| Evidence | Weight | Max Points |
|----------|--------|------------|
| Scam DB (verified) | Highest | 50 |
| Scam DB (unverified) | High | 40 |
| Domain Reputation (high) | Medium-High | 30 |
| Phone Validator (suspicious) | Medium | 25 |
| Exa Search Results | Medium | 20 |
| Young Domain (<30 days) | Low | 10 |

### Risk Thresholds

- **High Risk:** Score ≥ 70
- **Medium Risk:** Score 40-69
- **Low Risk:** Score < 40

---

## Error Handling

### Tool Failures

```python
# Agent continues even if individual tools fail
result = await orchestrator.analyze(...)

# Check which tools succeeded
for evidence in result.evidence:
    if not evidence.success:
        print(f"Tool {evidence.tool_name} failed: {evidence.result['error']}")
```

### Task Retries

- **Max retries:** 3
- **Retry delays:** 2s, 4s, 8s (exponential backoff)
- **Timeout:** 60 seconds hard limit

---

## Configuration

### Environment Variables

```bash
# Required
REDIS_URL=redis://localhost:6379
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key

# Tool API Keys
EXA_API_KEY=your-exa-api-key
VIRUSTOTAL_API_KEY=your-virustotal-key  # Optional
SAFE_BROWSING_API_KEY=your-safe-browsing-key  # Optional

# Optional Settings
ENABLE_MCP_AGENT=true
EXA_CACHE_TTL=86400  # 24 hours
EXA_MAX_RESULTS=10
```

---

## Testing

### Run Unit Tests

```bash
# All unit tests
pytest tests/test_mcp_agent.py -v

# Specific test class
pytest tests/test_mcp_agent.py::TestMCPAgentOrchestrator -v

# With coverage
pytest tests/test_mcp_agent.py --cov=app.agents.mcp_agent
```

### Run Integration Tests

```bash
# Requires Redis, Supabase, and API keys
pytest tests/test_mcp_agent_integration.py -v -m integration

# Skip slow tests
pytest tests/test_mcp_agent_integration.py -v -m "integration and not slow"
```

---

## Performance

### Benchmarks

| Metric | Target | Typical |
|--------|--------|---------|
| Total Time | < 30s | 3-8s |
| Entity Extraction | < 100ms | ~50ms |
| Tool Execution (parallel) | < 5s | 2-4s |
| Database Save | < 100ms | ~30ms |

### Monitoring

```python
# Check average processing time
response = supabase.rpc('agent_performance_stats').execute()
stats = response.data

print(f"Average: {stats['avg_processing_time_ms']}ms")
print(f"P95: {stats['p95_processing_time_ms']}ms")
print(f"Total analyses: {stats['total_analyses']}")
```

---

## Troubleshooting

### "Task timeout after 60 seconds"

**Solution:** Check Exa API rate limits and network connectivity.

```bash
# Test Exa API
curl -H "Authorization: Bearer $EXA_API_KEY" https://api.exa.ai/search

# Check Redis
redis-cli ping
```

### "Redis connection failed"

**Solution:** Verify Redis is running.

```bash
# Start Redis
redis-server

# Test connection
redis-cli ping
```

### "No entities found"

**Solution:** Check entity extraction patterns.

```python
from app.services.entity_extractor import get_entity_extractor

extractor = get_entity_extractor()
entities = extractor.extract("Your text here")

print(f"Phones: {entities.phones}")
print(f"URLs: {entities.urls}")
print(f"Emails: {entities.emails}")
```

---

## Common Patterns

### Check Task Status

```python
from celery.result import AsyncResult

task_result = AsyncResult('task-id-here')
print(f"State: {task_result.state}")
print(f"Ready: {task_result.ready()}")
print(f"Successful: {task_result.successful()}")
```

### Cancel Running Task

```python
task.revoke(terminate=True)
```

### Get Task Info

```python
info = task.info
print(f"Current: {task.state}")
print(f"Result: {task.result}")
```

---

## Advanced Usage

### Custom Progress Publisher

```python
class CustomProgressPublisher:
    def publish(self, message: str, percent: int):
        # Your custom logic here
        print(f"[{percent}%] {message}")

orchestrator = MCPAgentOrchestrator()
progress = CustomProgressPublisher()

result = await orchestrator.analyze(
    task_id="custom-123",
    ocr_text="...",
    progress_publisher=progress
)
```

### Parallel Scanning

```python
# Submit multiple scans at once
tasks = []
for i, text in enumerate(ocr_texts):
    task = analyze_with_mcp_agent.delay(
        task_id=f"batch-{i}",
        ocr_text=text,
        session_id=session_id
    )
    tasks.append(task)

# Wait for all to complete
results = [task.get(timeout=60) for task in tasks]
```

---

## API Integration Example

```python
from fastapi import FastAPI, BackgroundTasks
from app.agents.mcp_agent import analyze_with_mcp_agent

app = FastAPI()

@app.post("/api/scan")
async def scan_text(
    text: str,
    session_id: str,
    background_tasks: BackgroundTasks
):
    """Submit scan for analysis."""
    import uuid
    task_id = str(uuid.uuid4())
    
    # Submit to Celery
    task = analyze_with_mcp_agent.delay(
        task_id=task_id,
        ocr_text=text,
        session_id=session_id
    )
    
    return {
        "task_id": task_id,
        "celery_task_id": task.id,
        "status": "processing"
    }

@app.get("/api/scan/{task_id}")
async def get_scan_result(task_id: str):
    """Get scan result."""
    from app.db.client import get_supabase_client
    
    supabase = get_supabase_client()
    response = supabase.table('agent_scan_results').select('*').eq(
        'task_id', task_id
    ).single().execute()
    
    return response.data
```

---

## See Also

- **Full Documentation:** `STORY_8_7_MCP_AGENT_ORCHESTRATION.md`
- **Entity Extraction:** `STORY_8_2_IMPLEMENTATION_SUMMARY.md`
- **Scam Database:** `STORY_8_3_SCAM_DATABASE_TOOL.md`
- **Exa Search:** `STORY_8_4_IMPLEMENTATION_SUMMARY.md`
- **Domain Reputation:** `STORY_8_5_DOMAIN_REPUTATION_TOOL.md`
- **Phone Validator:** `STORY_8_6_PHONE_VALIDATOR_IMPLEMENTATION.md`

