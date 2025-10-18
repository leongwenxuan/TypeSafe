//
//  KeyboardAPIService.swift
//  TypeSafeKeyboard
//
//  Direct API service for keyboard extension - works independently!
//  With Full Access, keyboards CAN make network requests!
//

import Foundation
import UIKit
import Photos
import Vision

/// API service that runs directly in the keyboard extension
/// Allows keyboard to analyze screenshots without opening the main app
class KeyboardAPIService {
    
    // MARK: - Configuration
    
    /// Backend API base URL
    private let baseURL = "https://portiered-penultimately-dilan.ngrok-free.dev"
    
    /// API timeout
    private let timeout: TimeInterval = 10.0
    
    // MARK: - Models
    
    struct ScanRequest: Codable {
        let ocrText: String
        let image: String? // Base64 encoded
        let sessionId: String
        
        enum CodingKeys: String, CodingKey {
            case ocrText = "ocr_text"
            case image
            case sessionId = "session_id"
        }
    }
    
    struct ScanResponse: Codable {
        /// Response type: "simple" or "agent"
        let type: String
        
        // Simple response fields
        let riskLevel: String?
        let confidence: Double?
        let category: String?
        let explanation: String?
        
        // Agent response fields
        let taskId: String?
        let wsUrl: String?
        let estimatedTime: String?
        let entitiesFound: Int?
        
        enum CodingKeys: String, CodingKey {
            case type
            case riskLevel = "risk_level"
            case confidence
            case category
            case explanation
            case taskId = "task_id"
            case wsUrl = "ws_url"
            case estimatedTime = "estimated_time"
            case entitiesFound = "entities_found"
        }
        
        /// Whether this is an agent response
        var isAgentResponse: Bool {
            return type == "agent"
        }
    }
    
    enum APIError: Error, LocalizedError {
        case networkError(Error)
        case invalidResponse
        case serverError(Int)
        case decodingError
        case imageConversionFailed
        
        var errorDescription: String? {
            switch self {
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let code):
                return "Server error: \(code)"
            case .decodingError:
                return "Failed to decode response"
            case .imageConversionFailed:
                return "Failed to convert image"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Scans an image directly from the keyboard
    /// - Parameters:
    ///   - image: The screenshot UIImage to analyze
    ///   - sessionId: Session identifier
    ///   - completion: Callback with result
    func scanImage(
        image: UIImage,
        sessionId: String,
        completion: @escaping (Result<ScanResponse, APIError>) -> Void
    ) {
        print("🟡 KeyboardAPIService: Starting direct scan from keyboard")
        
        // Get user's country code from shared settings
        let sharedDefaults = UserDefaults(suiteName: "group.com.typesafe.app")
        let userCountryCode = sharedDefaults?.string(forKey: "user_country_code") ?? Locale.current.region?.identifier ?? "US"
        print("   User country: \(userCountryCode)")
        
        // Step 1: Perform OCR on the image
        performOCR(on: image) { [weak self] ocrResult in
            guard let self = self else { return }
            
            switch ocrResult {
            case .success(let ocrText):
                print("🟢 KeyboardAPIService: OCR complete - \(ocrText.count) characters")
                
                // Step 2: Send to backend with user country
                self.sendToBackend(ocrText: ocrText, image: image, sessionId: sessionId, userCountry: userCountryCode, completion: completion)
                
            case .failure(let error):
                print("🔴 KeyboardAPIService: OCR failed - \(error)")
                completion(.failure(.networkError(error)))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Performs OCR on the image using Vision framework
    private func performOCR(on image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(APIError.imageConversionFailed))
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            var extractedText = ""
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                extractedText += topCandidate.string + "\n"
            }
            
            let text = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if text.isEmpty {
                completion(.failure(APIError.invalidResponse))
            } else {
                completion(.success(text))
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Sends OCR text and image to backend API using multipart/form-data
    private func sendToBackend(
        ocrText: String,
        image: UIImage,
        sessionId: String,
        userCountry: String,
        completion: @escaping (Result<ScanResponse, APIError>) -> Void
    ) {
        print("🟡 KeyboardAPIService: Sending to backend API...")
        print("   Backend URL: \(baseURL)")
        print("   Endpoint: \(baseURL)/scan-image")
        print("   OCR Text: \(ocrText.prefix(50))...")
        
        // Check if backend URL is still placeholder
        if baseURL.contains("your-backend-url.com") {
            print("🔴 ERROR: Backend URL is still placeholder!")
            print("   Please update baseURL in KeyboardAPIService.swift")
            completion(.failure(.invalidResponse))
            return
        }
        
        // Convert image to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("🔴 KeyboardAPIService: Failed to convert image to JPEG")
            completion(.failure(.imageConversionFailed))
            return
        }
        print("🟢 KeyboardAPIService: Image converted to JPEG (\(imageData.count) bytes)")
        
        guard let url = URL(string: "\(baseURL)/scan-image") else {
            print("🔴 KeyboardAPIService: Invalid URL: \(baseURL)/scan-image")
            completion(.failure(.invalidResponse))
            return
        }
        
        print("🟢 KeyboardAPIService: URL created successfully")
        
        // Create multipart/form-data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        // Build multipart body
        var body = Data()
        
        // Add session_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"session_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sessionId)\r\n".data(using: .utf8)!)
        
        // Add ocr_text field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"ocr_text\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(ocrText)\r\n".data(using: .utf8)!)
        
        // Add user_country field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_country\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userCountry)\r\n".data(using: .utf8)!)
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"screenshot.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🟢 KeyboardAPIService: Multipart form-data created (\(body.count) bytes)")
        
        // Make the request - THIS WORKS IN KEYBOARD WITH FULL ACCESS!
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔴 KeyboardAPIService: Network error - \(error)")
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔴 KeyboardAPIService: Invalid response")
                completion(.failure(.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("🔴 KeyboardAPIService: Server error - \(httpResponse.statusCode)")
                completion(.failure(.serverError(httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                print("🔴 KeyboardAPIService: No data received")
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ScanResponse.self, from: data)
                print("🟢 KeyboardAPIService: Success! Risk: \(response.riskLevel), Confidence: \(response.confidence)")
                completion(.success(response))
            } catch {
                print("🔴 KeyboardAPIService: Decoding error - \(error)")
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
}

