//
//  NetworkClient.swift
//  TypeSafeKeyboard
//
//  Story 2.3: Backend API Integration
//  Protocol-based HTTP client for testability
//

import Foundation

/// Protocol for HTTP networking - enables mocking in tests
protocol NetworkClient {
    /// Performs a POST request with JSON body
    /// - Parameters:
    ///   - url: Full URL string to send request to
    ///   - body: Dictionary to encode as JSON body
    ///   - completion: Result handler with Data on success or Error on failure
    func post(url: String, body: [String: Any], completion: @escaping (Result<Data, Error>) -> Void)
}

/// Concrete implementation of NetworkClient using URLSession
class URLSessionNetworkClient: NetworkClient {
    
    // MARK: - Properties
    
    /// URLSession configured with 5s timeout
    private let session: URLSession
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0
        self.session = URLSession(configuration: config)
    }
    
    /// Custom initializer for testing with specific session
    init(session: URLSession) {
        self.session = session
    }
    
    // MARK: - NetworkClient Protocol
    
    func post(url: String, body: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        // Validate URL
        guard let endpoint = URL(string: url) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode body to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
        } catch {
            completion(.failure(NetworkError.encodingFailed(error)))
            return
        }
        
        // Execute request
        let task = session.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                // Check for timeout
                if (error as NSError).code == NSURLErrorTimedOut {
                    print("NetworkClient: Request timed out after 5.0s")
                    completion(.failure(NetworkError.timeout))
                } else {
                    print("NetworkClient: Network error: \(error.localizedDescription)")
                    completion(.failure(NetworkError.networkError(error)))
                }
                return
            }
            
            // Handle HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - return data
                    if let data = data {
                        completion(.success(data))
                    } else {
                        completion(.failure(NetworkError.emptyResponse))
                    }
                case 400:
                    print("NetworkClient: Bad request (400)")
                    completion(.failure(NetworkError.badRequest))
                case 429:
                    print("NetworkClient: Rate limited (429)")
                    completion(.failure(NetworkError.rateLimited))
                case 500...599:
                    print("NetworkClient: Server error (\(httpResponse.statusCode))")
                    completion(.failure(NetworkError.serverError(httpResponse.statusCode)))
                default:
                    print("NetworkClient: Unexpected status code (\(httpResponse.statusCode))")
                    completion(.failure(NetworkError.httpError(httpResponse.statusCode)))
                }
            } else {
                completion(.failure(NetworkError.invalidResponse))
            }
        }
        
        task.resume()
    }
}

// MARK: - Network Errors

/// Custom error types for network operations
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case encodingFailed(Error)
    case networkError(Error)
    case timeout
    case badRequest
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case invalidResponse
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .encodingFailed(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out after 5.0 seconds"
        case .badRequest:
            return "Bad request (400)"
        case .rateLimited:
            return "Rate limited (429)"
        case .serverError(let code):
            return "Server error (\(code))"
        case .httpError(let code):
            return "HTTP error (\(code))"
        case .invalidResponse:
            return "Invalid response from server"
        case .emptyResponse:
            return "Empty response from server"
        }
    }
}

