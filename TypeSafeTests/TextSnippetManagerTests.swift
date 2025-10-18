//
//  TextSnippetManagerTests.swift
//  TypeSafeTests
//
//  Unit tests for TextSnippetManager snippet windowing logic
//

import XCTest
@testable import TypeSafeKeyboard

class TextSnippetManagerTests: XCTestCase {
    
    var sut: TextSnippetManager!
    
    override func setUp() {
        super.setUp()
        sut = TextSnippetManager()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Sliding Window Tests
    
    func test_append_whenBufferExceeds300Chars_maintainsWindowSize() {
        // Given: 350 characters of text
        let longText = String(repeating: "a", count: 350)
        
        // When: Append each character
        for char in longText {
            _ = sut.append(String(char))
        }
        
        // Then: Buffer should contain exactly 300 characters
        let currentSnippet = sut.getCurrentSnippet()
        XCTAssertEqual(currentSnippet.count, 300, "Buffer should maintain 300 char limit")
    }
    
    func test_append_whenExactly300Chars_doesNotExceedLimit() {
        // Given: Exactly 300 characters
        let text = String(repeating: "b", count: 300)
        
        // When: Append each character
        for char in text {
            _ = sut.append(String(char))
        }
        
        // Then: Buffer should contain exactly 300 characters
        XCTAssertEqual(sut.getCurrentSnippet().count, 300)
    }
    
    func test_append_whenBufferExceeds300_trimsOldestCharacters() {
        // Given: 305 characters where first 5 are unique
        let uniquePrefix = "ABCDE"
        let remainder = String(repeating: "x", count: 300)
        
        // When: Append all characters
        for char in uniquePrefix {
            _ = sut.append(String(char))
        }
        for char in remainder {
            _ = sut.append(String(char))
        }
        
        // Then: Buffer should not contain the unique prefix (trimmed)
        let currentSnippet = sut.getCurrentSnippet()
        XCTAssertEqual(currentSnippet.count, 300)
        XCTAssertFalse(currentSnippet.contains("A"))
        XCTAssertFalse(currentSnippet.contains("B"))
    }
    
    // MARK: - Trigger Tests
    
    func test_append_whenSpaceTyped_triggersAnalysis() {
        // Given: Some text before space
        for char in "hello" {
            _ = sut.append(String(char))
        }
        
        // When: Space is typed
        let result = sut.append(" ")
        
        // Then: Analysis should be triggered
        XCTAssertNotNil(result, "Space should trigger analysis")
        XCTAssertEqual(result?.triggerReason, .significantPause)
    }
    
    func test_append_whenPeriodTyped_triggersAnalysis() {
        // Given: Some text before period
        for char in "hello" {
            _ = sut.append(String(char))
        }
        
        // When: Period is typed
        let result = sut.append(".")
        
        // Then: Analysis should be triggered
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.triggerReason, .significantPause)
    }
    
    func test_append_whenExclamationTyped_triggersAnalysis() {
        // Given: Some text
        for char in "wow" {
            _ = sut.append(String(char))
        }
        
        // When: Exclamation mark typed
        let result = sut.append("!")
        
        // Then: Should trigger
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.triggerReason, .significantPause)
    }
    
    func test_append_whenQuestionMarkTyped_triggersAnalysis() {
        // Given: Some text
        for char in "why" {
            _ = sut.append(String(char))
        }
        
        // When: Question mark typed
        let result = sut.append("?")
        
        // Then: Should trigger
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.triggerReason, .significantPause)
    }
    
    func test_append_whenCommaTyped_triggersAnalysis() {
        // Given: Some text
        for char in "hello" {
            _ = sut.append(String(char))
        }
        
        // When: Comma typed
        let result = sut.append(",")
        
        // Then: Should trigger
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.triggerReason, .significantPause)
    }
    
    func test_append_when50CharsTyped_triggersAnalysis() {
        // Given: 49 characters typed
        let text = String(repeating: "a", count: 49)
        for char in text {
            _ = sut.append(String(char))
        }
        
        // When: 50th character typed (no space/punctuation)
        let result = sut.append("b")
        
        // Then: Should trigger due to character threshold
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.triggerReason, .characterThreshold)
    }
    
    func test_append_whenLessThan10Chars_doesNotTrigger() {
        // Given: Only 5 characters
        for char in "hello" {
            _ = sut.append(String(char))
        }
        
        // When: Space typed (but buffer < 10 chars)
        let result = sut.append(" ")
        
        // Then: Should NOT trigger (buffer too small)
        XCTAssertNil(result, "Should not trigger with < 10 characters")
    }
    
    // MARK: - Backspace Tests
    
    func test_deleteLastCharacter_whenBufferHasContent_returnsTrue() {
        // Given: Buffer has content
        for char in "test" {
            _ = sut.append(String(char))
        }
        
        // When: Delete last character
        let result = sut.deleteLastCharacter()
        
        // Then: Should return true and modify buffer
        XCTAssertTrue(result)
        XCTAssertEqual(sut.getCurrentSnippet(), "tes")
    }
    
    func test_deleteLastCharacter_whenBufferEmpty_returnsFalse() {
        // Given: Empty buffer
        
        // When: Try to delete
        let result = sut.deleteLastCharacter()
        
        // Then: Should return false
        XCTAssertFalse(result)
    }
    
    func test_deleteLastCharacter_multipleDeletes_updatesBufferCorrectly() {
        // Given: Buffer with content
        for char in "testing" {
            _ = sut.append(String(char))
        }
        
        // When: Delete 3 characters
        _ = sut.deleteLastCharacter()
        _ = sut.deleteLastCharacter()
        _ = sut.deleteLastCharacter()
        
        // Then: Buffer should have "test"
        XCTAssertEqual(sut.getCurrentSnippet(), "test")
    }
    
    // MARK: - Clear Tests
    
    func test_clear_resetsBuffer() {
        // Given: Buffer with content
        for char in "some text here" {
            _ = sut.append(String(char))
        }
        
        // When: Clear is called
        sut.clear()
        
        // Then: Buffer should be empty
        XCTAssertTrue(sut.getCurrentSnippet().isEmpty)
    }
    
    func test_clear_resetsCounters() {
        // Given: Buffer with content and triggered analysis
        for char in "hello world test" {
            _ = sut.append(String(char))
        }
        
        // When: Clear then add 5 chars and space
        sut.clear()
        for char in "hello" {
            _ = sut.append(String(char))
        }
        let result = sut.append(" ")
        
        // Then: Should not trigger (< 10 chars after clear)
        XCTAssertNil(result)
    }
    
    // MARK: - Edge Cases
    
    func test_append_emptyBuffer_returnsNil() {
        // Given: Empty buffer
        
        // When: Append space immediately
        let result = sut.append(" ")
        
        // Then: Should not trigger
        XCTAssertNil(result)
    }
    
    func test_getCurrentSnippet_emptyBuffer_returnsEmptyString() {
        // Given: Empty buffer
        
        // When: Get current snippet
        let snippet = sut.getCurrentSnippet()
        
        // Then: Should be empty
        XCTAssertEqual(snippet, "")
    }
    
    func test_append_rapidInput_maintainsCorrectBuffer() {
        // Given: Rapid input of 400 characters
        let rapidText = String(repeating: "x", count: 400)
        
        // When: Append all at once
        for char in rapidText {
            _ = sut.append(String(char))
        }
        
        // Then: Buffer should be exactly 300 chars
        XCTAssertEqual(sut.getCurrentSnippet().count, 300)
    }
    
    func test_shouldTriggerAnalysis_withTriggerCharacter_returnsTrue() {
        // Given: Buffer with content
        for char in "hello world" {
            _ = sut.append(String(char))
        }
        
        // When: Check if space triggers
        let result = sut.shouldTriggerAnalysis(" ")
        
        // Then: Should return true
        XCTAssertTrue(result)
    }
    
    func test_shouldTriggerAnalysis_withRegularCharacter_returnsFalse() {
        // Given: Buffer with content
        for char in "hello" {
            _ = sut.append(String(char))
        }
        
        // When: Check if regular character triggers
        let result = sut.shouldTriggerAnalysis("a")
        
        // Then: Should return false (not at threshold yet)
        XCTAssertFalse(result)
    }
}

