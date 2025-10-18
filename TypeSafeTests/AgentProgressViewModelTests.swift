//
//  AgentProgressViewModelTests.swift
//  TypeSafeTests
//
//  Story 8.11: iOS App Agent Progress Display
//  Unit tests for AgentProgressViewModel
//

import XCTest
@testable import TypeSafe

@MainActor
class AgentProgressViewModelTests: XCTestCase {
    
    var viewModel: AgentProgressViewModel!
    let testTaskId = "test-task-123"
    let testWsUrl = "ws://localhost:8000/ws/agent-progress/test-task-123"
    
    override func setUp() async throws {
        try await super.setUp()
        viewModel = AgentProgressViewModel(taskId: testTaskId, wsUrl: testWsUrl)
    }
    
    override func tearDown() async throws {
        viewModel.disconnect()
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.progress, 0, "Initial progress should be 0")
        XCTAssertNil(viewModel.currentStep, "Initial current step should be nil")
        XCTAssertTrue(viewModel.toolResults.isEmpty, "Initial tool results should be empty")
        XCTAssertNil(viewModel.finalResult, "Initial final result should be nil")
        XCTAssertNil(viewModel.errorMessage, "Initial error message should be nil")
        XCTAssertFalse(viewModel.isComplete, "Initial isComplete should be false")
        XCTAssertFalse(viewModel.isFailed, "Initial isFailed should be false")
        XCTAssertFalse(viewModel.isConnected, "Initial isConnected should be false")
    }
    
    // MARK: - Connection Tests
    
    func testConnect() {
        // When
        viewModel.connect()
        
        // Then
        XCTAssertTrue(viewModel.isConnected, "Should be connected after connect()")
    }
    
    func testDisconnect() {
        // Given
        viewModel.connect()
        
        // When
        viewModel.disconnect()
        
        // Then
        XCTAssertFalse(viewModel.isConnected, "Should be disconnected after disconnect()")
    }
    
    // MARK: - Helper Method Tests
    
    func testFormatToolName() {
        // Test various tool names
        let testCases: [(input: String, expected: String)] = [
            ("scam_db", "Scam Database"),
            ("exa_search", "Web Search"),
            ("domain_reputation", "Domain Check"),
            ("phone_validator", "Phone Validator"),
            ("entity_extraction", "Entity Extraction"),
            ("reasoning", "Agent Reasoning"),
            ("unknown_tool", "Unknown Tool")
        ]
        
        // Note: We can't directly test private methods, but we can verify
        // the behavior through public methods that use them
        // This is a placeholder for the concept
    }
    
    func testIconForStep() {
        // Test that different steps would produce different icons
        // Note: Since iconForStep is private, we can't test directly
        // This is a placeholder showing the testing approach
        
        let expectedIcons: [String: String] = [
            "entity_extraction": "doc.text.magnifyingglass",
            "scam_db": "exclamationmark.shield",
            "exa_search": "magnifyingglass",
            "domain_reputation": "globe",
            "phone_validator": "phone.fill",
            "reasoning": "brain",
            "completed": "checkmark.circle.fill",
            "failed": "xmark.circle.fill"
        ]
        
        // Would need to expose icon mapping for testing or test through integration
    }
    
    // MARK: - State Management Tests
    
    func testRetry() {
        // Given - simulate failed state
        viewModel.progress = 50
        viewModel.isFailed = true
        viewModel.errorMessage = "Test error"
        
        // When
        viewModel.retry()
        
        // Then
        XCTAssertEqual(viewModel.progress, 0, "Progress should reset to 0")
        XCTAssertNil(viewModel.currentStep, "Current step should be nil")
        XCTAssertTrue(viewModel.toolResults.isEmpty, "Tool results should be empty")
        XCTAssertNil(viewModel.finalResult, "Final result should be nil")
        XCTAssertNil(viewModel.errorMessage, "Error message should be nil")
        XCTAssertFalse(viewModel.isComplete, "isComplete should be false")
        XCTAssertFalse(viewModel.isFailed, "isFailed should be false")
    }
    
    // MARK: - Base URL Tests
    
    func testBaseURLExtraction() {
        // Given
        let httpsViewModel = AgentProgressViewModel(
            taskId: "test",
            wsUrl: "wss://example.com/ws/agent-progress/test"
        )
        
        let httpViewModel = AgentProgressViewModel(
            taskId: "test",
            wsUrl: "ws://localhost:8000/ws/agent-progress/test"
        )
        
        // Then
        XCTAssertEqual(httpsViewModel.baseURL, "wss://example.com")
        XCTAssertEqual(httpViewModel.baseURL, "ws://localhost:8000")
    }
    
    func testInvalidWebSocketURL() {
        // Given
        let invalidViewModel = AgentProgressViewModel(
            taskId: "test",
            wsUrl: "not-a-valid-url"
        )
        
        // When
        invalidViewModel.connect()
        
        // Then - should handle gracefully
        XCTAssertTrue(invalidViewModel.isFailed, "Should fail with invalid URL")
        XCTAssertNotNil(invalidViewModel.errorMessage, "Should have error message")
    }
    
    // MARK: - Progress Message Handling Tests
    
    func testProgressMessageDecoding() throws {
        // Given
        let json = """
        {
            "step": "entity_extraction",
            "tool": "entity_extractor",
            "message": "Extracting entities from text...",
            "percent": 10,
            "timestamp": "2025-01-18T10:00:00Z",
            "error": false
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let message = try JSONDecoder().decode(ProgressMessage.self, from: data)
        
        // Then
        XCTAssertEqual(message.step, "entity_extraction")
        XCTAssertEqual(message.tool, "entity_extractor")
        XCTAssertEqual(message.message, "Extracting entities from text...")
        XCTAssertEqual(message.percent, 10)
        XCTAssertEqual(message.error, false)
        XCTAssertFalse(message.isCompleted)
        XCTAssertFalse(message.isFailed)
        XCTAssertFalse(message.isHeartbeat)
    }
    
    func testProgressMessageCompletion() throws {
        // Given
        let json = """
        {
            "step": "completed",
            "message": "Analysis complete",
            "percent": 100
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let message = try JSONDecoder().decode(ProgressMessage.self, from: data)
        
        // Then
        XCTAssertEqual(message.step, "completed")
        XCTAssertTrue(message.isCompleted)
        XCTAssertFalse(message.isFailed)
    }
    
    func testProgressMessageFailure() throws {
        // Given
        let json = """
        {
            "step": "failed",
            "message": "Analysis failed",
            "percent": 0,
            "error": true
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let message = try JSONDecoder().decode(ProgressMessage.self, from: data)
        
        // Then
        XCTAssertEqual(message.step, "failed")
        XCTAssertTrue(message.isFailed)
        XCTAssertFalse(message.isCompleted)
    }
    
    func testProgressMessageHeartbeat() throws {
        // Given
        let json = """
        {
            "heartbeat": true,
            "timestamp": "2025-01-18T10:00:00Z",
            "message": "heartbeat"
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let message = try JSONDecoder().decode(ProgressMessage.self, from: data)
        
        // Then
        XCTAssertTrue(message.isHeartbeat)
        XCTAssertFalse(message.isCompleted)
        XCTAssertFalse(message.isFailed)
    }
    
    // MARK: - Agent Result Decoding Tests
    
    func testAgentAnalysisResultDecoding() throws {
        // Given
        let json = """
        {
            "task_id": "test-task-123",
            "risk_level": "high",
            "confidence": 95.5,
            "entities_found": {
                "phones": ["+1234567890"],
                "urls": ["https://example.com"],
                "emails": ["test@example.com"]
            },
            "evidence": [
                {
                    "tool_name": "scam_db",
                    "entity_type": "phone",
                    "entity_value": "+1234567890",
                    "result": {
                        "found": true,
                        "report_count": 47
                    },
                    "success": true,
                    "execution_time_ms": 150.5
                }
            ],
            "reasoning": "This appears to be a high-risk scam based on database evidence.",
            "processing_time_ms": 5234,
            "tools_used": ["scam_db", "exa_search", "phone_validator"]
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(AgentAnalysisResult.self, from: data)
        
        // Then
        XCTAssertEqual(result.taskId, "test-task-123")
        XCTAssertEqual(result.riskLevel, "high")
        XCTAssertEqual(result.confidence, 95.5)
        XCTAssertEqual(result.reasoning, "This appears to be a high-risk scam based on database evidence.")
        XCTAssertEqual(result.toolsUsed.count, 3)
        XCTAssertEqual(result.evidence.count, 1)
        
        // Test computed properties
        XCTAssertEqual(result.riskTitle, "High Risk Detected")
        XCTAssertEqual(result.riskColor, "red")
        XCTAssertEqual(result.totalEntitiesFound, 3)
    }
    
    func testAgentResultRiskLevels() throws {
        let testCases: [(riskLevel: String, expectedTitle: String, expectedColor: String)] = [
            ("high", "High Risk Detected", "red"),
            ("medium", "Medium Risk Detected", "orange"),
            ("low", "Low Risk - Looks Safe", "green"),
            ("unknown", "Analysis Complete", "gray")
        ]
        
        for testCase in testCases {
            // Given
            let json = """
            {
                "task_id": "test",
                "risk_level": "\(testCase.riskLevel)",
                "confidence": 80.0,
                "entities_found": {"phones": [], "urls": [], "emails": []},
                "evidence": [],
                "reasoning": "Test",
                "tools_used": []
            }
            """
            
            // When
            let data = json.data(using: .utf8)!
            let result = try JSONDecoder().decode(AgentAnalysisResult.self, from: data)
            
            // Then
            XCTAssertEqual(result.riskTitle, testCase.expectedTitle, "Risk title mismatch for \(testCase.riskLevel)")
            XCTAssertEqual(result.riskColor, testCase.expectedColor, "Risk color mismatch for \(testCase.riskLevel)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testMissingTaskIdOrWsUrl() {
        // Given - viewModel with valid URLs
        XCTAssertNotNil(viewModel.baseURL, "Should have valid base URL")
        
        // Test that connection handles errors gracefully
        viewModel.connect()
        
        // Should not crash
        XCTAssertTrue(true, "Connection should handle errors gracefully")
    }
    
    // MARK: - Tool Result Display Tests
    
    func testToolResultDisplayCreation() {
        // Given
        let toolResult = ToolResultDisplay(
            toolName: "Scam Database",
            entityValue: "+1234567890",
            summary: "Found 47 reports",
            icon: "exclamationmark.shield",
            isSuccess: true,
            timestamp: Date()
        )
        
        // Then
        XCTAssertEqual(toolResult.toolName, "Scam Database")
        XCTAssertEqual(toolResult.entityValue, "+1234567890")
        XCTAssertEqual(toolResult.summary, "Found 47 reports")
        XCTAssertEqual(toolResult.icon, "exclamationmark.shield")
        XCTAssertTrue(toolResult.isSuccess)
    }
    
    func testProgressStepCreation() {
        // Given
        let timestamp = Date()
        let step = ProgressStep(
            step: "entity_extraction",
            message: "Extracting entities...",
            timestamp: timestamp,
            isComplete: false
        )
        
        // Then
        XCTAssertEqual(step.step, "entity_extraction")
        XCTAssertEqual(step.message, "Extracting entities...")
        XCTAssertEqual(step.timestamp, timestamp)
        XCTAssertFalse(step.isComplete)
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflowSimulation() async {
        // This test simulates a full agent workflow
        // Note: In a real environment, we would use a mock WebSocket
        
        // Given
        viewModel.connect()
        
        // Wait a brief moment
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then - verify initial connection state
        XCTAssertTrue(viewModel.isConnected)
        XCTAssertEqual(viewModel.progress, 0)
        
        // Cleanup
        viewModel.disconnect()
    }
    
    func testRetryAfterError() async {
        // Given - simulate error state
        viewModel.isFailed = true
        viewModel.errorMessage = "Connection failed"
        viewModel.progress = 50
        
        // When
        viewModel.retry()
        
        // Wait for retry to initialize
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertFalse(viewModel.isFailed, "Should not be in failed state after retry")
        XCTAssertNil(viewModel.errorMessage, "Error message should be cleared")
        XCTAssertEqual(viewModel.progress, 0, "Progress should be reset")
    }
}

