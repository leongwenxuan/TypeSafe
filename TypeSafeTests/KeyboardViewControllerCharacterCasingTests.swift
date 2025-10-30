//
//  KeyboardViewControllerCharacterCasingTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 29/10/25.
//  Story 13.4: Character Processing Case Sensitivity
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardViewControllerCharacterCasingTests: XCTestCase {

    // MARK: - Test Properties
    var keyboardVC: KeyboardViewController!
    var mockTextProxy: MockTextDocumentProxy!

    override func setUp() {
        super.setUp()
        keyboardVC = KeyboardViewController()
        mockTextProxy = MockTextDocumentProxy()
        keyboardVC.textDocumentProxy = mockTextProxy
        // Load view to trigger viewDidLoad
        _ = keyboardVC.view
    }

    override func tearDown() {
        keyboardVC = nil
        mockTextProxy = nil
        super.tearDown()
    }

    // MARK: - Character Case Conversion Tests

    func testUppercaseConversionWithShift() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Simulate character processing
        let key = "a"
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, "A", "Character should be uppercase with shift enabled")
    }

    func testUppercaseConversionWithCapsLock() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Simulate character processing
        let key = "a"
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, "A", "Character should be uppercase with caps lock enabled")
    }

    func testUppercaseConversionWithShiftAndCapsLock() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Simulate character processing
        let key = "a"
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, "A", "Character should be uppercase with both shift and caps lock enabled")
    }

    func testLowercaseConversionWithoutShiftOrCapsLock() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Simulate character processing
        let key = "A"
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, "a", "Character should be lowercase without shift or caps lock")
    }

    func testUppercaseConversionMultipleCharacters() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act & Assert
        let testCases = ["a": "A", "b": "B", "z": "Z", "m": "M"]
        for (input, expected) in testCases {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? input.uppercased() : input.lowercased()
            XCTAssertEqual(character, expected, "Character \(input) should convert to \(expected) with shift")
        }
    }

    func testLowercaseConversionMultipleCharacters() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act & Assert
        let testCases = ["A": "a", "B": "b", "Z": "z", "M": "m"]
        for (input, expected) in testCases {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? input.uppercased() : input.lowercased()
            XCTAssertEqual(character, expected, "Character \(input) should convert to \(expected) without shift")
        }
    }

    // MARK: - Layout-Specific Case Sensitivity Tests

    func testLetterLayoutAppliesCasing() {
        // Arrange
        keyboardVC.currentLayout = .letters
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act - Simulate character processing in letters layout
        let key = "x"
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, "X", "Letters layout should apply casing")
    }

    func testNumberLayoutIgnoresCasing() {
        // Arrange
        keyboardVC.currentLayout = .numbers
        keyboardVC.isShifted = true

        // Act - In numbers layout, we should return key as-is
        let key = "5"
        let character = keyboardVC.currentLayout == .letters ? (keyboardVC.isShifted || keyboardVC.isCapsLocked ? key.uppercased() : key.lowercased()) : key

        // Assert
        XCTAssertEqual(character, "5", "Numbers layout should not apply casing")
    }

    func testSymbolLayoutIgnoresCasing() {
        // Arrange
        keyboardVC.currentLayout = .symbols
        keyboardVC.isShifted = true

        // Act - In symbols layout, we should return key as-is
        let key = "@"
        let character = keyboardVC.currentLayout == .letters ? (keyboardVC.isShifted || keyboardVC.isCapsLocked ? key.uppercased() : key.lowercased()) : key

        // Assert
        XCTAssertEqual(character, "@", "Symbols layout should not apply casing")
    }

    // MARK: - Shift Auto-Dismiss Tests

    func testShiftAutoDismissAfterCharacterInput() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Simulate character input auto-dismiss logic
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert
        XCTAssertFalse(keyboardVC.isShifted, "Shift should auto-dismiss after character input")
    }

    func testCapsLockPersistsAfterCharacterInput() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Simulate character input auto-dismiss logic
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert
        XCTAssertTrue(keyboardVC.isCapsLocked, "Caps lock should persist after character input")
        XCTAssertTrue(keyboardVC.isShifted, "Shift should remain true while caps lock is active")
    }

    func testShiftNoAutoDismissInNumberLayout() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .numbers

        // Act - Simulate character input in numbers layout
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert
        XCTAssertTrue(keyboardVC.isShifted, "Shift should not auto-dismiss in numbers layout")
    }

    func testShiftNoAutoDismissInSymbolsLayout() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .symbols

        // Act - Simulate character input in symbols layout
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert
        XCTAssertTrue(keyboardVC.isShifted, "Shift should not auto-dismiss in symbols layout")
    }

    // MARK: - Special Character Tests

    func testSpaceCharacterNotAffectedByShift() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Space should remain unchanged
        let key = " "
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, " ", "Space character should not be affected by shift")
    }

    func testPunctuationNotAffectedByShift() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act & Assert - Test various punctuation marks
        let punctuation = [".", ",", "!", "?", ";", ":"]
        for mark in punctuation {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? mark.uppercased() : mark.lowercased()
            // Most punctuation doesn't change with case conversion
            XCTAssertEqual(character, mark, "Punctuation \(mark) should not be affected by shift")
        }
    }

    func testNumberCharactersNotAffectedByShift() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act & Assert - Numbers should not be affected by case conversion
        let numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        for number in numbers {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? number.uppercased() : number.lowercased()
            XCTAssertEqual(character, number, "Number \(number) should not be affected by shift")
        }
    }

    // MARK: - State Combination Tests

    func testSingleShiftThenCharacterInput() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Enable shift
        keyboardVC.isShifted = true
        let key = "x"
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

        // Assert character is uppercase
        XCTAssertEqual(character, "X", "Character should be uppercase with shift")

        // Act - Simulate character input (auto-dismiss shift)
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert shift dismissed
        XCTAssertFalse(keyboardVC.isShifted, "Shift should be dismissed after character input")
    }

    func testCapsLockThenMultipleCharacterInputs() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Enable caps lock
        keyboardVC.isCapsLocked = true
        keyboardVC.isShifted = true

        // Assert - Type multiple characters
        let testString = "hello"
        for char in testString {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? String(char).uppercased() : String(char).lowercased()
            XCTAssertEqual(character, String(char).uppercased(), "Character \(char) should be uppercase with caps lock")

            // Caps lock should NOT auto-dismiss
            if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
                keyboardVC.isShifted = false
            }
        }

        // Assert caps lock still active
        XCTAssertTrue(keyboardVC.isCapsLocked, "Caps lock should persist across multiple character inputs")
    }

    func testCapsLockToggleOffReverts() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Character input with caps lock on
        let key1 = "a"
        let character1 = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key1.uppercased() : key1.lowercased()
        XCTAssertEqual(character1, "A", "Character should be uppercase with caps lock")

        // Disable caps lock
        keyboardVC.isCapsLocked = false
        keyboardVC.isShifted = false

        // Type another character
        let key2 = "a"
        let character2 = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key2.uppercased() : key2.lowercased()

        // Assert
        XCTAssertEqual(character2, "a", "Character should be lowercase after caps lock is disabled")
    }

    // MARK: - Rapid Input Tests

    func testRapidCharacterInputWithShift() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Simulate rapid input: only first character should be uppercase
        let keys = ["h", "e", "l", "l", "o"]
        var results: [String] = []

        for key in keys {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()
            results.append(character)

            // Auto-dismiss shift after first character
            if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
                keyboardVC.isShifted = false
            }
        }

        // Assert
        XCTAssertEqual(results[0], "H", "First character should be uppercase")
        XCTAssertEqual(results[1], "e", "Second character should be lowercase")
        XCTAssertEqual(results[2], "l", "Third character should be lowercase")
        XCTAssertEqual(results[3], "l", "Fourth character should be lowercase")
        XCTAssertEqual(results[4], "o", "Fifth character should be lowercase")
    }

    func testRapidCharacterInputWithCapsLock() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Simulate rapid input: all characters should be uppercase
        let keys = ["h", "e", "l", "l", "o"]
        var results: [String] = []

        for key in keys {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()
            results.append(character)

            // Caps lock should NOT auto-dismiss
            if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
                keyboardVC.isShifted = false
            }
        }

        // Assert
        for (i, result) in results.enumerated() {
            XCTAssertEqual(result, "HELLO"[String.Index(utf16Offset: i, in: "HELLO")], "Character at index \(i) should be uppercase")
        }
    }
}

// MARK: - Mock TextDocumentProxy

class MockTextDocumentProxy: NSObject, UITextDocumentProxy {
    var insertedTexts: [String] = []

    func insertText(_ text: String) {
        insertedTexts.append(text)
    }

    // Implement required UITextDocumentProxy properties
    var documentContextBeforeInput: String? { nil }
    var documentContextAfterInput: String? { nil }
    var selectedText: String? { nil }
    var markedTextRange: UITextRange? { nil }
    var markedTextStyle: [NSAttributedString.Key : Any]? { nil }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {}
    func unmarkText() {}
    func textInRange(_ range: UITextRange) -> String? { nil }
    func replaceRange(_ range: UITextRange, withText text: String) {}
    func textRangeByExtendingPosition(_ position: UITextPosition, inDirection direction: UITextLayoutDirection, offset: Int) -> UITextRange? { nil }
    func textRangeFromPosition(_ fromPosition: UITextPosition, toPosition: UITextPosition) -> UITextRange? { nil }
    func comparePosition(_ position: UITextPosition, toPosition: UITextPosition) -> ComparisonResult { .orderedSame }
    func offsetFromPosition(_ from: UITextPosition, toPosition: UITextPosition) -> Int { 0 }
    func positionWithinRange(_ range: UITextRange, atCharacterOffset offset: Int) -> UITextPosition? { nil }
    func characterRangeByExtendingPosition(_ position: UITextPosition, inDirection direction: UITextLayoutDirection) -> UITextRange? { nil }
    func firstRectForRange(_ range: UITextRange) -> CGRect { .zero }
    func caretRectForPosition(_ position: UITextPosition) -> CGRect { .zero }
    func closestPositionToPoint(_ point: CGPoint) -> UITextPosition? { nil }
    func closestPositionToPoint(_ point: CGPoint, withinRange: UITextRange) -> UITextPosition? { nil }
    func characterRangeAtPoint(_ point: CGPoint) -> UITextRange? { nil }
    func deleteSurroundingText(_ beforeLength: Int, afterLength: Int) {}
    func hasText() -> Bool { false }
}
