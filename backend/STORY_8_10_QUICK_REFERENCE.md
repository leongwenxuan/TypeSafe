# Story 8.10: Smart Routing - Quick Reference

**Quick guide for developers working with smart routing logic.**

---

## Overview

Smart routing intelligently decides whether to use:
- **Fast Path**: Gemini/Groq analysis (1-3s) for simple scans
- **Agent Path**: MCP agent with tools (5-30s) for complex scans

**Routing Decision:** Based on entity extraction (phones, URLs, emails, payments)

---

## Key Endpoints

### 1. Scan Image (with Smart Routing)
```bash
POST /scan-image
```

**Request:**
```bash
curl -X POST http://localhost:8000/scan-image \
  -F "session_id=<uuid>" \
  -F "ocr_text=<text>" \
  -F "user_country=US" \
  -F "image=@screenshot.png"
```

**Response Types:**

**Fast Path (no entities):**
```json
{
  "type": "simple",
  "result": {
    "risk_level": "low|medium|high",
    "confidence": 0.85,
    "category": "...",
    "explanation": "...",
    "ts": "2025-01-18T10:30:00Z"
  }
}
```

**Agent Path (entities found):**
```json
{
  "type": "agent",
  "task_id": "uuid",
  "ws_url": "ws://domain/ws/agent-progress/{task_id}",
  "estimated_time": "5-30 seconds",
  "entities_found": 3
}
```

### 2. Agent Task Status
```bash
GET /agent-task/{task_id}/status
```

**Response:**
```json
{
  "task_id": "uuid",
  "status": "pending|processing|completed|failed",
  "result": {...},
  "error": null
}
```

### 3. Agent Health Check
```bash
GET /health/agent
```

**Response:**
```json
{
  "status": "healthy",
  "workers_active": 2,
  "active_tasks": 5
}
```

### 4. Routing Metrics
```bash
GET /metrics/routing?window_minutes=60
```

**Response:**
```json
{
  "routing_stats": {
    "total_scans": 1000,
    "agent_path_percentage": 20.0,
    "fast_path_percentage": 80.0,
    "avg_routing_time_ms": 45.2
  },
  "fast_path_latency": {
    "p50": 1500,
    "p95": 2800,
    "p99": 3200
  },
  "agent_path_latency": {
    "p50": 8500,
    "p95": 25000,
    "p99": 28000
  },
  "alerts": []
}
```

---

## Configuration

### Environment Variables

```bash
# Enable/disable MCP agent
ENABLE_MCP_AGENT=true  # Default: true

# Celery settings
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1

# API domain for WebSocket URLs
API_DOMAIN=localhost:8000
```

### Feature Flag

```python
from app.config import settings

# Check if agent is enabled
if settings.enable_mcp_agent:
    # Agent routing enabled
    pass
```

---

## Routing Logic

### Decision Flow

```python
# 1. Extract entities
extractor = get_entity_extractor()
entities = extractor.extract(ocr_text)

# 2. Check if entities found
has_entities = entities.has_entities()

# 3. Routing decision
if has_entities and settings.enable_mcp_agent and worker_available:
    # AGENT PATH: Enqueue task
    return agent_response
else:
    # FAST PATH: Gemini/Groq analysis
    return fast_path_response
```

### Fallback Scenarios

1. **Worker Unavailable**: Falls back to fast path
2. **Agent Disabled**: Falls back to fast path
3. **No Entities**: Uses fast path directly

---

## Testing

### Run All Tests

```bash
cd backend

# Unit tests
pytest tests/test_smart_routing.py -v

# Integration tests
pytest tests/test_smart_routing_integration.py -v

# All routing tests
pytest tests/test_smart_routing*.py -v

# With coverage
pytest tests/test_smart_routing*.py --cov=app.main --cov-report=html
```

### Test Scenarios

**Test 1: No entities → Fast path**
```python
response = client.post("/scan-image", data={
    "session_id": str(uuid.uuid4()),
    "ocr_text": "Hello, how are you?"
})
assert response.json()['type'] == 'simple'
```

**Test 2: With entities → Agent path**
```python
response = client.post("/scan-image", data={
    "session_id": str(uuid.uuid4()),
    "ocr_text": "Call 1-800-555-1234"
})
assert response.json()['type'] == 'agent'
```

**Test 3: Worker down → Fallback**
```python
with patch('app.main._check_worker_availability', return_value=False):
    response = client.post("/scan-image", data={...})
    assert response.json()['type'] == 'simple'  # Fallback
```

---

## Metrics Tracking

### Record Routing Decision

```python
from app.metrics.routing_metrics import get_metrics_tracker

metrics_tracker = get_metrics_tracker()

metrics_tracker.record_routing_decision(
    route_type='agent_path',  # or 'fast_path'
    has_entities=True,
    entity_count=3,
    routing_time_ms=65.2,
    session_id=str(session_uuid),
    request_id=request_id,
    fallback_reason=None  # or 'worker_unavailable', 'agent_disabled'
)
```

### Get Statistics

```python
# Routing stats
stats = metrics_tracker.get_routing_stats(window_minutes=60)

# Latency stats
fast_path_latency = metrics_tracker.get_latency_stats(
    route_type='fast_path',
    window_minutes=60
)

# Check alerts
alerts = metrics_tracker.check_alert_conditions()
```

---

## Common Issues

### Issue 1: Worker Not Available

**Symptom:** All scans go to fast path despite having entities

**Solution:**
```bash
# Check worker status
curl http://localhost:8000/health/agent

# Start Celery worker
celery -A app.agents.worker worker --loglevel=info
```

### Issue 2: Slow Entity Extraction

**Symptom:** Routing time > 100ms

**Solution:**
- Check OCR text length (should be < 5000 chars)
- Review entity extraction patterns
- Consider caching entity extractor

### Issue 3: High Agent Path Percentage

**Symptom:** > 50% of scans routed to agent path

**Solution:**
- Check if too many false positive entities
- Review entity extraction filters
- Consider adjusting routing threshold

---

## Performance Targets

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Routing Time | < 100ms | > 150ms |
| Fast Path p95 | < 3s | > 5s |
| Agent Path p95 | < 30s | > 45s |
| Agent Path % | < 30% | > 50% |
| Fallback Rate | < 5% | > 20% |

---

## Debugging

### Enable Debug Logging

```python
import logging
logging.getLogger('app.main').setLevel(logging.DEBUG)
```

### Check Routing Decision

```python
# Look for log messages like:
# "Entity extraction complete: has_entities=True count=2 time_ms=65.23"
# "Routing to AGENT PATH: entities=2"
# "Routing to FAST PATH: has_entities=False"
```

### Inspect Metrics

```bash
# Get recent routing stats
curl http://localhost:8000/metrics/routing?window_minutes=5

# Check for alerts
curl http://localhost:8000/metrics/routing | jq '.alerts'
```

---

## Integration with iOS

### Handling Agent Path Response

```swift
let response = try await apiService.scanImage(...)

switch response.type {
case "simple":
    // Fast path - show result immediately
    let result = response.result
    showRiskAssessment(result)
    
case "agent":
    // Agent path - connect to WebSocket for progress
    let taskId = response.taskId
    let wsURL = response.wsUrl
    connectToAgentProgress(wsURL: wsURL, taskId: taskId)
    
default:
    // Unknown response type
    handleError("Unknown response type")
}
```

### Polling Alternative (if WebSocket unavailable)

```swift
func pollTaskStatus(taskId: String) async {
    while true {
        let status = try await apiService.getAgentTaskStatus(taskId)
        
        switch status.status {
        case "completed":
            showRiskAssessment(status.result)
            return
        case "failed":
            handleError(status.error)
            return
        case "pending", "processing":
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        default:
            break
        }
    }
}
```

---

## Monitoring Queries

### Prometheus/Grafana

```promql
# Agent path percentage
sum(rate(routing_decision{type="agent_path"}[5m])) / 
sum(rate(routing_decision[5m])) * 100

# Routing latency p95
histogram_quantile(0.95, rate(routing_time_ms_bucket[5m]))

# Fallback rate
sum(rate(routing_decision{fallback_reason!=""}[5m])) / 
sum(rate(routing_decision[5m])) * 100
```

---

## Resources

- **Implementation Summary:** `STORY_8_10_IMPLEMENTATION_SUMMARY.md`
- **Story Document:** `docs/stories/story-8-10-smart-routing-logic.md`
- **Entity Extractor:** `app/services/entity_extractor.py`
- **Metrics Module:** `app/metrics/routing_metrics.py`
- **Unit Tests:** `tests/test_smart_routing.py`
- **Integration Tests:** `tests/test_smart_routing_integration.py`

---

## Quick Commands

```bash
# Start backend server
cd backend && uvicorn app.main:app --reload

# Start Celery worker
cd backend && celery -A app.agents.worker worker --loglevel=info

# Run tests
pytest tests/test_smart_routing*.py -v

# Check health
curl http://localhost:8000/health/agent

# Get metrics
curl http://localhost:8000/metrics/routing

# Test scan (no entities)
curl -X POST http://localhost:8000/scan-image \
  -F "session_id=$(uuidgen)" \
  -F "ocr_text=Hello world"

# Test scan (with entities)
curl -X POST http://localhost:8000/scan-image \
  -F "session_id=$(uuidgen)" \
  -F "ocr_text=Call 1-800-555-1234"
```

---

**Last Updated:** 2025-01-18

