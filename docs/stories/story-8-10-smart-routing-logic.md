# Story 8.10: Smart Routing Logic

**Story ID:** 8.10  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P0 (Critical for Performance)  
**Effort:** 10 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As a** backend API,  
**I want** to intelligently route scans to fast path or agent path,  
**so that** simple scans remain fast while complex scans get deep analysis.

---

## Description

Smart routing ensures optimal performance by deciding which scans need the full agent treatment:

**Fast Path (1-3s):**
- No entities detected
- Generic content (no phone numbers, URLs, emails)
- Uses existing Gemini/Groq analysis only

**Agent Path (5-30s):**
- Contains phone numbers, URLs, emails, or payment details
- Requires tool investigation
- Returns `task_id` + WebSocket URL

**Key Decision:** Extract entities ONCE at routing time, pass to agent if needed

---

## Acceptance Criteria

### Routing Logic
- [ ] 1. Modified `/scan-image` endpoint with routing decision
- [ ] 2. Quick entity extraction check (< 100ms)
- [ ] 3. Routes to agent if ANY entities found
- [ ] 4. Routes to fast path if NO entities found
- [ ] 5. Feature flag: `ENABLE_MCP_AGENT` (default: true in prod)

### Response Formats
- [ ] 6. Fast path returns: `{"type": "simple", "result": {...}}`
- [ ] 7. Agent path returns: `{"type": "agent", "task_id": "...", "ws_url": "...", "estimated_time": "5-30 seconds"}`
- [ ] 8. Both response types have consistent structure for frontend

### Task Status Endpoint
- [ ] 9. `GET /agent-task/{task_id}/status` endpoint
- [ ] 10. Returns: `{"status": "pending|processing|completed|failed", "result": {...}}`
- [ ] 11. Polls Celery task state
- [ ] 12. Returns result if completed

### Fallback Strategy
- [ ] 13. If Celery worker down, route all to fast path
- [ ] 14. If agent task times out (>60s), return timeout error
- [ ] 15. Health check: `/health/agent` checks worker availability

### Metrics
- [ ] 16. Track routing decisions: % agent vs fast path
- [ ] 17. Track agent path latency (p50, p95, p99)
- [ ] 18. Track fast path latency (baseline)
- [ ] 19. Alert if agent path > 50% of scans (potential issue)

### Testing
- [ ] 20. Unit tests for routing logic
- [ ] 21. Integration tests: Fast and agent paths
- [ ] 22. Load test: 100 concurrent scans with mixed routing

---

## Technical Implementation

**`app/main.py` (Updated scan endpoint):**

```python
"""Smart routing for scans."""

import uuid
from app.agents.mcp_agent import analyze_with_mcp_agent
from app.services.entity_extractor import get_entity_extractor

@app.post("/scan-image")
async def scan_image(
    image: UploadFile,
    ocr_text: str = Form(...),
    session_id: str = Form(...)
):
    """Scan image with smart routing."""
    
    # Quick entity extraction check
    extractor = get_entity_extractor()
    entities = extractor.extract(ocr_text)
    
    has_entities = entities.has_entities()
    
    if has_entities and settings.ENABLE_MCP_AGENT:
        # Route to agent path
        task_id = str(uuid.uuid4())
        
        # Enqueue agent task
        analyze_with_mcp_agent.delay(
            task_id=task_id,
            ocr_text=ocr_text,
            session_id=session_id,
            user_metadata={"country": get_user_country()}
        )
        
        return {
            "type": "agent",
            "task_id": task_id,
            "ws_url": f"ws://{settings.API_DOMAIN}/ws/agent-progress/{task_id}",
            "estimated_time": "5-30 seconds",
            "entities_found": entities.entity_count()
        }
    else:
        # Route to fast path (existing logic)
        result = await analyze_image_fast_path(
            image_data=await image.read(),
            ocr_text=ocr_text,
            session_id=session_id
        )
        
        return {
            "type": "simple",
            "result": result
        }


@app.get("/agent-task/{task_id}/status")
async def get_agent_task_status(task_id: str):
    """Get status of agent task."""
    from celery.result import AsyncResult
    from app.agents.worker import celery_app
    
    result = AsyncResult(task_id, app=celery_app)
    
    return {
        "task_id": task_id,
        "status": result.state.lower(),
        "result": result.result if result.successful() else None,
        "error": str(result.info) if result.failed() else None
    }
```

---

## Success Criteria

- [ ] All 22 acceptance criteria met
- [ ] Routing decision < 100ms
- [ ] Fast path maintains 1-3s latency
- [ ] Agent path completes in < 30s
- [ ] All tests passing

---

**Estimated Effort:** 10 hours  
**Sprint:** Week 10, Day 2

