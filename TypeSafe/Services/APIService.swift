//
//  APIService.swift
//  TypeSafe
//
//  Story 3.4: Backend Integration (Scan Image API)
//  API client for companion app to communicate with TypeSafe backend
//

import Foundation
import UIKit
import Combine

/// High-level service for communicating with TypeSafe backend from companion app
class APIService: ObservableObject {
    
    // MARK: - Properties
    
    /// Backend base URL (configurable for dev/prod)
    let baseURL: String
    
    /// URLSession configured with 4s timeout as per architecture requirements
    private let session: URLSession
    
    /// Session manager for anonymous session IDs
    private let sessionManager: SessionManager
    
    /// Settings manager for privacy controls (Story 3.8)
    private let settingsManager: SettingsManager
    
    // MARK: - Initialization
    
    /// Initializes API service with dependencies
    /// - Parameters:
    ///   - baseURL: Backend URL (default: ngrok tunnel for development)
    ///   - sessionManager: Session ID manager (default: SessionManager)
    ///   - settingsManager: Settings manager for privacy controls (default: SettingsManager.shared)
    init(
        baseURL: String = "https://portiered-penultimately-dilan.ngrok-free.dev",
        sessionManager: SessionManager = SessionManager(),
        settingsManager: SettingsManager = SettingsManager.shared
    ) {
        self.baseURL = baseURL
        self.sessionManager = sessionManager
        self.settingsManager = settingsManager
        
        // Configure URLSession with 4-second timeout as per architecture requirements
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 4.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// Sends OCR text and optional image to backend for scam analysis
    /// - Parameters:
    ///   - ocrText: Extracted text from image
    ///   - image: Optional screenshot image (sent only if user opted in)
    ///   - completion: Result handler with ScanImageResponse or Error
    func scanImage(
        ocrText: String,
        image: UIImage? = nil,
        completion: @escaping (Result<ScanImageResponse, Error>) -> Void
    ) {
        // Get or create session ID
        let sessionID = sessionManager.getOrCreateSessionID()
        
        // Check privacy setting for image upload (Story 3.8: Use SettingsManager)
        let shouldIncludeImage = settingsManager.settings.sendScreenshotImages && image != nil
        
        print("APIService: Scanning image")
        print("  - Session ID: \(sessionID)")
        print("  - OCR text length: \(ocrText.count) chars")
        print("  - Include image: \(shouldIncludeImage)")
        
        // Construct endpoint URL
        let endpoint = "\(baseURL)/scan-image"
        
        // Create multipart form data request
        createMultipartRequest(
            url: endpoint,
            sessionID: sessionID,
            ocrText: ocrText,
            image: shouldIncludeImage ? image : nil
        ) { [weak self] result in
            switch result {
            case .success(let request):
                self?.executeRequest(request: request, completion: completion)
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Retry the last scan operation
    /// - Parameter completion: Result handler with ScanImageResponse or Error
    func retryScan(
        ocrText: String,
        image: UIImage? = nil,
        completion: @escaping (Result<ScanImageResponse, Error>) -> Void
    ) {
        print("APIService: Retrying scan")
        scanImage(ocrText: ocrText, image: image, completion: completion)
    }
    
    // MARK: - Private Methods
    
    /// Creates a multipart form data request for the scan-image endpoint
    private func createMultipartRequest(
        url: String,
        sessionID: String,
        ocrText: String,
        image: UIImage?,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        guard let endpoint = URL(string: url) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Create request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        
        // Generate boundary for multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart body
        var body = Data()
        
        // Add session_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"session_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sessionID)\r\n".data(using: .utf8)!)
        
        // Add ocr_text field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"ocr_text\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(ocrText)\r\n".data(using: .utf8)!)
        
        // Add image field if provided and privacy setting allows
        if let image = image {
            // Convert image to JPEG data
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"image\"; filename=\"screenshot.jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        completion(.success(request))
    }
    
    /// Executes the HTTP request and handles the response
    private func executeRequest(
        request: URLRequest,
        completion: @escaping (Result<ScanImageResponse, Error>) -> Void
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                print("APIService: Network error: \(error.localizedDescription)")
                
                // Check for timeout
                if (error as NSError).code == NSURLErrorTimedOut {
                    print("APIService: Request timed out after 4.0s")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.timeout))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.networkError(error)))
                    }
                }
                return
            }
            
            // Handle HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("APIService: HTTP status code: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - parse response
                    if let data = data {
                        self.parseResponse(data: data, completion: completion)
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(APIError.emptyResponse))
                        }
                    }
                case 400:
                    print("APIService: Bad request (400)")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.badRequest))
                    }
                case 429:
                    print("APIService: Rate limited (429)")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.rateLimited))
                    }
                case 500...599:
                    print("APIService: Server error (\(httpResponse.statusCode))")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.serverError(httpResponse.statusCode)))
                    }
                default:
                    print("APIService: Unexpected status code (\(httpResponse.statusCode))")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.httpError(httpResponse.statusCode)))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(APIError.invalidResponse))
                }
            }
        }
        
        task.resume()
    }
    
    /// Parses the JSON response from the backend
    private func parseResponse(
        data: Data,
        completion: @escaping (Result<ScanImageResponse, Error>) -> Void
    ) {
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(ScanImageResponse.self, from: data)
            
            print("APIService: Received response")
            print("  - Type: \(response.type)")
            
            if response.isAgentResponse {
                // Agent path response
                print("  - Task ID: \(response.task_id ?? "none")")
                print("  - WebSocket URL: \(response.ws_url ?? "none")")
                print("  - Entities found: \(response.entities_found ?? 0)")
            } else {
                // Simple fast path response
                print("  - Risk level: \(response.risk_level ?? "unknown")")
                print("  - Confidence: \(response.confidence ?? 0)")
                print("  - Category: \(response.category ?? "unknown")")
                
                // Update shared storage for keyboard sync (Story 3.7)
                // Only for simple responses - agent responses don't have immediate results
                updateSharedScanResult(response)
            }
            
            DispatchQueue.main.async {
                completion(.success(response))
            }
        } catch {
            print("APIService: JSON parsing failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(APIError.parsingFailed(error)))
            }
        }
    }
    
    /// Updates shared storage with scan result for keyboard sync
    /// - Parameter response: Scan result from backend
    private func updateSharedScanResult(_ response: ScanImageResponse) {
        // Only update for simple responses with valid data
        guard let riskLevel = response.risk_level,
              let category = response.category,
              let confidence = response.confidence else {
            print("APIService: Skipping shared storage update - missing required fields")
            return
        }
        
        // Create SharedScanResult with privacy-safe data
        let sharedResult = SharedScanResult(
            riskLevel: riskLevel,
            category: formatCategoryForDisplay(category),
            confidence: confidence
        )
        
        // Write to shared storage (non-blocking)
        DispatchQueue.global(qos: .utility).async {
            let success = SharedStorageManager.shared.setLatestScanResult(sharedResult)
            if success {
                print("APIService: Updated shared storage for keyboard sync")
                print("  - Scan ID: \(sharedResult.scanId)")
                print("  - Risk: \(sharedResult.riskLevel)")
                print("  - Category: \(sharedResult.category)")
            } else {
                print("APIService: Failed to update shared storage")
            }
        }
    }
    
    /// Formats backend category for user-friendly display
    /// - Parameter category: Backend category (e.g., "otp_phishing")
    /// - Returns: Display-friendly category (e.g., "OTP Phishing")
    private func formatCategoryForDisplay(_ category: String) -> String {
        // Convert snake_case to Title Case
        return category
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Session Manager

/// Manages anonymous session IDs for API requests
class SessionManager {
    
    private let sessionIDKey = "TypeSafe.SessionID"
    
    /// Gets existing session ID or creates a new one
    /// - Returns: Anonymous UUID string for session identification
    func getOrCreateSessionID() -> String {
        if let existingID = UserDefaults.standard.string(forKey: sessionIDKey) {
            return existingID
        }
        
        // Create new anonymous session ID
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: sessionIDKey)
        
        print("SessionManager: Created new session ID: \(newID)")
        return newID
    }
    
    /// Resets the session ID (creates a new anonymous session)
    func resetSession() {
        UserDefaults.standard.removeObject(forKey: sessionIDKey)
        print("SessionManager: Session reset")
    }
}

// MARK: - Privacy Manager

/// Manages privacy settings for image upload
class PrivacyManager: ObservableObject {
    
    private let imageUploadKey = "TypeSafe.ImageUploadEnabled"
    
    /// Whether image upload is enabled (default: false for privacy-first approach)
    @Published var isImageUploadEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isImageUploadEnabled, forKey: imageUploadKey)
            print("PrivacyManager: Image upload setting changed to: \(isImageUploadEnabled)")
        }
    }
    
    init() {
        // Default to false (privacy-first approach)
        self.isImageUploadEnabled = UserDefaults.standard.bool(forKey: imageUploadKey)
    }
    
    /// Enables image upload with user consent
    func enableImageUpload() {
        isImageUploadEnabled = true
    }
    
    /// Disables image upload
    func disableImageUpload() {
        isImageUploadEnabled = false
    }
}

// MARK: - Response Models

/// Response payload from POST /scan-image endpoint
/// Can be either a simple (fast path) response or an agent response
struct ScanImageResponse: Codable {
    /// Response type: "simple" or "agent"
    let type: String
    
    // Fast path fields (type == "simple")
    /// Risk classification: "low", "medium", or "high"
    let risk_level: String?
    
    /// Confidence score from 0.0 to 1.0
    let confidence: Double?
    
    /// Scam category: "otp_phishing", "payment_scam", "impersonation", or "unknown"
    let category: String?
    
    /// Human-friendly explanation (one-liner)
    let explanation: String?
    
    /// Optional ISO-8601 timestamp from backend
    let ts: String?
    
    // Agent path fields (type == "agent")
    /// Agent task ID for progress tracking
    let task_id: String?
    
    /// WebSocket URL for progress updates
    let ws_url: String?
    
    /// Estimated processing time
    let estimated_time: String?
    
    /// Number of entities found (for agent path)
    let entities_found: Int?
    
    /// Whether this is an agent response
    var isAgentResponse: Bool {
        return type == "agent"
    }
    
    /// Whether this is a simple fast path response
    var isSimpleResponse: Bool {
        return type == "simple"
    }
}

// MARK: - API Errors

/// Custom errors specific to API operations
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case timeout
    case badRequest
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case invalidResponse
    case emptyResponse
    case parsingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out after 4.0 seconds"
        case .badRequest:
            return "Bad request - please check your input"
        case .rateLimited:
            return "Too many requests - please try again later"
        case .serverError(let code):
            return "Server error (\(code)) - please try again"
        case .httpError(let code):
            return "HTTP error (\(code))"
        case .invalidResponse:
            return "Invalid response from server"
        case .emptyResponse:
            return "Empty response from server"
        case .parsingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
    
    /// User-friendly error message for display in UI
    var userFriendlyMessage: String {
        switch self {
        case .timeout:
            return "The request took too long. Please check your internet connection and try again."
        case .networkError:
            return "Network connection failed. Please check your internet connection."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError, .httpError, .invalidResponse, .emptyResponse:
            return "Server is temporarily unavailable. Please try again later."
        case .badRequest:
            return "There was an issue with your request. Please try again."
        case .parsingFailed, .invalidURL:
            return "An unexpected error occurred. Please try again."
        }
    }
}
