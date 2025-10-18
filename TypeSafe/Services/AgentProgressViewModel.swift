//
//  AgentProgressViewModel.swift
//  TypeSafe
//
//  Story 8.11: iOS App Agent Progress Display
//  ViewModel managing WebSocket connection for agent progress updates
//

import Foundation
import Combine

/// ViewModel managing agent progress updates via WebSocket
@MainActor
class AgentProgressViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current progress percentage (0-100)
    @Published var progress: Double = 0
    
    /// Current step being executed
    @Published var currentStep: ProgressStep?
    
    /// Collection of tool results
    @Published var toolResults: [ToolResultDisplay] = []
    
    /// Final analysis result (when complete)
    @Published var finalResult: AgentAnalysisResult?
    
    /// Error message (if any)
    @Published var errorMessage: String?
    
    /// Whether analysis is complete
    @Published var isComplete: Bool = false
    
    /// Whether analysis failed
    @Published var isFailed: Bool = false
    
    /// Connection status
    @Published var isConnected: Bool = false
    
    // MARK: - Private Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let taskId: String
    private let wsUrl: String
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var connectionRetryCount = 0
    private let maxRetries = 3
    
    // MARK: - Initialization
    
    /// Initialize with task ID and WebSocket URL
    /// - Parameters:
    ///   - taskId: Unique agent task identifier
    ///   - wsUrl: WebSocket URL for progress stream
    ///   - apiService: API service for fetching final result
    init(taskId: String, wsUrl: String, apiService: APIService = APIService()) {
        self.taskId = taskId
        self.wsUrl = wsUrl
        self.apiService = apiService
        
        print("AgentProgressViewModel initialized:")
        print("  - Task ID: \(taskId)")
        print("  - WebSocket URL: \(wsUrl)")
    }
    
    // MARK: - Connection Management
    
    /// Connect to WebSocket and start receiving progress updates
    func connect() {
        guard let url = URL(string: wsUrl) else {
            print("AgentProgressViewModel: Invalid WebSocket URL: \(wsUrl)")
            handleError("Invalid connection URL")
            return
        }
        
        print("AgentProgressViewModel: Connecting to WebSocket...")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        receiveMessage()
    }
    
    /// Disconnect from WebSocket
    func disconnect() {
        print("AgentProgressViewModel: Disconnecting from WebSocket...")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    /// Reconnect to WebSocket (retry on failure)
    private func reconnect() {
        guard connectionRetryCount < maxRetries else {
            print("AgentProgressViewModel: Max reconnection attempts reached")
            handleError("Connection lost. Please try again.")
            return
        }
        
        connectionRetryCount += 1
        print("AgentProgressViewModel: Reconnecting (attempt \(connectionRetryCount)/\(maxRetries))...")
        
        disconnect()
        
        // Wait 2 seconds before reconnecting
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            connect()
        }
    }
    
    // MARK: - Message Handling
    
    /// Receive and process WebSocket messages
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                Task { @MainActor in
                    await self.handleMessage(message)
                    self.receiveMessage() // Continue listening
                }
                
            case .failure(let error):
                Task { @MainActor in
                    print("AgentProgressViewModel: WebSocket error: \(error)")
                    self.reconnect()
                }
            }
        }
    }
    
    /// Handle incoming WebSocket message
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        guard case .string(let text) = message else {
            print("AgentProgressViewModel: Received non-string message")
            return
        }
        
        guard let data = text.data(using: .utf8) else {
            print("AgentProgressViewModel: Failed to convert message to data")
            return
        }
        
        do {
            let progressMessage = try JSONDecoder().decode(ProgressMessage.self, from: data)
            await processProgressMessage(progressMessage)
        } catch {
            print("AgentProgressViewModel: JSON decode error: \(error)")
            print("AgentProgressViewModel: Raw message: \(text)")
        }
    }
    
    /// Process decoded progress message
    private func processProgressMessage(_ message: ProgressMessage) async {
        // Skip heartbeat messages
        if message.isHeartbeat {
            print("AgentProgressViewModel: ❤️ Heartbeat received")
            return
        }
        
        print("AgentProgressViewModel: Progress update:")
        print("  - Step: \(message.step ?? "none")")
        print("  - Message: \(message.message)")
        print("  - Percent: \(message.percent)%")
        
        // Update progress
        progress = Double(message.percent)
        
        // Update current step
        if let step = message.step {
            currentStep = ProgressStep(
                step: step,
                message: message.message,
                timestamp: Date(),
                isComplete: message.isCompleted
            )
        }
        
        // Handle completion
        if message.isCompleted {
            print("AgentProgressViewModel: Task completed, fetching final result...")
            isComplete = true
            await fetchFinalResult()
            disconnect()
        }
        
        // Handle failure
        if message.isFailed {
            print("AgentProgressViewModel: Task failed")
            isFailed = true
            errorMessage = message.message
            disconnect()
        }
        
        // Extract tool result if applicable
        if let step = message.step, step.contains("scam_db") || step.contains("exa_search") ||
           step.contains("domain_reputation") || step.contains("phone_validator") {
            addToolResult(from: message)
        }
    }
    
    /// Add tool result to display list
    private func addToolResult(from message: ProgressMessage) {
        guard let step = message.step else { return }
        
        let toolResult = ToolResultDisplay(
            toolName: formatToolName(step),
            entityValue: "", // Will be populated from final result
            summary: message.message,
            icon: iconForStep(step),
            isSuccess: !(message.error ?? false),
            timestamp: Date()
        )
        
        toolResults.append(toolResult)
    }
    
    /// Fetch final analysis result from API
    private func fetchFinalResult() async {
        print("AgentProgressViewModel: Fetching final result for task \(taskId)...")
        
        // Construct the API endpoint URL
        let baseURL = apiService.baseURL ?? "https://portiered-penultimately-dilan.ngrok-free.dev"
        let endpoint = "\(baseURL)/agent-task/\(taskId)/result"
        
        guard let url = URL(string: endpoint) else {
            handleError("Invalid result URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                handleError("Failed to fetch result")
                return
            }
            
            let result = try JSONDecoder().decode(AgentAnalysisResult.self, from: data)
            
            print("AgentProgressViewModel: Final result received:")
            print("  - Risk: \(result.riskLevel)")
            print("  - Confidence: \(result.confidence)%")
            print("  - Evidence count: \(result.evidence.count)")
            
            finalResult = result
            
        } catch {
            print("AgentProgressViewModel: Error fetching final result: \(error)")
            handleError("Failed to fetch analysis result")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Handle error state
    private func handleError(_ message: String) {
        errorMessage = message
        isFailed = true
        isConnected = false
    }
    
    /// Format tool name for display
    private func formatToolName(_ step: String) -> String {
        switch step {
        case "scam_db":
            return "Scam Database"
        case "exa_search":
            return "Web Search"
        case "domain_reputation":
            return "Domain Check"
        case "phone_validator":
            return "Phone Validator"
        case "entity_extraction":
            return "Entity Extraction"
        case "reasoning":
            return "Agent Reasoning"
        default:
            return step.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    /// Get icon for step
    private func iconForStep(_ step: String) -> String {
        switch step {
        case "entity_extraction":
            return "doc.text.magnifyingglass"
        case "scam_db":
            return "exclamationmark.shield"
        case "exa_search":
            return "magnifyingglass"
        case "domain_reputation":
            return "globe"
        case "phone_validator":
            return "phone.fill"
        case "reasoning":
            return "brain"
        case "completed":
            return "checkmark.circle.fill"
        case "failed":
            return "xmark.circle.fill"
        default:
            return "circle"
        }
    }
    
    // MARK: - Public Methods
    
    /// Retry analysis (reconnect)
    func retry() {
        print("AgentProgressViewModel: Retrying analysis...")
        
        // Reset state
        progress = 0
        currentStep = nil
        toolResults = []
        finalResult = nil
        errorMessage = nil
        isComplete = false
        isFailed = false
        connectionRetryCount = 0
        
        // Reconnect
        connect()
    }
}

// MARK: - Extensions

extension AgentProgressViewModel {
    /// Computed property for baseURL access (for testing)
    var baseURL: String? {
        // Extract base URL from wsUrl
        guard let url = URL(string: wsUrl) else { return nil }
        
        let scheme = url.scheme ?? "https"
        let host = url.host ?? ""
        return "\(scheme)://\(host)"
    }
}

