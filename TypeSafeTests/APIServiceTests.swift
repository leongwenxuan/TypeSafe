//
//  APIServiceTests.swift
//  TypeSafeTests
//
//  Story 2.3: Backend API Integration
//  Unit tests for APIService with mocked dependencies
//

import XCTest
@testable import TypeSafe

class APIServiceTests: XCTestCase {
    
    var apiService: APIService!
    var mockNetworkClient: MockNetworkClient!
    var mockSessionManager: MockSessionManager!
    
    override func setUp() {
        super.setUp()
        mockNetworkClient = MockNetworkClient()
        mockSessionManager = MockSessionManager()
        apiService = APIService(
            networkClient: mockNetworkClient,
            sessionManager: mockSessionManager,
            baseURL: "https://test-backend.com"
        )
    }
    
    override func tearDown() {
        apiService = nil
        mockNetworkClient = nil
        mockSessionManager = nil
        super.tearDown()
    }
    
    // MARK: - Test: Request Construction
    
    func testAnalyzeTextConstructsCorrectRequest() {
        // Given: Mock session ID
        mockSessionManager.mockSessionID = "test-session-123"
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Request sent")
        mockNetworkClient.onPost = { _, body in
            // Then: Should construct correct request body
            XCTAssertEqual(body["session_id"] as? String, "test-session-123")
            XCTAssertEqual(body["app_bundle"] as? String, "unknown")
            XCTAssertEqual(body["text"] as? String, "test message")
            expectation.fulfill()
        }
        
        apiService.analyzeText(text: "test message") { _ in }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testAnalyzeTextUsesCorrectEndpoint() {
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Endpoint check")
        mockNetworkClient.onPost = { url, _ in
            // Then: Should use correct endpoint
            XCTAssertEqual(url, "https://test-backend.com/analyze-text")
            expectation.fulfill()
        }
        
        apiService.analyzeText(text: "test") { _ in }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testAnalyzeTextRetrievesSessionID() {
        // Given: Mock session manager
        mockSessionManager.mockSessionID = "session-xyz"
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Session ID retrieved")
        mockNetworkClient.onPost = { _, body in
            // Then: Should retrieve session ID from manager
            XCTAssertEqual(body["session_id"] as? String, "session-xyz")
            XCTAssert(self.mockSessionManager.getOrCreateCalled, "Should call getOrCreateSessionID")
            expectation.fulfill()
        }
        
        apiService.analyzeText(text: "test") { _ in }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Test: Successful Response Parsing
    
    func testAnalyzeTextParsesSuccessfulResponse() {
        // Given: Mock successful API response
        let responseJSON = """
        {
            "risk_level": "high",
            "confidence": 0.93,
            "category": "otp_phishing",
            "explanation": "Asking for OTP.",
            "ts": "2025-01-18T10:00:00Z"
        }
        """.data(using: .utf8)!
        
        mockNetworkClient.mockResponse = .success(responseJSON)
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Response parsed")
        var parsedResponse: AnalyzeTextResponse?
        
        apiService.analyzeText(text: "test") { result in
            if case .success(let response) = result {
                parsedResponse = response
            }
            expectation.fulfill()
        }
        
        // Then: Should parse response correctly
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(parsedResponse)
        XCTAssertEqual(parsedResponse?.risk_level, "high")
        XCTAssertEqual(parsedResponse?.confidence, 0.93)
        XCTAssertEqual(parsedResponse?.category, "otp_phishing")
        XCTAssertEqual(parsedResponse?.explanation, "Asking for OTP.")
    }
    
    func testAnalyzeTextInvokesSuccessCallback() {
        // Given: Mock successful response
        let responseJSON = """
        {
            "risk_level": "low",
            "confidence": 0.12,
            "category": "unknown",
            "explanation": "Safe message"
        }
        """.data(using: .utf8)!
        
        mockNetworkClient.mockResponse = .success(responseJSON)
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Success callback")
        var successCalled = false
        
        apiService.analyzeText(text: "test") { result in
            if case .success = result {
                successCalled = true
            }
            expectation.fulfill()
        }
        
        // Then: Should invoke success callback
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(successCalled, "Success callback should be invoked")
    }
    
    // MARK: - Test: Error Handling
    
    func testAnalyzeTextHandlesNetworkError() {
        // Given: Mock network error
        mockNetworkClient.mockResponse = .failure(NetworkError.timeout)
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Error handled")
        var receivedError: Error?
        
        apiService.analyzeText(text: "test") { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should invoke error callback
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedError)
        XCTAssertTrue(receivedError is NetworkError)
    }
    
    func testAnalyzeTextHandlesJSONParsingError() {
        // Given: Mock invalid JSON response
        let invalidJSON = "not valid json".data(using: .utf8)!
        mockNetworkClient.mockResponse = .success(invalidJSON)
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Parsing error handled")
        var receivedError: Error?
        
        apiService.analyzeText(text: "test") { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should invoke error callback with parsing error
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedError)
        XCTAssertTrue(receivedError is APIError)
    }
    
    func testAnalyzeTextInvokesErrorCallback() {
        // Given: Mock error
        mockNetworkClient.mockResponse = .failure(NetworkError.badRequest)
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Error callback")
        var errorCallbackInvoked = false
        
        apiService.analyzeText(text: "test") { result in
            if case .failure = result {
                errorCallbackInvoked = true
            }
            expectation.fulfill()
        }
        
        // Then: Should invoke error callback
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(errorCallbackInvoked, "Error callback should be invoked")
    }
    
    // MARK: - Test: Edge Cases
    
    func testAnalyzeTextWithLongText() {
        // Given: Long text (300 chars from snippet manager)
        let longText = String(repeating: "a", count: 300)
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Long text sent")
        mockNetworkClient.onPost = { _, body in
            // Then: Should send full text
            let sentText = body["text"] as? String
            XCTAssertEqual(sentText?.count, 300)
            expectation.fulfill()
        }
        
        apiService.analyzeText(text: longText) { _ in }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testAnalyzeTextWithEmptyString() {
        // When: Calling analyzeText with empty string
        let expectation = self.expectation(description: "Empty text sent")
        mockNetworkClient.onPost = { _, body in
            // Then: Should still send request
            XCTAssertEqual(body["text"] as? String, "")
            expectation.fulfill()
        }
        
        apiService.analyzeText(text: "") { _ in }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testAnalyzeTextWithSpecialCharacters() {
        // Given: Text with special characters
        let specialText = "Test 💰 emoji and \n newline"
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Special chars sent")
        mockNetworkClient.onPost = { _, body in
            // Then: Should preserve special characters
            XCTAssertEqual(body["text"] as? String, specialText)
            expectation.fulfill()
        }
        
        apiService.analyzeText(text: specialText) { _ in }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testCallbacksAreInvokedOnMainThread() {
        // Given: Mock response
        let responseJSON = """
        {
            "risk_level": "low",
            "confidence": 0.5,
            "category": "unknown",
            "explanation": "Test"
        }
        """.data(using: .utf8)!
        
        mockNetworkClient.mockResponse = .success(responseJSON)
        
        // When: Calling analyzeText
        let expectation = self.expectation(description: "Main thread check")
        
        apiService.analyzeText(text: "test") { _ in
            // Then: Callback should be on main thread
            XCTAssertTrue(Thread.isMainThread, "Callback should be invoked on main thread")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
}

// MARK: - Mock NetworkClient

class MockNetworkClient: NetworkClient {
    var mockResponse: Result<Data, Error>?
    var onPost: ((String, [String: Any]) -> Void)?
    
    func post(url: String, body: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        // Call the inspection hook if set
        onPost?(url, body)
        
        // Return mock response if set
        if let response = mockResponse {
            completion(response)
        }
    }
}

// MARK: - Mock SessionManager

class MockSessionManager: SessionManager {
    var mockSessionID: String = "mock-session-id"
    var getOrCreateCalled = false
    
    override func getOrCreateSessionID() -> String {
        getOrCreateCalled = true
        return mockSessionID
    }
}

