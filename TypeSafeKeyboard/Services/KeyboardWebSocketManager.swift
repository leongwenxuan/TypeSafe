//
//  KeyboardWebSocketManager.swift
//  TypeSafeKeyboard
//
//  WebSocket manager for agent progress updates in keyboard extension
//

import Foundation

/// Manages WebSocket connection for agent progress in keyboard
class KeyboardWebSocketManager {
    
    // MARK: - Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let wsUrl: String
    private let taskId: String
    private var isConnected: Bool = false
    private var isFetchingFinalResult: Bool = false  // Flag to ignore WS errors during HTTP fetch
    private var progressCallback: ((AgentProgressUpdate) -> Void)?
    private var completionCallback: ((AgentFinalResult) -> Void)?
    private var errorCallback: ((Error) -> Void)?
    
    // MARK: - Initialization
    
    init(wsUrl: String, taskId: String) {
        self.wsUrl = wsUrl
        self.taskId = taskId
    }
    
    // MARK: - Public Methods
    
    /// Connect to WebSocket and listen for updates
    func connect(
        onProgress: @escaping (AgentProgressUpdate) -> Void,
        onCompletion: @escaping (AgentFinalResult) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.progressCallback = onProgress
        self.completionCallback = onCompletion
        self.errorCallback = onError
        
        guard let url = URL(string: wsUrl) else {
            print("🔴 KeyboardWebSocketManager: Invalid WebSocket URL: \(wsUrl)")
            onError(WebSocketError.invalidURL)
            return
        }
        
        print("🟡 KeyboardWebSocketManager: Connecting to \(wsUrl)")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        
        print("🟢 KeyboardWebSocketManager: Connected")
        
        // Start receiving messages
        receiveMessage()
    }
    
    /// Disconnect from WebSocket
    func disconnect() {
        print("🟡 KeyboardWebSocketManager: Disconnecting...")
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    // MARK: - Private Methods
    
    private func receiveMessage() {
        guard isConnected else { return }
        
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving
                self.receiveMessage()
                
            case .failure(let error):
                print("🔴 KeyboardWebSocketManager: Receive error - \(error)")
                
                // Ignore errors if we're already fetching the final result
                if self.isFetchingFinalResult {
                    print("🟡 KeyboardWebSocketManager: Ignoring WS error - already fetching final result")
                    return
                }
                
                self.errorCallback?(error)
                self.disconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        print("🟡 KeyboardWebSocketManager: Received message")
        
        guard let data = text.data(using: .utf8) else {
            print("🔴 KeyboardWebSocketManager: Failed to convert message to data")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            
            // Try to decode as progress update
            if let progress = try? decoder.decode(AgentProgressUpdate.self, from: data) {
                print("🟢 KeyboardWebSocketManager: Progress update - \(progress.percent)% - \(progress.message)")
                print("   Step: \(progress.step ?? "nil")")
                
                // Dispatch to main thread for UI updates
                DispatchQueue.main.async { [weak self] in
                    self?.progressCallback?(progress)
                }
                
                // Check if task completed (check both step and percent)
                if progress.step == "completed" || progress.percent >= 100 {
                    print("🟡 KeyboardWebSocketManager: Task completed (step=\(progress.step ?? "nil"), percent=\(progress.percent)), fetching final result...")
                    isFetchingFinalResult = true  // Ignore WebSocket errors now
                    fetchFinalResult()
                }
                return
            }
            
            // Try to decode as final result (in case backend sends it directly)
            if let result = try? decoder.decode(AgentFinalResult.self, from: data) {
                print("🟢 KeyboardWebSocketManager: Final result - risk=\(result.riskLevel)")
                
                // Dispatch to main thread for UI updates
                DispatchQueue.main.async { [weak self] in
                    self?.completionCallback?(result)
                }
                disconnect()
                return
            }
            
            print("🔴 KeyboardWebSocketManager: Unknown message format: \(text)")
            
        } catch {
            print("🔴 KeyboardWebSocketManager: Decoding error - \(error)")
        }
    }
    
    private func fetchFinalResult() {
        // Extract base URL from WebSocket URL
        guard let wsURL = URL(string: wsUrl) else {
            print("🔴 KeyboardWebSocketManager: Invalid WebSocket URL for parsing")
            return
        }
        let baseURL = "\(wsURL.scheme == "wss" ? "https" : "http")://\(wsURL.host ?? "")\(wsURL.port.map { ":\($0)" } ?? "")"
        let resultURL = "\(baseURL)/agent-task/\(taskId)/result"
        
        print("🟡 KeyboardWebSocketManager: Fetching result from \(resultURL)")
        print("   Base URL: \(baseURL)")
        print("   Task ID: \(taskId)")
        
        guard let url = URL(string: resultURL) else {
            print("🔴 KeyboardWebSocketManager: Invalid result URL")
            DispatchQueue.main.async { [weak self] in
                self?.errorCallback?(WebSocketError.invalidURL)
            }
            return
        }
        
        // Use STRONG self to keep manager alive during HTTP request
        let task = URLSession.shared.dataTask(with: url) { [self] data, response, error in
            
            if let error = error {
                print("🔴 KeyboardWebSocketManager: Failed to fetch result - \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.errorCallback?(error)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🟡 KeyboardWebSocketManager: HTTP status code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("🔴 KeyboardWebSocketManager: No data received")
                DispatchQueue.main.async { [weak self] in
                    self?.errorCallback?(WebSocketError.connectionFailed)
                }
                return
            }
            
            print("🟡 KeyboardWebSocketManager: Received \(data.count) bytes")
            
            // Debug: Print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🟡 KeyboardWebSocketManager: Raw response: \(jsonString.prefix(200))")
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(AgentFinalResult.self, from: data)
                print("🟢 KeyboardWebSocketManager: Final result decoded successfully")
                print("   Risk: \(result.riskLevel)")
                print("   Confidence: \(result.confidence)")
                print("   Category: \(result.category)")
                
                // Dispatch to main thread for UI updates
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("🟢 KeyboardWebSocketManager: Calling completion callback...")
                    self.completionCallback?(result)
                    
                    // Disconnect AFTER callback completes
                    self.disconnect()
                }
            } catch {
                print("🔴 KeyboardWebSocketManager: Failed to decode result - \(error)")
                print("   Error details: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.errorCallback?(error)
                }
            }
        }
        
        print("🟡 KeyboardWebSocketManager: Starting HTTP request...")
        task.resume()
    }
}

// MARK: - Models

/// Agent progress update
struct AgentProgressUpdate: Codable {
    let message: String
    let percent: Int  // Backend sends "percent", not "progress"
    let step: String?
    let tool: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case percent
        case step
        case tool
    }
    
    /// Progress value (0-100)
    var progress: Int {
        return percent
    }
}

/// Final agent analysis result
struct AgentFinalResult: Codable {
    let riskLevel: String
    let confidence: Double
    let category: String
    let explanation: String
    let evidence: [AgentEvidence]?
    
    enum CodingKeys: String, CodingKey {
        case riskLevel = "risk_level"
        case confidence
        case category
        case explanation
        case evidence
    }
}

/// Agent evidence item
struct AgentEvidence: Codable {
    let toolName: String
    let entityType: String
    let entityValue: String
    let success: Bool
    
    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case entityType = "entity_type"
        case entityValue = "entity_value"
        case success
    }
}

/// WebSocket errors
enum WebSocketError: Error, LocalizedError {
    case invalidURL
    case connectionFailed
    case disconnected
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .connectionFailed:
            return "Failed to connect to server"
        case .disconnected:
            return "Connection closed unexpectedly"
        }
    }
}

