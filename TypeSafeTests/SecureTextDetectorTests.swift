//
//  SecureTextDetectorTests.swift
//  TypeSafeTests
//
//  Unit tests for SecureTextDetector secure field detection logic
//

import XCTest
import UIKit
@testable import TypeSafeKeyboard

class SecureTextDetectorTests: XCTestCase {
    
    var sut: SecureTextDetector!
    
    override func setUp() {
        super.setUp()
        sut = SecureTextDetector()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Mock UITextDocumentProxy
    
    class MockTextDocumentProxy: NSObject, UITextDocumentProxy {
        var documentContextBeforeInput: String?
        var documentContextAfterInput: String?
        var selectedText: String?
        var documentInputMode: UITextInputMode?
        var documentIdentifier: UUID = UUID()
        
        // Configurable properties for testing
        var mockKeyboardType: UIKeyboardType = .default
        var mockTextContentType: UITextContentType?
        
        var keyboardType: UIKeyboardType {
            return mockKeyboardType
        }
        
        var textContentType: UITextContentType? {
            return mockTextContentType
        }
        
        func adjustTextPosition(byCharacterOffset offset: Int) {}
        func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
        func unmarkText() {}
        func insertText(_ text: String) {}
        func deleteBackward() {}
    }
    
    // MARK: - Number Pad Detection Tests
    
    func test_isSecureField_whenNumberPad_returnsTrue() {
        // Given: Mock proxy with number pad keyboard
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockKeyboardType = .numberPad
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure (PIN field)
        XCTAssertTrue(result, "Number pad should be detected as secure field")
    }
    
    func test_isSecureField_whenDefaultKeyboard_returnsFalse() {
        // Given: Mock proxy with default keyboard
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockKeyboardType = .default
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should not detect as secure
        XCTAssertFalse(result, "Default keyboard should not be detected as secure")
    }
    
    // MARK: - Text Content Type Detection Tests
    
    func test_isSecureField_whenPasswordContentType_returnsTrue() {
        // Given: Mock proxy with password content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .password
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure
        XCTAssertTrue(result, "Password content type should be detected")
    }
    
    func test_isSecureField_whenNewPasswordContentType_returnsTrue() {
        // Given: Mock proxy with new password content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .newPassword
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure
        XCTAssertTrue(result, "New password content type should be detected")
    }
    
    func test_isSecureField_whenOneTimeCodeContentType_returnsTrue() {
        // Given: Mock proxy with one-time code content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .oneTimeCode
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure
        XCTAssertTrue(result, "One-time code should be detected as secure")
    }
    
    func test_isSecureField_whenEmailAddressContentType_returnsFalse() {
        // Given: Mock proxy with email address content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .emailAddress
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should not detect as secure
        XCTAssertFalse(result, "Email address should not be detected as secure")
    }
    
    func test_isSecureField_whenUsernameContentType_returnsFalse() {
        // Given: Mock proxy with username content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .username
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should not detect as secure
        XCTAssertFalse(result, "Username should not be detected as secure")
    }
    
    // MARK: - False Positive Prevention Tests
    
    func test_isSecureField_regularTextField_returnsFalse() {
        // Given: Mock proxy with regular text field characteristics
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockKeyboardType = .default
        mockProxy.mockTextContentType = nil
        mockProxy.documentContextBeforeInput = "Some text"
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should not be detected as secure
        XCTAssertFalse(result, "Regular text field should not be false positive")
    }
    
    func test_isSecureField_emailKeyboard_returnsFalse() {
        // Given: Mock proxy with email keyboard
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockKeyboardType = .emailAddress
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should not detect as secure
        XCTAssertFalse(result, "Email keyboard should not be detected as secure")
    }
    
    func test_isSecureField_urlKeyboard_returnsFalse() {
        // Given: Mock proxy with URL keyboard
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockKeyboardType = .URL
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should not detect as secure
        XCTAssertFalse(result, "URL keyboard should not be detected as secure")
    }
    
    func test_isSecureField_phoneNumberKeyboard_returnsTrue() {
        // Given: Mock proxy with phone number keyboard (Story 2.8: now detects phone pad as secure)
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockKeyboardType = .phonePad
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure (Story 2.8 enhancement)
        XCTAssertTrue(result, "Phone pad should be detected as potentially secure")
    }
    
    // MARK: - Edge Cases
    
    func test_isSecureField_nilContentType_returnsFalse() {
        // Given: Mock proxy with nil content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = nil
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should not detect as secure
        XCTAssertFalse(result)
    }
    
    func test_isSecureField_numberPadWithEmailType_returnsTrue() {
        // Given: Mock proxy with conflicting hints (number pad wins)
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockKeyboardType = .numberPad
        mockProxy.mockTextContentType = .emailAddress
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure (number pad takes precedence)
        XCTAssertTrue(result, "Number pad takes precedence in conflict")
    }
    
    // MARK: - Story 2.8: Enhanced Secure Field Detection Tests
    
    func test_isSecureField_creditCardNumber_returnsTrue() {
        // Given: Mock proxy with credit card number content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .creditCardNumber
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure
        XCTAssertTrue(result, "Credit card number should be detected as secure")
    }
    
    func test_isSecureField_creditCardSecurityCode_returnsTrue() {
        // Given: Mock proxy with credit card security code content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .creditCardSecurityCode
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure
        XCTAssertTrue(result, "Credit card security code should be detected as secure")
    }
    
    // MARK: - Caching Tests (Story 2.8)
    
    func test_isSecureField_caching_performance() {
        // Given: Mock proxy with password content type
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .password
        
        // When: Call multiple times quickly
        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = sut.isSecureField(mockProxy)
        }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Should complete quickly due to caching
        XCTAssertLessThan(timeElapsed, 0.1, "Caching should improve performance")
    }
    
    func test_invalidateCache_clearsCache() {
        // Given: Mock proxy and initial detection
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .password
        
        // When: Detect secure field, then invalidate cache
        let firstResult = sut.isSecureField(mockProxy)
        sut.invalidateCache()
        let secondResult = sut.isSecureField(mockProxy)
        
        // Then: Results should be consistent (cache invalidation doesn't change logic)
        XCTAssertEqual(firstResult, secondResult)
        XCTAssertTrue(firstResult, "Password field should be detected as secure")
    }
    
    // MARK: - Limited Context Access Tests (Story 2.8)
    
    class MockTextDocumentProxyWithHasText: MockTextDocumentProxy {
        var mockHasText: Bool = false
        
        override var hasText: Bool {
            return mockHasText
        }
    }
    
    func test_isSecureField_limitedContextAccess_returnsTrue() {
        // Given: Mock proxy with limited context access characteristics
        let mockProxy = MockTextDocumentProxyWithHasText()
        mockProxy.documentContextBeforeInput = nil
        mockProxy.documentContextAfterInput = nil
        mockProxy.selectedText = nil
        mockProxy.mockHasText = true
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should detect as secure due to limited context access
        XCTAssertTrue(result, "Limited context access should indicate secure field")
    }
    
    func test_isSecureField_emptyFieldWithNoContext_returnsFalse() {
        // Given: Mock proxy with no context but also no text (empty field)
        let mockProxy = MockTextDocumentProxyWithHasText()
        mockProxy.documentContextBeforeInput = nil
        mockProxy.documentContextAfterInput = nil
        mockProxy.selectedText = nil
        mockProxy.mockHasText = false
        
        // When: Check if secure field
        let result = sut.isSecureField(mockProxy)
        
        // Then: Should not detect as secure (empty field, not secure field)
        XCTAssertFalse(result, "Empty field should not be detected as secure")
    }
    
    // MARK: - Performance Tests (Story 2.8)
    
    func test_secureFieldDetection_performance() {
        let mockProxy = MockTextDocumentProxy()
        mockProxy.mockTextContentType = .password
        
        measure {
            for _ in 0..<1000 {
                _ = sut.isSecureField(mockProxy)
            }
        }
    }
}

