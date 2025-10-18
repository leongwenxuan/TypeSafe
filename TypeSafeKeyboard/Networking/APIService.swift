//
//  APIService.swift
//  TypeSafeKeyboard
//
//  Story 2.3: Backend API Integration
//  High-level API wrapper for backend communication
//

import Foundation

/// High-level service for communicating with TypeSafe backend
class APIService {
    
    // MARK: - Properties
    
    /// Network client for making HTTP requests
    private let networkClient: NetworkClient
    
    /// Session manager for anonymous session IDs
    private let sessionManager: SessionManager
    
    /// Backend base URL (configurable for dev/prod)
    /// For MVP: hardcoded, will be configurable in future stories
    private let baseURL: String
    
    // Performance optimization properties (Story 2.9)
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    private let maxFailures: Int = 5
    private let circuitBreakerTimeout: TimeInterval = 60.0 // 1 minute
    private let requestQueue = DispatchQueue(label: "com.typesafe.api", qos: .userInitiated)
    
    // MARK: - Initialization
    
    /// Initializes API service with dependencies
    /// - Parameters:
    ///   - networkClient: HTTP client implementation (default: URLSessionNetworkClient)
    ///   - sessionManager: Session ID manager (default: SessionManager)
    ///   - baseURL: Backend URL (default: placeholder, override for testing)
    init(
        networkClient: NetworkClient = URLSessionNetworkClient(),
        sessionManager: SessionManager = SessionManager(),
        baseURL: String = "https://portiered-penultimately-dilan.ngrok-free.dev"  // ngrok tunnel to localhost:8000
    ) {
        self.networkClient = networkClient
        self.sessionManager = sessionManager
        self.baseURL = baseURL
    }
    
    // MARK: - Public Methods
    
    /// Sends text snippet to backend for scam analysis
    /// - Parameters:
    ///   - text: Text content to analyze (max 300 chars)
    ///   - completion: Result handler with AnalyzeTextResponse or Error
    func analyzeText(
        text: String,
        completion: @escaping (Result<AnalyzeTextResponse, Error>) -> Void
    ) {
        // Performance optimization: Circuit breaker pattern (Story 2.9)
        if isCircuitBreakerOpen() {
            print("APIService: Circuit breaker open - failing fast")
            DispatchQueue.main.async {
                completion(.failure(APIError.circuitBreakerOpen))
            }
            return
        }
        
        // Execute on background queue to avoid blocking UI (Story 2.9)
        requestQueue.async { [weak self] in
            self?.performAnalyzeTextRequest(text: text, completion: completion)
        }
    }
    
    /// Performs the actual API request (internal method)
    private func performAnalyzeTextRequest(
        text: String,
        completion: @escaping (Result<AnalyzeTextResponse, Error>) -> Void
    ) {
        // Use fixed session ID for now (to avoid database foreign key issues)
        let sessionID = "550e8400-e29b-41d4-a716-446655440000"
        
        // Get app bundle ID (for MVP, use "unknown")
        let appBundle = "unknown"  // TODO: Implement actual detection in future story
        
        // Construct request body
        let request = AnalyzeTextRequest(
            session_id: sessionID,
            app_bundle: appBundle,
            text: text
        )
        
        // Convert to dictionary for NetworkClient
        let body: [String: Any] = [
            "session_id": request.session_id,
            "app_bundle": request.app_bundle,
            "text": request.text
        ]
        
        // Construct endpoint URL
        let endpoint = "\(baseURL)/analyze-text"
        
        print("APIService: Sending request to \(endpoint)")
        print("  - Session ID: \(sessionID)")
        print("  - Text length: \(text.count) chars")
        
        // TEMPORARY: Mock response for testing while backend is being set up
        if baseURL.contains("10.37.3.51") {
            print("APIService: Using mock response for testing")
            let mockResponse = AnalyzeTextResponse(
                risk_level: "low",
                confidence: 0.95,
                category: "safe",
                explanation: "Mock response - normal text",
                ts: nil  // Optional timestamp
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                completion(.success(mockResponse))
            }
            return
        }
        
        // Make API call
        networkClient.post(url: endpoint, body: body) { [weak self] result in
            switch result {
            case .success(let data):
                // Parse JSON response
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(AnalyzeTextResponse.self, from: data)
                    
                    print("APIService: Received response")
                    print("  - Risk level: \(response.risk_level)")
                    print("  - Confidence: \(response.confidence)")
                    print("  - Category: \(response.category)")
                    
                    // Performance optimization: Reset failure count on success (Story 2.9)
                    self?.recordSuccess()
                    
                    // Invoke success callback on main queue
                    DispatchQueue.main.async {
                        completion(.success(response))
                    }
                } catch {
                    print("APIService: JSON parsing failed: \(error.localizedDescription)")
                    
                    // Performance optimization: Record failure (Story 2.9)
                    self?.recordFailure()
                    
                    DispatchQueue.main.async {
                        completion(.failure(APIError.parsingFailed(error)))
                    }
                }
                
            case .failure(let error):
                print("APIService: Request failed: \(error.localizedDescription)")
                
                // Performance optimization: Record failure (Story 2.9)
                self?.recordFailure()
                
                // Invoke error callback on main queue
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Circuit Breaker Implementation (Story 2.9)
    
    /// Checks if circuit breaker is open (failing fast)
    private func isCircuitBreakerOpen() -> Bool {
        guard failureCount >= maxFailures else { return false }
        
        // Check if timeout has passed
        if let lastFailure = lastFailureTime,
           Date().timeIntervalSince(lastFailure) > circuitBreakerTimeout {
            // Reset circuit breaker after timeout
            failureCount = 0
            lastFailureTime = nil
            print("APIService: Circuit breaker reset after timeout")
            return false
        }
        
        return failureCount >= maxFailures
    }
    
    /// Records a successful API call
    private func recordSuccess() {
        failureCount = 0
        lastFailureTime = nil
    }
    
    /// Records a failed API call
    private func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= maxFailures {
            print("APIService: Circuit breaker opened after \(failureCount) failures")
        }
    }
}

// MARK: - API Errors

/// Custom errors specific to API operations
enum APIError: Error, LocalizedError {
    case parsingFailed(Error)
    case circuitBreakerOpen
    
    var errorDescription: String? {
        switch self {
        case .parsingFailed(let error):
            return "Failed to parse API response: \(error.localizedDescription)"
        case .circuitBreakerOpen:
            return "Service temporarily unavailable - too many recent failures"
        }
    }
}

