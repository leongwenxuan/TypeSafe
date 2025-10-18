# Epic 7: Real-Time Progress Updates

**Epic ID:** 7  
**Epic Title:** Real-Time Progress Updates for Backend Processing  
**Priority:** P1 (Enhancement - User Experience Improvement)  
**Timeline:** Week 7  
**Dependencies:** Epic 1 (Backend API), Epic 2 (Keyboard Extension), Epic 3 (Companion App)

---

## Epic Goal

Provide live progress updates to users during backend AI processing by streaming status messages (e.g., "Analyzing Text...", "Processing Image...", "Checking for Scams...") to the keyboard banner and companion app, transforming opaque loading states into transparent, informative feedback that builds user trust and reduces perceived wait time.

---

## Epic Description

Currently, when users trigger scam detection (text analysis or screenshot scanning), they experience a black-box waiting period (1-3 seconds) with no indication of what's happening. This creates:

- **Uncertainty:** "Is it working? Should I tap again?"
- **Perceived slowness:** Silent processing feels longer than it actually is
- **Missed engagement opportunity:** Users don't understand the complexity of multi-provider AI analysis

This epic implements a **real-time progress streaming system** that:

1. Broadcasts processing stages from backend to frontend (text analysis, OCR, Gemini analysis, Groq fallback, etc.)
2. Updates keyboard banner and app UI with human-friendly status messages
3. Provides transparent visibility into multi-step AI workflows
4. Reduces perceived latency by 30-40% through informative feedback

**User Experience Enhancement:**

- **Current:** [Tap] → [Silent Loading Spinner] → [Result] (~2-3 seconds)
- **New:** [Tap] → "Analyzing Text..." → "Checking Risk..." → [Result] (~same time, feels faster)

---

## Problem Statement

**Current State Issues:**

1. **Opacity:** Users have no visibility into backend processing stages
2. **Uncertainty:** No indication of progress during 1-3 second API calls
3. **Perceived Latency:** Silent loading feels slower than it actually is
4. **Lack of Trust:** Users don't see the multi-provider AI analysis happening
5. **Debugging Difficulty:** Frontend has no insight into backend processing steps

**User Feedback (Hypothetical):**
> "When I tap 'Scan Now', nothing happens for 2 seconds. I thought it was broken."
> 
> "I'd feel more confident if I could see the AI actually working."

---

## Proposed Solution

### Architecture: Server-Sent Events (SSE)

**Why SSE over WebSockets or Polling?**

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Server-Sent Events (SSE)** | ✅ Unidirectional (perfect for progress updates)<br>✅ Built-in reconnection<br>✅ Works with HTTP/HTTPS<br>✅ Easy FastAPI integration | ❌ No bi-directional communication | ✅ **SELECTED** |
| **WebSockets** | ✅ Bi-directional | ❌ Overkill for one-way updates<br>❌ Complex connection management | ❌ Over-engineered |
| **Polling** | ✅ Simple | ❌ High server load<br>❌ Increased latency | ❌ Inefficient |

### Technical Design

**Backend (FastAPI):**
```python
@app.get("/progress/{request_id}")
async def stream_progress(request_id: str):
    async def event_generator():
        # Subscribe to progress updates for this request_id
        while processing:
            progress_data = await get_progress_update(request_id)
            yield f"data: {json.dumps(progress_data)}\n\n"
    
    return EventSourceResponse(event_generator())
```

**Progress Manager:**
- In-memory dict mapping `request_id` → progress queue
- Services publish progress events (e.g., "gemini_started", "ocr_complete")
- SSE endpoint consumes and streams events to clients

**Frontend (Swift):**
```swift
// EventSource library for SSE in iOS
let eventSource = EventSource(url: "https://api.typesafe.com/progress/\(requestId)")
eventSource.onMessage { message in
    updateBannerText(message.data.status) // "Analyzing Text..."
}
```

---

## User Stories

### Story 7.1: Backend Progress Manager Infrastructure

**As a** backend developer,  
**I want** a progress tracking system that services can publish updates to,  
**so that** frontend clients can receive real-time processing status.

**Acceptance Criteria:**

1. `ProgressManager` singleton class created in `app/services/`
2. Methods: `create_session(request_id)`, `publish(request_id, stage, message)`, `get_updates(request_id)`
3. In-memory storage with TTL (5 minutes) for automatic cleanup
4. Thread-safe implementation for concurrent request handling
5. Progress stages enum: `STARTED`, `OCR`, `AI_ANALYSIS`, `AGGREGATING`, `COMPLETED`, `FAILED`
6. Each progress event includes: `stage`, `message`, `timestamp`, `percentage` (optional)
7. Handles race conditions (late subscribers, early completions)
8. Unit tests verify publish/subscribe flow

**Technical Notes:**
- Use `asyncio.Queue` for async event streaming
- Store progress in dict: `{request_id: Queue()}`
- Cleanup old sessions after 5 minutes (TTL)

**Priority:** P0

---

### Story 7.2: SSE Endpoint for Progress Streaming

**As a** frontend client,  
**I want** an SSE endpoint to receive real-time progress updates,  
**so that** I can display processing status to users.

**Acceptance Criteria:**

1. `GET /progress/{request_id}` endpoint returns SSE stream
2. Uses FastAPI's `StreamingResponse` with `text/event-stream` content type
3. Streams progress events as JSON: `{"stage": "AI_ANALYSIS", "message": "Analyzing with Gemini...", "percent": 60}`
4. Closes stream automatically when processing completes or fails
5. Handles client disconnection gracefully (cleanup resources)
6. Sends heartbeat messages every 15 seconds to keep connection alive
7. Returns 404 if `request_id` not found
8. Integration tests verify SSE streaming with test client

**Technical Implementation:**
```python
from sse_starlette.sse import EventSourceResponse

@app.get("/progress/{request_id}")
async def stream_progress(request_id: str):
    async def event_generator():
        queue = progress_manager.get_queue(request_id)
        while True:
            update = await queue.get()
            if update['stage'] == 'COMPLETED':
                yield {"data": json.dumps(update)}
                break
            yield {"data": json.dumps(update)}
    
    return EventSourceResponse(event_generator())
```

**Priority:** P0

---

### Story 7.3: Instrument Text Analysis Pipeline

**As a** text analysis service,  
**I want** to publish progress updates at each processing stage,  
**so that** users see real-time feedback during text scam detection.

**Acceptance Criteria:**

1. `/analyze-text` endpoint generates unique `request_id` and returns it immediately
2. Progress updates published at key stages:
   - `START`: "Analyzing text..." (0%)
   - `AI_CALL`: "Checking with AI..." (40%)
   - `AGGREGATING`: "Finalizing results..." (80%)
   - `COMPLETED`: "Analysis complete!" (100%)
3. Groq service publishes progress before/after API call
4. Risk aggregator publishes progress during normalization
5. Database insert publishes progress update
6. Error states publish `FAILED` stage with user-friendly message
7. All progress calls non-blocking (fire-and-forget)

**Technical Notes:**
- Modify `analyze_text_aggregated()` to accept `request_id`
- Add progress calls: `progress_manager.publish(request_id, "AI_CALL", "Checking with AI...", 40)`

**Priority:** P0

---

### Story 7.4: Instrument Image Analysis Pipeline

**As an** image analysis service,  
**I want** to publish progress updates for OCR and AI analysis stages,  
**so that** users understand the multi-step screenshot scanning process.

**Acceptance Criteria:**

1. `/scan-image` endpoint generates and returns `request_id` immediately
2. Progress updates published at key stages:
   - `START`: "Processing screenshot..." (0%)
   - `GEMINI`: "Analyzing image with Gemini..." (30%)
   - `GROQ_FALLBACK`: "Running backup analysis..." (50%)
   - `AGGREGATING`: "Combining results..." (80%)
   - `COMPLETED`: "Scan complete!" (100%)
3. Gemini service publishes progress before/after API call
4. Groq fallback publishes progress if triggered
5. Result aggregation publishes progress
6. Handles timeout scenarios with informative messages

**Technical Notes:**
- Update `analyze_image()` to accept `request_id` parameter
- Add progress calls in `gemini_service.py` and `groq_service.py`

**Priority:** P0

---

### Story 7.5: iOS Keyboard Banner Progress Display

**As a** keyboard user,  
**I want** the alert banner to show live processing status,  
**so that** I understand what's happening during scam detection.

**Acceptance Criteria:**

1. Keyboard initiates API call and receives `request_id` in immediate response
2. Opens SSE connection to `/progress/{request_id}` endpoint
3. Banner displays progress messages in real-time (e.g., "Analyzing text...")
4. Updates banner text smoothly (no flickering)
5. Shows subtle loading animation (spinner or progress bar)
6. Closes SSE connection when results received
7. Falls back to static "Analyzing..." if SSE fails (graceful degradation)
8. Handles connection errors silently (no user disruption)
9. Cleans up SSE connection on keyboard dismissal
10. Works with both text analysis and screenshot scan flows

**Technical Implementation:**
- Use iOS `EventSource` library for SSE: `https://github.com/inaka/EventSource`
- Update `RiskAlertBannerView` to show progress text
- Store `EventSource` instance in `KeyboardViewController`

**UI Design:**
```
┌─────────────────────────────────────┐
│ ⚠️ Analyzing Text...          [◌]  │  ← Yellow/Amber banner
│    Checking with AI...             │  ← Progress message
└─────────────────────────────────────┘
```

**Priority:** P1

---

### Story 7.6: Companion App Progress Display

**As a** companion app user,  
**I want** the scan view to show live processing status,  
**so that** I see progress during screenshot analysis.

**Acceptance Criteria:**

1. `ScanView` initiates scan and receives `request_id`
2. Opens SSE connection to `/progress/{request_id}`
3. Updates progress bar and status text in real-time
4. Progress bar animates from 0% to 100% based on backend percentage
5. Status messages displayed below progress bar
6. Shows final result when `COMPLETED` stage received
7. Handles `FAILED` stage with error message
8. Graceful fallback if SSE unavailable
9. Timeout after 10 seconds if no progress updates received

**UI Design:**
```
┌─────────────────────────────────────┐
│  Scanning Screenshot                │
│                                     │
│  ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░  60%        │  ← Progress bar
│                                     │
│  📸 Analyzing image with Gemini... │  ← Status message
└─────────────────────────────────────┘
```

**Priority:** P1

---

### Story 7.7: Error Handling & Fallback Behavior

**As a** developer,  
**I want** progress streaming to degrade gracefully on failures,  
**so that** users aren't disrupted if SSE is unavailable.

**Acceptance Criteria:**

1. Backend handles missing `request_id` with 404 response
2. Frontend falls back to static "Analyzing..." if SSE connection fails
3. SSE connection timeout set to 10 seconds (auto-close)
4. Backend cleans up progress sessions after 5 minutes (prevent memory leaks)
5. Frontend retries SSE connection once if initial connection fails
6. Logs all SSE errors for debugging (client and server)
7. Progress updates never block main API processing (fire-and-forget)
8. If progress manager unavailable, API continues working normally
9. Unit tests verify fallback behavior

**Priority:** P1

---

## Technical Architecture

### Backend Components

```
┌─────────────────────────────────────────────────────────┐
│                    FastAPI Backend                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────┐      ┌──────────────────┐         │
│  │ /analyze-text  │─────▶│ Progress Manager │         │
│  │ /scan-image    │      │  - create_session│         │
│  └────────────────┘      │  - publish()     │         │
│                           │  - get_updates() │         │
│  ┌────────────────┐      └──────────────────┘         │
│  │ /progress/{id} │              │                      │
│  │  (SSE Stream)  │◀─────────────┘                     │
│  └────────────────┘                                     │
│                                                          │
│  Services publish progress:                             │
│  - gemini_service.py                                    │
│  - groq_service.py                                      │
│  - risk_aggregator.py                                   │
└─────────────────────────────────────────────────────────┘
```

### Frontend Components

```
┌─────────────────────────────────────────────────────────┐
│                    iOS Frontend                          │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Keyboard Extension:                                     │
│  ┌────────────────────┐     ┌──────────────────┐       │
│  │ KeyboardViewController│───▶│ ProgressBannerView│      │
│  │  - apiService      │     │  - updateStatus() │       │
│  │  - eventSource     │◀────┤  - showProgress() │       │
│  └────────────────────┘     └──────────────────┘       │
│                                                          │
│  Companion App:                                          │
│  ┌────────────────────┐     ┌──────────────────┐       │
│  │ ScanView           │───▶│ ProgressView     │       │
│  │  - apiService      │     │  - progressBar   │       │
│  │  - eventSource     │◀────┤  - statusLabel   │       │
│  └────────────────────┘     └──────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
1. User Action (Type Text / Scan Screenshot)
         │
         ▼
2. API Call (POST /analyze-text or /scan-image)
         │
         ├─▶ Immediate Response: {"request_id": "abc123", "status": "processing"}
         │
         ▼
3. Frontend Opens SSE Stream (GET /progress/abc123)
         │
         ▼
4. Backend Processing:
   - Progress: {"stage": "START", "message": "Analyzing...", "percent": 0}
   - Progress: {"stage": "AI_ANALYSIS", "message": "Checking with AI...", "percent": 50}
   - Progress: {"stage": "COMPLETED", "message": "Done!", "percent": 100}
         │
         ▼
5. Frontend Updates Banner/UI in Real-Time
         │
         ▼
6. Stream Closes, Final Result Displayed
```

---

## Progress Stages & Messages

### Text Analysis Pipeline

| Stage | Message | Percentage |
|-------|---------|------------|
| `START` | "Analyzing text..." | 0% |
| `AI_CALL` | "Checking with AI..." | 40% |
| `AGGREGATING` | "Finalizing results..." | 80% |
| `COMPLETED` | "Analysis complete!" | 100% |
| `FAILED` | "Analysis failed. Please try again." | - |

### Image Analysis Pipeline

| Stage | Message | Percentage |
|-------|---------|------------|
| `START` | "Processing screenshot..." | 0% |
| `GEMINI` | "Analyzing image with Gemini..." | 30% |
| `GROQ_FALLBACK` | "Running backup analysis..." | 50% |
| `AGGREGATING` | "Combining results..." | 80% |
| `COMPLETED` | "Scan complete!" | 100% |
| `FAILED` | "Scan failed. Please try again." | - |

---

## Performance Considerations

**Latency Impact:**
- SSE connection overhead: ~50-100ms initial handshake
- Progress publishing overhead: < 1ms per update (fire-and-forget)
- Total impact on API response time: < 5% (acceptable for UX benefit)

**Resource Usage:**
- Memory: ~10KB per active progress session (negligible)
- Connections: 1 additional HTTP connection per request (standard SSE)
- Cleanup: Auto-cleanup after 5 minutes prevents memory leaks

**Optimization:**
- Progress publishing is non-blocking (background threads)
- SSE heartbeats only every 15 seconds (minimal overhead)
- In-memory storage (no database writes for progress)

---

## Testing Strategy

### Unit Tests

- `ProgressManager` publish/subscribe logic
- SSE event formatting and serialization
- Progress cleanup after TTL expiration
- Concurrent request handling

### Integration Tests

- End-to-end SSE streaming with test client
- Progress updates during real API calls
- Error handling and fallback behavior
- Connection timeout and cleanup

### Manual Testing

- Real device testing (iOS keyboard and app)
- Network condition simulation (slow 3G, disconnections)
- Concurrent scan testing (multiple users)
- Visual verification of progress messages

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|---------|------------|
| **SSE connection overhead** | Low | Minimal latency added (~50ms); acceptable for UX gain |
| **Memory leaks from abandoned connections** | Medium | Auto-cleanup after 5 minutes; TTL expiration |
| **iOS EventSource library stability** | Medium | Use well-maintained library; implement fallback |
| **Backend complexity increase** | Low | Progress manager is isolated; doesn't affect core logic |
| **Network instability breaking SSE** | Medium | Graceful fallback to static "Analyzing..." message |

---

## Privacy & Security

**Data Considerations:**
- Progress messages contain NO user text or image data
- Only generic status messages: "Analyzing text...", "Processing image..."
- `request_id` is random UUID, not linked to user identity
- SSE stream auto-closes after processing (no persistent connections)

**Security:**
- SSE endpoint requires valid `request_id` (no enumeration attacks)
- Progress sessions expire after 5 minutes (prevent resource exhaustion)
- No sensitive data exposed in progress messages
- HTTPS required for SSE connections (prevent eavesdropping)

---

## Definition of Done

- [ ] Story 7.1: ProgressManager implemented and tested
- [ ] Story 7.2: SSE endpoint functional with streaming tests
- [ ] Story 7.3: Text analysis pipeline instrumented
- [ ] Story 7.4: Image analysis pipeline instrumented
- [ ] Story 7.5: Keyboard banner shows live progress
- [ ] Story 7.6: Companion app shows progress bar
- [ ] Story 7.7: Error handling and fallbacks tested
- [ ] Integration tests pass for all flows
- [ ] Manual testing on iOS devices successful
- [ ] Performance benchmarks meet targets (< 5% overhead)
- [ ] Documentation updated with SSE endpoint details

---

## Success Metrics

**User Experience:**
- Reduce perceived latency by 30-40% (via user surveys)
- Increase user confidence in AI processing (qualitative feedback)
- Reduce "accidental double-taps" by 50% (analytics tracking)

**Technical Performance:**
- SSE connection overhead < 100ms (p95)
- Progress update publishing < 1ms per event
- Memory usage < 50MB for 100 concurrent sessions
- Zero memory leaks after 24-hour soak test

**Adoption:**
- 95%+ of API calls successfully stream progress updates
- < 1% SSE connection failures requiring fallback
- No user-reported issues with progress display

---

## Rollout Plan

**Phase 1: Backend Infrastructure (Week 1)**
- Implement ProgressManager and SSE endpoint
- Instrument text and image analysis pipelines
- Deploy to staging for testing

**Phase 2: iOS Integration (Week 2)**
- Implement EventSource integration in keyboard
- Add progress display to companion app
- Beta testing with internal users

**Phase 3: Production Release (Week 3)**
- Deploy to production with monitoring
- Collect user feedback and analytics
- Iterate on progress messages based on feedback

---

## Future Enhancements

**Post-Epic Ideas:**
- Visual progress animations (e.g., animated AI brain icon)
- More granular progress stages (10+ stages instead of 5)
- Progress persistence (show progress even if app is reopened)
- Multi-language progress messages
- Voice feedback for progress updates (accessibility)

---

## Notes

This epic transforms opaque AI processing into a transparent, trust-building experience. By showing users exactly what's happening during scam detection, we:

- **Build trust:** Users see the multi-provider AI analysis in action
- **Reduce friction:** Informative feedback makes waiting feel faster
- **Differentiate from competitors:** Most security apps have silent loading states
- **Enable debugging:** Progress logs help identify slow processing stages

**Estimated Timeline:** 2-3 weeks
- Week 1: Backend infrastructure (Stories 7.1-7.4)
- Week 2: iOS integration (Stories 7.5-7.6)
- Week 3: Testing and polish (Story 7.7)

---

**End of Epic 7**

