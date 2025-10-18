# Story 8.11: iOS Agent Progress Display - Quick Reference

## 🎯 What Was Built

Real-time agent progress tracking in iOS app showing step-by-step investigation updates via WebSocket.

---

## 📁 New Files Created

```
TypeSafe/Models/AgentProgress.swift              ← Data models
TypeSafe/Services/AgentProgressViewModel.swift   ← WebSocket logic
TypeSafe/Views/AgentProgressView.swift           ← Progress UI
TypeSafeTests/AgentProgressViewModelTests.swift  ← Unit tests
```

## 📝 Files Modified

```
TypeSafe/Services/APIService.swift               ← Agent path support
TypeSafe/Views/ScanView.swift                    ← Navigation integration
```

---

## 🔧 How It Works

### 1. User Scans Screenshot
```swift
// ScanView.swift
apiService.scanImage(ocrText: text, image: image) { result in
    if response.isAgentResponse {
        // Agent path → show progress
        navigateToAgentProgress(taskId, wsUrl)
    } else {
        // Fast path → show immediate result
        navigateToSimpleResult(response)
    }
}
```

### 2. Backend Returns Agent Response
```json
{
  "type": "agent",
  "task_id": "uuid-here",
  "ws_url": "ws://host/ws/agent-progress/uuid-here",
  "estimated_time": "5-30 seconds",
  "entities_found": 3
}
```

### 3. App Connects to WebSocket
```swift
// AgentProgressViewModel.swift
viewModel.connect()
// Subscribes to: ws://host/ws/agent-progress/task-id
```

### 4. Real-Time Progress Updates
```json
// Message 1
{
  "step": "entity_extraction",
  "message": "Extracting entities...",
  "percent": 10
}

// Message 2
{
  "step": "scam_db",
  "message": "Checking scam database...",
  "percent": 40
}

// Final message
{
  "step": "completed",
  "message": "Analysis complete",
  "percent": 100
}
```

### 5. Fetch & Display Final Result
```swift
GET /agent-task/{task_id}/result

// Returns AgentAnalysisResult
{
  "task_id": "...",
  "risk_level": "high",
  "confidence": 95.5,
  "reasoning": "...",
  "evidence": [...],
  "tools_used": ["scam_db", "exa_search", ...]
}
```

---

## 🎨 UI Components

### AgentProgressView
Main view showing:
- Header with status icon
- Progress bar (0-100%)
- Current step indicator
- Tool results list
- Final verdict card

### ToolResultRow
Individual tool result:
- Tool icon (shield, magnifying glass, etc.)
- Tool name
- Result summary
- Success checkmark or warning

### FinalVerdictCard
Comprehensive results:
- Risk level (red/orange/green)
- Confidence percentage
- Agent reasoning
- Entities found
- Evidence breakdown (expandable)
- Tools used badges

---

## 🧪 Testing

### Run Unit Tests
```bash
# In Xcode
⌘ + U

# Or select specific test
AgentProgressViewModelTests
```

### Manual Testing
1. Enable MCP agent in backend (ENABLE_MCP_AGENT=true)
2. Scan screenshot with phone number or URL
3. Verify agent path response
4. Watch real-time progress updates
5. Check final verdict display
6. Test error handling (disconnect WiFi)
7. Test retry functionality

---

## 🐛 Troubleshooting

### WebSocket Won't Connect
```swift
// Check URL format
print(viewModel.wsUrl)
// Should be: ws://host/ws/agent-progress/task-id
//         or: wss://host/ws/agent-progress/task-id

// Check backend logs
// Should show: "WebSocket connected: task_id=..."
```

### No Progress Updates
```bash
# Check Redis pub/sub
redis-cli
> SUBSCRIBE agent_progress:task-id-here

# Should see messages being published
```

### Missing Final Result
```bash
# Check endpoint manually
curl http://localhost:8000/agent-task/{task_id}/result

# Should return AgentAnalysisResult JSON
```

### App Crashes on Navigation
```swift
// Verify task_id and ws_url are not nil
guard let taskId = response.task_id,
      let wsUrl = response.ws_url else {
    print("Missing agent response fields!")
    return
}
```

---

## 📊 Key Metrics

### WebSocket Messages
- `step: entity_extraction` → 10%
- `step: scam_db` → 30-50%
- `step: exa_search` → 50-65%
- `step: domain_reputation` → 65-75%
- `step: phone_validator` → 75-85%
- `step: reasoning` → 85-95%
- `step: completed` → 100%

### Timeouts
- **Message timeout**: 60 seconds (no messages)
- **Reconnection**: 3 attempts with 2s delay
- **Heartbeat**: Every 15 seconds

---

## 🔍 Code Snippets

### Check Response Type
```swift
if response.isAgentResponse {
    // Has: task_id, ws_url, estimated_time, entities_found
} else if response.isSimpleResponse {
    // Has: risk_level, confidence, category, explanation
}
```

### Connect to Progress Stream
```swift
let viewModel = AgentProgressViewModel(
    taskId: taskId,
    wsUrl: wsUrl
)
viewModel.connect()
```

### Handle Completion
```swift
if message.isCompleted {
    // Fetch final result
    await viewModel.fetchFinalResult()
}
```

### Retry on Error
```swift
Button("Retry Analysis") {
    viewModel.retry()
    // Resets state and reconnects
}
```

---

## 📋 Acceptance Criteria Checklist

- ✅ 1-5: UI Components (view, progress bar, tool results, final card)
- ✅ 6-10: WebSocket Integration (connect, parse, update, reconnect)
- ✅ 11-14: Progress States (icons, animations, colors)
- ✅ 15-18: Evidence Display (breakdown, findings, reasoning, expand)
- ✅ 19-22: Error Handling (friendly errors, timeout, retry, fallback)
- ✅ 23-25: Testing (unit tests, UI tests, manual tests)

**Status: 25/25 Complete** ✅

---

## 🚀 Deployment Checklist

### Backend
- [ ] ENABLE_MCP_AGENT=true in environment
- [ ] Redis running for pub/sub
- [ ] WebSocket endpoint accessible
- [ ] CORS configured for WebSocket

### iOS App
- [ ] API_DOMAIN configured correctly
- [ ] WebSocket URL protocol (ws/wss) matches environment
- [ ] Test with real agent responses
- [ ] Monitor crash reports

### Testing
- [ ] Test agent path with entities
- [ ] Test fast path without entities
- [ ] Test WebSocket connection
- [ ] Test error handling
- [ ] Test retry functionality
- [ ] Test final result display

---

## 📞 Quick Debug Commands

```bash
# Check backend agent status
curl http://localhost:8000/health/agent

# Check routing metrics
curl http://localhost:8000/metrics/routing

# Test scan endpoint
curl -X POST http://localhost:8000/scan-image \
  -F "session_id=test-session" \
  -F "ocr_text=Call +1234567890 for urgent verification"

# Monitor WebSocket (wscat tool)
wscat -c ws://localhost:8000/ws/agent-progress/task-id-here
```

---

## 🎓 Learning Resources

### SwiftUI WebSocket
- [URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask)
- [Async/Await in SwiftUI](https://developer.apple.com/documentation/swift/concurrency)

### Backend Integration
- `/scan-image` endpoint documentation
- `/ws/agent-progress/{task_id}` WebSocket spec
- `/agent-task/{task_id}/result` result endpoint

---

## 💡 Tips & Best Practices

### Performance
- Use `@MainActor` for UI updates
- Cancel WebSocket on view disappear
- Implement reconnection logic
- Add timeout handling

### Error Handling
- Show user-friendly messages
- Provide retry functionality
- Log errors for debugging
- Graceful degradation to fast path

### Testing
- Mock WebSocket for unit tests
- Test all message types
- Verify state transitions
- Test error scenarios

### UI/UX
- Smooth progress animations
- Clear step descriptions
- Color-coded risk levels
- Expandable evidence details

---

**Need Help?**
- Check `STORY_8_11_IMPLEMENTATION_SUMMARY.md` for detailed docs
- Review `AgentProgressViewModelTests.swift` for usage examples
- Look at `AgentProgressView.swift` for UI patterns


