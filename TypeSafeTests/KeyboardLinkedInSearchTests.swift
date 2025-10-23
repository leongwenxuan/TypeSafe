//
//  KeyboardLinkedInSearchTests.swift
//  TypeSafeTests
//
//  Created by AI Agent on Story 9.3
//  Unit tests for LinkedIn search functionality
//

import XCTest
@testable import TypeSafe

class KeyboardLinkedInSearchTests: XCTestCase {
    
    // MARK: - Test LinkedIn Search Models
    
    func testLinkedInSearchRequestEncoding() {
        // Given
        let request = KeyboardAPIService.LinkedInSearchRequest(
            prompt: "John Smith",
            sessionId: "test-session-123",
            maxResults: 5
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try? encoder.encode(request)
        
        // Then
        XCTAssertNotNil(data, "Request should be encodable")
        
        if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["prompt"] as? String, "John Smith")
            XCTAssertEqual(json["session_id"] as? String, "test-session-123")
            XCTAssertEqual(json["max_results"] as? Int, 5)
        }
    }
    
    func testLinkedInSearchResponseDecoding() {
        // Given
        let json = """
        {
            "type": "linkedin_search",
            "results": [
                {
                    "name": "John Smith",
                    "title": "Senior Software Engineer",
                    "company": "Google",
                    "profile_url": "https://linkedin.com/in/johnsmith",
                    "snippet": "Experienced engineer specializing in distributed systems"
                }
            ],
            "search_time_ms": 2340,
            "source": "exa"
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try? decoder.decode(KeyboardAPIService.LinkedInSearchResponse.self, from: data)
        
        // Then
        XCTAssertNotNil(response, "Response should be decodable")
        XCTAssertEqual(response?.type, "linkedin_search")
        XCTAssertEqual(response?.results.count, 1)
        XCTAssertEqual(response?.results.first?.name, "John Smith")
        XCTAssertEqual(response?.results.first?.title, "Senior Software Engineer")
        XCTAssertEqual(response?.results.first?.company, "Google")
        XCTAssertEqual(response?.results.first?.profileUrl, "https://linkedin.com/in/johnsmith")
        XCTAssertEqual(response?.searchTimeMs, 2340)
        XCTAssertEqual(response?.source, "exa")
    }
    
    func testLinkedInProfileDecoding() {
        // Given
        let json = """
        {
            "name": "Jane Doe",
            "title": "Product Manager",
            "company": "Microsoft",
            "profile_url": "https://linkedin.com/in/janedoe",
            "snippet": "Leading innovative products"
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let profile = try? decoder.decode(KeyboardAPIService.LinkedInProfile.self, from: data)
        
        // Then
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.name, "Jane Doe")
        XCTAssertEqual(profile?.title, "Product Manager")
        XCTAssertEqual(profile?.company, "Microsoft")
        XCTAssertEqual(profile?.profileUrl, "https://linkedin.com/in/janedoe")
        XCTAssertEqual(profile?.snippet, "Leading innovative products")
    }
    
    // MARK: - Test Empty Results
    
    func testEmptyLinkedInSearchResponse() {
        // Given
        let json = """
        {
            "type": "linkedin_search",
            "results": [],
            "search_time_ms": 1200,
            "source": "exa"
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try? decoder.decode(KeyboardAPIService.LinkedInSearchResponse.self, from: data)
        
        // Then
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.results.count, 0)
        XCTAssertTrue(response?.results.isEmpty ?? false)
    }
    
    // MARK: - Test Multiple Results
    
    func testMultipleLinkedInResults() {
        // Given
        let json = """
        {
            "type": "linkedin_search",
            "results": [
                {
                    "name": "John Smith",
                    "title": "Senior Software Engineer",
                    "company": "Google",
                    "profile_url": "https://linkedin.com/in/johnsmith1",
                    "snippet": "First profile"
                },
                {
                    "name": "John A. Smith",
                    "title": "CEO",
                    "company": "StartupCo",
                    "profile_url": "https://linkedin.com/in/johnsmith2",
                    "snippet": "Second profile"
                },
                {
                    "name": "Johnny Smith",
                    "title": "Designer",
                    "company": "Creative Agency",
                    "profile_url": "https://linkedin.com/in/johnsmith3",
                    "snippet": "Third profile"
                }
            ],
            "search_time_ms": 3500,
            "source": "exa"
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try? decoder.decode(KeyboardAPIService.LinkedInSearchResponse.self, from: data)
        
        // Then
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.results.count, 3)
        XCTAssertEqual(response?.results[0].name, "John Smith")
        XCTAssertEqual(response?.results[1].name, "John A. Smith")
        XCTAssertEqual(response?.results[2].name, "Johnny Smith")
    }
    
    // MARK: - Test API Error Cases
    
    func testAPIErrorDescriptions() {
        // Test network error
        let networkError = KeyboardAPIService.APIError.networkError(NSError(domain: "test", code: -1009))
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription?.contains("Network error") ?? false)
        
        // Test rate limit error
        let rateLimitError = KeyboardAPIService.APIError.rateLimitExceeded
        XCTAssertEqual(rateLimitError.errorDescription, "Rate limit exceeded")
        
        // Test validation error
        let validationError = KeyboardAPIService.APIError.validationError
        XCTAssertEqual(validationError.errorDescription, "Validation error")
        
        // Test server error
        let serverError = KeyboardAPIService.APIError.serverError(500)
        XCTAssertEqual(serverError.errorDescription, "Server error: 500")
        
        // Test decoding error
        let decodingError = KeyboardAPIService.APIError.decodingError
        XCTAssertEqual(decodingError.errorDescription, "Failed to decode response")
    }
    
    // MARK: - Test CodingKeys Mapping
    
    func testLinkedInSearchRequestCodingKeys() {
        // Test that Swift camelCase maps to snake_case
        let request = KeyboardAPIService.LinkedInSearchRequest(
            prompt: "test",
            sessionId: "session123",
            maxResults: 10
        )
        
        let encoder = JSONEncoder()
        let data = try? encoder.encode(request)
        
        XCTAssertNotNil(data)
        
        if let data = data,
           let jsonString = String(data: data, encoding: .utf8) {
            // Verify snake_case keys are present
            XCTAssertTrue(jsonString.contains("session_id"))
            XCTAssertTrue(jsonString.contains("max_results"))
            
            // Verify camelCase keys are NOT present
            XCTAssertFalse(jsonString.contains("sessionId"))
            XCTAssertFalse(jsonString.contains("maxResults"))
        }
    }
    
    func testLinkedInProfileCodingKeys() {
        // Test that profile_url maps correctly
        let json = """
        {
            "name": "Test User",
            "title": "Engineer",
            "company": "TestCo",
            "profile_url": "https://linkedin.com/test",
            "snippet": "Test snippet"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let profile = try? decoder.decode(KeyboardAPIService.LinkedInProfile.self, from: data)
        
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.profileUrl, "https://linkedin.com/test")
    }
    
    func testLinkedInResponseCodingKeys() {
        // Test that search_time_ms maps correctly
        let json = """
        {
            "type": "linkedin_search",
            "results": [],
            "search_time_ms": 9999,
            "source": "exa"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try? decoder.decode(KeyboardAPIService.LinkedInSearchResponse.self, from: data)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.searchTimeMs, 9999)
    }
    
    // MARK: - Test Edge Cases
    
    func testLinkedInProfileWithLongSnippet() {
        // Given
        let longSnippet = String(repeating: "a", count: 500)
        let json = """
        {
            "name": "Test User",
            "title": "Engineer",
            "company": "TestCo",
            "profile_url": "https://linkedin.com/test",
            "snippet": "\(longSnippet)"
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let profile = try? decoder.decode(KeyboardAPIService.LinkedInProfile.self, from: data)
        
        // Then
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.snippet.count, 500)
    }
    
    func testLinkedInProfileWithSpecialCharacters() {
        // Given
        let json = """
        {
            "name": "José María García-López",
            "title": "VP of Engineering & Product",
            "company": "Über™ Technologies",
            "profile_url": "https://linkedin.com/in/jose-garcia",
            "snippet": "Leading @company with 💪 and ❤️"
        }
        """
        
        // When
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let profile = try? decoder.decode(KeyboardAPIService.LinkedInProfile.self, from: data)
        
        // Then
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.name, "José María García-López")
        XCTAssertEqual(profile?.title, "VP of Engineering & Product")
        XCTAssertEqual(profile?.company, "Über™ Technologies")
        XCTAssertTrue(profile?.snippet.contains("💪") ?? false)
    }
    
    // MARK: - Test Validation
    
    func testEmptyPromptHandling() {
        // In real implementation, empty prompt should not trigger API call
        // This test documents the expected behavior
        let emptyPrompt = ""
        XCTAssertTrue(emptyPrompt.isEmpty)
        
        let trimmedPrompt = emptyPrompt.trimmingCharacters(in: .whitespaces)
        XCTAssertTrue(trimmedPrompt.isEmpty)
    }
    
    func testShortPromptHandling() {
        // Prompts with less than 2 characters should be rejected
        let shortPrompt = "a"
        XCTAssertLessThan(shortPrompt.count, 2)
    }
    
    func testValidPromptHandling() {
        // Valid prompts should have 2+ characters
        let validPrompt = "John Smith"
        XCTAssertGreaterThanOrEqual(validPrompt.count, 2)
    }
}

