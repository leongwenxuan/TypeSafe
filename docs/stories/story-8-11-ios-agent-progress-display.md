# Story 8.11: iOS App Agent Progress Display

**Story ID:** 8.11  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P1 (Essential UX)  
**Effort:** 16 hours  
**Assignee:** iOS Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As a** companion app user,  
**I want** to see detailed agent progress with tool executions,  
**so that** I understand how the agent is investigating my screenshot.

---

## Description

Creates beautiful, transparent UI showing agent investigation in real-time:
- Step-by-step progress
- Tool-by-tool updates
- Evidence as it's collected
- Final verdict with full breakdown

**UI Experience:**
```
[Scanning Screenshot]
━━━━━━━━━━━━━━━━░░░░ 60%

✓ Entities Extracted: 1 phone, 1 URL
🔄 Checking Scam Database...
✓ Found in database: 47 reports
🔄 Searching web for complaints...
✓ Found 12 web complaints
⏳ Validating phone number...
```

---

## Acceptance Criteria

### UI Components
- [ ] 1. New `AgentProgressView` SwiftUI component
- [ ] 2. Displays current step with icon and message
- [ ] 3. Progress bar (0-100%) with smooth animations
- [ ] 4. Tool results list that updates as tools complete
- [ ] 5. Final result card with risk level, confidence, evidence breakdown

### WebSocket Integration
- [ ] 6. `AgentProgressViewModel` manages WebSocket connection
- [ ] 7. Connects to `ws_url` returned from scan API
- [ ] 8. Parses JSON progress messages
- [ ] 9. Updates UI in real-time as messages arrive
- [ ] 10. Handles reconnection if connection drops

### Progress States
- [ ] 11. Shows different icons for each step type
- [ ] 12. Animates progress bar smoothly
- [ ] 13. Displays tool results with checkmarks/warnings
- [ ] 14. Shows final verdict with appropriate color (red/yellow/green)

### Evidence Display
- [ ] 15. Evidence breakdown section: "What the agent found"
- [ ] 16. Lists each tool's findings clearly
- [ ] 17. Shows agent reasoning/explanation
- [ ] 18. Allows expanding individual evidence items

### Error Handling
- [ ] 19. Shows user-friendly error if analysis fails
- [ ] 20. Timeout message if takes > 60 seconds
- [ ] 21. Retry button on errors
- [ ] 22. Graceful fallback to simple result if agent unavailable

### Testing
- [ ] 23. Unit tests for ViewModel logic
- [ ] 24. UI tests for progress animations
- [ ] 25. Manual testing with real agent scans

---

## Technical Implementation

**`AgentProgressView.swift`:**

```swift
import SwiftUI

struct AgentProgressView: View {
    @StateObject private var viewModel: AgentProgressViewModel
    
    init(taskId: String, wsUrl: String) {
        _viewModel = StateObject(wrappedValue: AgentProgressViewModel(taskId: taskId, wsUrl: wsUrl))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Agent Analyzing Screenshot")
                .font(.headline)
            
            // Progress Bar
            ProgressView(value: viewModel.progress, total: 100)
                .progressViewStyle(LinearProgressViewStyle())
                .animation(.easeInOut, value: viewModel.progress)
            
            Text("\(Int(viewModel.progress))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Current Step
            if let currentStep = viewModel.currentStep {
                HStack {
                    stepIcon(for: currentStep.step)
                    Text(currentStep.message)
                        .font(.body)
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Tool Results
            if !viewModel.toolResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Evidence Collected:")
                        .font(.subheadline)
                        .bold()
                    
                    ForEach(viewModel.toolResults) { result in
                        ToolResultRow(result: result)
                    }
                }
            }
            
            // Final Result
            if let finalResult = viewModel.finalResult {
                FinalVerdictCard(result: finalResult)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
    
    @ViewBuilder
    private func stepIcon(for step: String) -> some View {
        switch step {
        case "entity_extraction":
            Image(systemName: "doc.text.magnifyingglass")
        case "scam_db", "exa_search", "domain_reputation", "phone_validator":
            Image(systemName: "magnifyingglass")
        case "reasoning":
            Image(systemName: "brain")
        case "completed":
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case "failed":
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        default:
            Image(systemName: "circle")
        }
    }
}

class AgentProgressViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var currentStep: ProgressStep?
    @Published var toolResults: [ToolResult] = []
    @Published var finalResult: AgentResult?
    
    private var webSocket: URLSessionWebSocketTask?
    private let taskId: String
    private let wsUrl: String
    
    init(taskId: String, wsUrl: String) {
        self.taskId = taskId
        self.wsUrl = wsUrl
    }
    
    func connect() {
        guard let url = URL(string: wsUrl) else { return }
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue listening
            case .failure(let error):
                print("WebSocket error: \(error)")
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONDecoder().decode(ProgressMessage.self, from: data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.progress = Double(json.percent)
            self.currentStep = ProgressStep(step: json.step ?? "", message: json.message)
            
            // Handle completion
            if json.step == "completed" {
                // Fetch final result
                self.fetchFinalResult()
            }
        }
    }
    
    private func fetchFinalResult() {
        // Call API to get final result
        // Implementation...
    }
}

struct ProgressMessage: Codable {
    let step: String?
    let message: String
    let percent: Int
}

struct ProgressStep {
    let step: String
    let message: String
}

struct ToolResult: Identifiable {
    let id = UUID()
    let toolName: String
    let result: String
    let icon: String
}

struct AgentResult {
    let riskLevel: String
    let confidence: Double
    let explanation: String
    let evidence: [String]
}
```

---

## Success Criteria

- [ ] All 25 acceptance criteria met
- [ ] UI updates smoothly in real-time
- [ ] WebSocket connection stable
- [ ] Evidence display clear and informative
- [ ] All tests passing

---

**Estimated Effort:** 16 hours  
**Sprint:** Week 10, Days 3-4

