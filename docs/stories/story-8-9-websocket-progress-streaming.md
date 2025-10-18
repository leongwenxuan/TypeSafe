# Story 8.9: WebSocket Progress Streaming

**Story ID:** 8.9  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P0 (Essential for Transparency)  
**Effort:** 12 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As a** frontend client,  
**I want** to receive real-time updates via WebSocket,  
**so that** I can display agent progress and tool executions to users.

---

## Description

Builds on Epic 7's progress system to add WebSocket streaming for agent tasks. Users see:
- Current step ("Checking scam database...")
- Tool-by-tool progress
- Real-time updates as tools complete
- Final verdict when analysis done

**Flow:**
```
Client → POST /scan-image → Returns {task_id, ws_url}
       → Connect to ws://api/ws/agent-progress/{task_id}
       → Receive: {"step": "scam_db", "message": "Checking database...", "percent": 30}
       → Receive: {"step": "exa_search", "message": "Searching web...", "percent": 50}
       → Receive: {"step": "completed", "message": "Analysis complete!", "percent": 100}
```

---

## Acceptance Criteria

### WebSocket Endpoint
- [ ] 1. WebSocket endpoint: `ws://api/ws/agent-progress/{task_id}`
- [ ] 2. Subscribes to Redis Pub/Sub channel: `agent_progress:{task_id}`
- [ ] 3. Streams progress messages as JSON to connected clients
- [ ] 4. Auto-closes when task completes or fails
- [ ] 5. Handles client disconnection gracefully

### Message Format
- [ ] 6. JSON format: `{"step": str, "tool": str, "message": str, "percent": int, "timestamp": str}`
- [ ] 7. Step types: `entity_extraction`, `scam_db`, `exa_search`, `domain_reputation`, `phone_validator`, `reasoning`, `completed`, `failed`
- [ ] 8. Tool names match agent tool names for UI mapping
- [ ] 9. Progress percentage 0-100

### Connection Management
- [ ] 10. Heartbeat every 15 seconds to keep connection alive
- [ ] 11. Cleanup on client disconnect (unsubscribe from Redis)
- [ ] 12. Timeout if no messages for 60 seconds (task likely failed)
- [ ] 13. Connection limit: Max 100 concurrent WebSocket connections

### Error Handling
- [ ] 14. Send error messages to client: `{"step": "failed", "message": "...", "error": true}`
- [ ] 15. Gracefully handle Redis connection failures
- [ ] 16. Log all connection errors for debugging

### Testing
- [ ] 17. Integration test: Full WebSocket flow with real agent task
- [ ] 18. Test connection timeout and cleanup
- [ ] 19. Test concurrent connections (10+ clients)
- [ ] 20. Test error scenarios (invalid task_id, Redis down)

---

## Technical Implementation

**`app/main.py` (WebSocket endpoint):**

```python
"""WebSocket endpoint for agent progress streaming."""

from fastapi import WebSocket, WebSocketDisconnect
import redis.asyncio as redis
import json
import asyncio
import logging

logger = logging.getLogger(__name__)


@app.websocket("/ws/agent-progress/{task_id}")
async def agent_progress_stream(websocket: WebSocket, task_id: str):
    """
    Stream agent progress updates via WebSocket.
    
    Args:
        task_id: Unique agent task identifier
    """
    await websocket.accept()
    logger.info(f"WebSocket connected: task_id={task_id}")
    
    redis_client = None
    pubsub = None
    
    try:
        # Connect to Redis
        redis_client = await redis.from_url(
            os.getenv('REDIS_URL', 'redis://localhost:6379/0')
        )
        pubsub = redis_client.pubsub()
        
        # Subscribe to progress channel
        channel = f'agent_progress:{task_id}'
        await pubsub.subscribe(channel)
        
        # Send initial connection message
        await websocket.send_json({
            "step": "connected",
            "message": "Connected to agent progress stream",
            "percent": 0
        })
        
        # Stream messages
        heartbeat_task = asyncio.create_task(_heartbeat(websocket))
        
        async for message in pubsub.listen():
            if message['type'] == 'message':
                try:
                    data = json.loads(message['data'])
                    await websocket.send_text(message['data'])
                    
                    # Check if task completed
                    if data.get('step') in ['completed', 'failed']:
                        logger.info(f"Task {task_id} {data.get('step')}, closing WebSocket")
                        break
                
                except json.JSONDecodeError:
                    logger.warning(f"Invalid JSON in progress message: {message['data']}")
                except Exception as e:
                    logger.error(f"Error sending message: {e}")
                    break
        
        # Cancel heartbeat
        heartbeat_task.cancel()
        
    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected: task_id={task_id}")
    
    except Exception as e:
        logger.error(f"WebSocket error for task {task_id}: {e}", exc_info=True)
    
    finally:
        # Cleanup
        if pubsub:
            await pubsub.unsubscribe(f'agent_progress:{task_id}')
            await pubsub.close()
        if redis_client:
            await redis_client.close()
        
        try:
            await websocket.close()
        except:
            pass


async def _heartbeat(websocket: WebSocket, interval: int = 15):
    """Send periodic heartbeat to keep connection alive."""
    try:
        while True:
            await asyncio.sleep(interval)
            await websocket.send_json({"heartbeat": True})
    except asyncio.CancelledError:
        pass
    except Exception as e:
        logger.debug(f"Heartbeat error: {e}")
```

---

## Success Criteria

- [ ] All 20 acceptance criteria met
- [ ] WebSocket streams progress in real-time
- [ ] Handles 10+ concurrent connections
- [ ] Auto-cleanup on disconnect
- [ ] All integration tests passing

---

**Estimated Effort:** 12 hours  
**Sprint:** Week 10, Days 1-2

