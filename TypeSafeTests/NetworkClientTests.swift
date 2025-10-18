//
//  NetworkClientTests.swift
//  TypeSafeTests
//
//  Story 2.3: Backend API Integration
//  Unit tests for NetworkClient with mocked URLSession
//

import XCTest
@testable import TypeSafe

class NetworkClientTests: XCTestCase {
    
    var networkClient: URLSessionNetworkClient!
    var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        // Create URLSession with custom configuration for mocking
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        networkClient = URLSessionNetworkClient(session: mockSession)
    }
    
    override func tearDown() {
        networkClient = nil
        mockSession = nil
        MockURLProtocol.reset()
        super.tearDown()
    }
    
    // MARK: - Test: Successful Requests
    
    func testSuccessfulPOSTRequest() {
        // Given: Mock successful response
        let expectedData = """
        {
            "risk_level": "high",
            "confidence": 0.93,
            "category": "otp_phishing",
            "explanation": "Asking for OTP."
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com/analyze-text")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockData = expectedData
        
        // When: Making POST request
        let expectation = self.expectation(description: "POST request")
        var resultData: Data?
        
        networkClient.post(url: "https://test.com/analyze-text", body: ["test": "data"]) { result in
            if case .success(let data) = result {
                resultData = data
            }
            expectation.fulfill()
        }
        
        // Then: Should receive data
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(resultData)
        XCTAssertEqual(resultData, expectedData)
    }
    
    func testRequestContainsCorrectHeaders() {
        // Given: Mock response
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockData = Data()
        
        // When: Making POST request
        let expectation = self.expectation(description: "Headers check")
        
        networkClient.post(url: "https://test.com/test", body: ["key": "value"]) { _ in
            expectation.fulfill()
        }
        
        // Then: Request should have correct Content-Type header
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(MockURLProtocol.lastRequest)
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
    }
    
    // MARK: - Test: Timeout Handling
    
    func testTimeoutError() {
        // Given: Mock timeout error
        MockURLProtocol.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )
        
        // When: Making request that times out
        let expectation = self.expectation(description: "Timeout")
        var receivedError: Error?
        
        networkClient.post(url: "https://test.com/timeout", body: [:]) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should receive timeout error
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedError)
        XCTAssertTrue(receivedError is NetworkError)
        if case .timeout = receivedError as? NetworkError {
            // Success
        } else {
            XCTFail("Expected NetworkError.timeout")
        }
    }
    
    // MARK: - Test: Network Errors
    
    func testNetworkConnectionError() {
        // Given: Mock network error (no connection)
        MockURLProtocol.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        
        // When: Making request with no connection
        let expectation = self.expectation(description: "Network error")
        var receivedError: Error?
        
        networkClient.post(url: "https://test.com/test", body: [:]) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should receive network error
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedError)
        XCTAssertTrue(receivedError is NetworkError)
    }
    
    // MARK: - Test: HTTP Status Codes
    
    func testBadRequestError() {
        // Given: Mock 400 response
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com/test")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When: Making request that returns 400
        let expectation = self.expectation(description: "Bad request")
        var receivedError: Error?
        
        networkClient.post(url: "https://test.com/test", body: [:]) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should receive badRequest error
        waitForExpectations(timeout: 1.0)
        if case .badRequest = receivedError as? NetworkError {
            // Success
        } else {
            XCTFail("Expected NetworkError.badRequest, got \(String(describing: receivedError))")
        }
    }
    
    func testRateLimitError() {
        // Given: Mock 429 response
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com/test")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When: Making request that returns 429
        let expectation = self.expectation(description: "Rate limit")
        var receivedError: Error?
        
        networkClient.post(url: "https://test.com/test", body: [:]) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should receive rateLimited error
        waitForExpectations(timeout: 1.0)
        if case .rateLimited = receivedError as? NetworkError {
            // Success
        } else {
            XCTFail("Expected NetworkError.rateLimited")
        }
    }
    
    func testServerError500() {
        // Given: Mock 500 response
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com/test")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When: Making request that returns 500
        let expectation = self.expectation(description: "Server error")
        var receivedError: Error?
        
        networkClient.post(url: "https://test.com/test", body: [:]) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should receive serverError
        waitForExpectations(timeout: 1.0)
        if case .serverError(let code) = receivedError as? NetworkError {
            XCTAssertEqual(code, 500)
        } else {
            XCTFail("Expected NetworkError.serverError(500)")
        }
    }
    
    // MARK: - Test: Invalid Responses
    
    func testInvalidJSONResponse() {
        // Given: Mock response with invalid JSON
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockData = "not valid json".data(using: .utf8)
        
        // When: Making request that returns invalid JSON
        let expectation = self.expectation(description: "Invalid JSON")
        var resultData: Data?
        
        networkClient.post(url: "https://test.com/test", body: [:]) { result in
            if case .success(let data) = result {
                resultData = data
            }
            expectation.fulfill()
        }
        
        // Then: Should still receive data (parsing happens at higher level)
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(resultData)
    }
    
    func testEmptyResponse() {
        // Given: Mock 200 response with no data
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com/test")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockData = nil
        
        // When: Making request with empty response
        let expectation = self.expectation(description: "Empty response")
        var receivedError: Error?
        
        networkClient.post(url: "https://test.com/test", body: [:]) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should receive emptyResponse error
        waitForExpectations(timeout: 1.0)
        if case .emptyResponse = receivedError as? NetworkError {
            // Success
        } else {
            XCTFail("Expected NetworkError.emptyResponse")
        }
    }
    
    func testInvalidURL() {
        // When: Providing invalid URL
        let expectation = self.expectation(description: "Invalid URL")
        var receivedError: Error?
        
        networkClient.post(url: "not a valid url", body: [:]) { result in
            if case .failure(let error) = result {
                receivedError = error
            }
            expectation.fulfill()
        }
        
        // Then: Should receive invalidURL error
        waitForExpectations(timeout: 1.0)
        if case .invalidURL = receivedError as? NetworkError {
            // Success
        } else {
            XCTFail("Expected NetworkError.invalidURL")
        }
    }
}

// MARK: - Mock URLProtocol

class MockURLProtocol: URLProtocol {
    static var mockResponse: URLResponse?
    static var mockData: Data?
    static var mockError: Error?
    static var lastRequest: URLRequest?
    
    static func reset() {
        mockResponse = nil
        mockData = nil
        mockError = nil
        lastRequest = nil
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        // Store request for verification
        MockURLProtocol.lastRequest = request
        
        // Handle error case
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        // Handle response
        if let response = MockURLProtocol.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        
        // Handle data
        if let data = MockURLProtocol.mockData {
            client?.urlProtocol(self, didLoad: data)
        }
        
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // No-op for mock
    }
}

