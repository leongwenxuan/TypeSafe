//
//  APIServiceTests.swift
//  TypeSafeTests
//
//  Story 3.4: Backend Integration (Scan Image API)
//  Unit tests for API service functionality
//

import XCTest
import UIKit
@testable import TypeSafe

/// Unit tests for APIService functionality
/// Tests multipart form data construction, session management, privacy settings, and error handling
final class APIServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var apiService: APIService!
    var mockSession: MockURLSession!
    var sessionManager: SessionManager!
    var privacyManager: PrivacyManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create mock session
        mockSession = MockURLSession()
        
        // Create managers
        sessionManager = SessionManager()
        privacyManager = PrivacyManager()
        
        // Reset privacy setting to default
        privacyManager.disableImageUpload()
        
        // Create API service with test configuration
        apiService = APIService(
            baseURL: "https://test.example.com",
            sessionManager: sessionManager,
            privacyManager: privacyManager
        )
    }
    
    override func tearDown() {
        apiService = nil
        mockSession = nil
        sessionManager = nil
        privacyManager = nil
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "TypeSafe.SessionID")
        UserDefaults.standard.removeObject(forKey: "TypeSafe.ImageUploadEnabled")
        
        super.tearDown()
    }
    
    // MARK: - Session Manager Tests
    
    func testSessionIDGeneration() {
        // Given
        let sessionManager = SessionManager()
        
        // When
        let sessionID1 = sessionManager.getOrCreateSessionID()
        let sessionID2 = sessionManager.getOrCreateSessionID()
        
        // Then
        XCTAssertFalse(sessionID1.isEmpty, "Session ID should not be empty")
        XCTAssertEqual(sessionID1, sessionID2, "Session ID should be consistent")
        
        // Verify UUID format
        XCTAssertNotNil(UUID(uuidString: sessionID1), "Session ID should be valid UUID")
    }
    
    func testSessionIDPersistence() {
        // Given
        let sessionManager1 = SessionManager()
        let sessionID1 = sessionManager1.getOrCreateSessionID()
        
        // When - Create new session manager (simulates app restart)
        let sessionManager2 = SessionManager()
        let sessionID2 = sessionManager2.getOrCreateSessionID()
        
        // Then
        XCTAssertEqual(sessionID1, sessionID2, "Session ID should persist across app sessions")
    }
    
    func testSessionReset() {
        // Given
        let sessionManager = SessionManager()
        let originalID = sessionManager.getOrCreateSessionID()
        
        // When
        sessionManager.resetSession()
        let newID = sessionManager.getOrCreateSessionID()
        
        // Then
        XCTAssertNotEqual(originalID, newID, "Session ID should change after reset")
        XCTAssertNotNil(UUID(uuidString: newID), "New session ID should be valid UUID")
    }
    
    // MARK: - Privacy Manager Tests
    
    func testPrivacyManagerDefaultState() {
        // Given
        let privacyManager = PrivacyManager()
        
        // Then
        XCTAssertFalse(privacyManager.isImageUploadEnabled, "Image upload should be disabled by default")
    }
    
    func testPrivacyManagerToggle() {
        // Given
        let privacyManager = PrivacyManager()
        XCTAssertFalse(privacyManager.isImageUploadEnabled)
        
        // When
        privacyManager.enableImageUpload()
        
        // Then
        XCTAssertTrue(privacyManager.isImageUploadEnabled, "Image upload should be enabled")
        
        // When
        privacyManager.disableImageUpload()
        
        // Then
        XCTAssertFalse(privacyManager.isImageUploadEnabled, "Image upload should be disabled")
    }
    
    func testPrivacyManagerPersistence() {
        // Given
        let privacyManager1 = PrivacyManager()
        privacyManager1.enableImageUpload()
        
        // When - Create new privacy manager (simulates app restart)
        let privacyManager2 = PrivacyManager()
        
        // Then
        XCTAssertTrue(privacyManager2.isImageUploadEnabled, "Privacy setting should persist")
    }
    
    // MARK: - API Service Tests
    
    func testScanImageWithTextOnly() {
        // Given
        let expectation = XCTestExpectation(description: "API call completes")
        let testText = "Test OCR text for analysis"
        
        // Mock successful response
        let mockResponse = ScanImageResponse(
            risk_level: "low",
            confidence: 0.95,
            category: "safe",
            explanation: "Test response",
            ts: "2025-01-18T10:30:00Z"
        )
        
        // When
        apiService.scanImage(ocrText: testText, image: nil) { result in
            // Then
            switch result {
            case .success(let response):
                XCTAssertEqual(response.risk_level, "low")
                XCTAssertEqual(response.confidence, 0.95)
                XCTAssertEqual(response.category, "safe")
                XCTAssertEqual(response.explanation, "Test response")
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testScanImageWithImageWhenPrivacyEnabled() {
        // Given
        privacyManager.enableImageUpload()
        let expectation = XCTestExpectation(description: "API call completes")
        let testText = "Test OCR text"
        let testImage = createTestImage()
        
        // When
        apiService.scanImage(ocrText: testText, image: testImage) { result in
            // Then - Should include image in request when privacy allows
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testScanImageWithImageWhenPrivacyDisabled() {
        // Given
        privacyManager.disableImageUpload()
        let expectation = XCTestExpectation(description: "API call completes")
        let testText = "Test OCR text"
        let testImage = createTestImage()
        
        // When
        apiService.scanImage(ocrText: testText, image: testImage) { result in
            // Then - Should not include image in request when privacy disabled
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testRetryMechanism() {
        // Given
        let expectation = XCTestExpectation(description: "Retry completes")
        let testText = "Test text for retry"
        
        // When
        apiService.retryScan(ocrText: testText, image: nil) { result in
            // Then
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testAPIErrorTypes() {
        // Test timeout error
        let timeoutError = APIError.timeout
        XCTAssertEqual(timeoutError.errorDescription, "Request timed out after 4.0 seconds")
        XCTAssertEqual(timeoutError.userFriendlyMessage, "The request took too long. Please check your internet connection and try again.")
        
        // Test network error
        let networkError = APIError.networkError(NSError(domain: "Test", code: -1, userInfo: nil))
        XCTAssertTrue(networkError.errorDescription?.contains("Network error") == true)
        XCTAssertEqual(networkError.userFriendlyMessage, "Network connection failed. Please check your internet connection.")
        
        // Test rate limited error
        let rateLimitedError = APIError.rateLimited
        XCTAssertEqual(rateLimitedError.errorDescription, "Too many requests - please try again later")
        XCTAssertEqual(rateLimitedError.userFriendlyMessage, "Too many requests. Please wait a moment and try again.")
        
        // Test server error
        let serverError = APIError.serverError(500)
        XCTAssertEqual(serverError.errorDescription, "Server error (500) - please try again")
        XCTAssertEqual(serverError.userFriendlyMessage, "Server is temporarily unavailable. Please try again later.")
        
        // Test bad request error
        let badRequestError = APIError.badRequest
        XCTAssertEqual(badRequestError.errorDescription, "Bad request - please check your input")
        XCTAssertEqual(badRequestError.userFriendlyMessage, "There was an issue with your request. Please try again.")
    }
    
    // MARK: - Response Model Tests
    
    func testScanImageResponseDecoding() throws {
        // Given
        let jsonString = """
        {
            "risk_level": "high",
            "confidence": 0.93,
            "category": "otp_phishing",
            "explanation": "This message is requesting an OTP code",
            "ts": "2025-01-18T10:30:00Z"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let response = try decoder.decode(ScanImageResponse.self, from: jsonData)
        
        // Then
        XCTAssertEqual(response.risk_level, "high")
        XCTAssertEqual(response.confidence, 0.93)
        XCTAssertEqual(response.category, "otp_phishing")
        XCTAssertEqual(response.explanation, "This message is requesting an OTP code")
        XCTAssertEqual(response.ts, "2025-01-18T10:30:00Z")
    }
    
    func testScanImageResponseDecodingWithoutTimestamp() throws {
        // Given
        let jsonString = """
        {
            "risk_level": "low",
            "confidence": 0.95,
            "category": "safe",
            "explanation": "Normal message"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        let response = try decoder.decode(ScanImageResponse.self, from: jsonData)
        
        // Then
        XCTAssertEqual(response.risk_level, "low")
        XCTAssertEqual(response.confidence, 0.95)
        XCTAssertEqual(response.category, "safe")
        XCTAssertEqual(response.explanation, "Normal message")
        XCTAssertNil(response.ts)
    }
    
    // MARK: - Performance Tests
    
    func testSessionIDGenerationPerformance() {
        let sessionManager = SessionManager()
        
        measure {
            for _ in 0..<1000 {
                _ = sessionManager.getOrCreateSessionID()
            }
        }
    }
    
    func testPrivacyTogglePerformance() {
        let privacyManager = PrivacyManager()
        
        measure {
            for _ in 0..<1000 {
                privacyManager.enableImageUpload()
                privacyManager.disableImageUpload()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates a test image for testing purposes
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Mock URLSession

/// Mock URLSession for testing network requests
class MockURLSession: URLSession {
    
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    override func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        return MockURLSessionDataTask {
            completionHandler(self.mockData, self.mockResponse, self.mockError)
        }
    }
}

/// Mock URLSessionDataTask for testing
class MockURLSessionDataTask: URLSessionDataTask {
    
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    override func resume() {
        // Simulate async network call
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            self.completion()
        }
    }
}