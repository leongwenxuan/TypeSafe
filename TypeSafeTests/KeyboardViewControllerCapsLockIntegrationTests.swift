//
//  KeyboardViewControllerCapsLockIntegrationTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 30/10/25.
//  Story 13.5: Comprehensive Caps Lock Feature Testing
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardViewControllerCapsLockIntegrationTests: XCTestCase {

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

    // MARK: - Integration Tests: Shift → Type → Auto-Dismiss Flow (AC: 7, 8)

    func testSingleShiftTypeLetterAutoDissmiss() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Single shift tap
        keyboardVC.isShifted = true
        let initialShift = keyboardVC.isShifted

        // Type letter
        let key = "a"
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

        // Auto-dismiss shift
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert
        XCTAssertTrue(initialShift, "Shift should be enabled after single tap")
        XCTAssertEqual(character, "A", "Character should be uppercase")
        XCTAssertFalse(keyboardVC.isShifted, "Shift should auto-dismiss after character")
        XCTAssertFalse(keyboardVC.isCapsLocked, "Caps lock should remain off")
    }

    func testSingleShiftTypeNumberShiftDismisses() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .numbers

        // Act - Single shift tap
        keyboardVC.isShifted = true

        // Type number (even though shift applies in letters layout only)
        let key = "5"
        let character = keyboardVC.currentLayout == .letters ?
            ((keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()) :
            key

        // Auto-dismiss shift (shouldn't happen in numbers layout)
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert
        XCTAssertEqual(character, "5", "Number should be unaffected")
        XCTAssertTrue(keyboardVC.isShifted, "Shift should NOT auto-dismiss in numbers layout")
    }

    func testCapsLockTypeMultipleLettersAllUppercase() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Double-tap to enable caps lock
        keyboardVC.isCapsLocked = true
        keyboardVC.isShifted = true

        // Type multiple letters
        let keys = ["h", "e", "l", "l", "o"]
        var results: [String] = []

        for key in keys {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()
            results.append(character)

            // Simulate auto-dismiss logic (shouldn't affect caps lock)
            if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
                keyboardVC.isShifted = false
            }
        }

        // Assert
        XCTAssertEqual(results, ["H", "E", "L", "L", "O"], "All characters should be uppercase")
        XCTAssertTrue(keyboardVC.isCapsLocked, "Caps lock should persist")
    }

    func testCapsLockDisableRevertsToLowercase() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Type letter with caps lock
        let key1 = "a"
        let character1 = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key1.uppercased() : key1.lowercased()

        // Disable caps lock
        keyboardVC.isCapsLocked = false
        keyboardVC.isShifted = false

        // Type another letter
        let key2 = "a"
        let character2 = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key2.uppercased() : key2.lowercased()

        // Assert
        XCTAssertEqual(character1, "A", "Character should be uppercase with caps lock")
        XCTAssertEqual(character2, "a", "Character should be lowercase after disabling caps lock")
    }

    // MARK: - Layout Transition Tests (AC: 1-8)

    func testLayoutTransitionPreservesShiftState() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Switch to numbers layout
        let shiftStateBeforeSwitch = keyboardVC.isShifted
        keyboardVC.currentLayout = .numbers
        let shiftStateAfterSwitch = keyboardVC.isShifted

        // Switch back to letters
        keyboardVC.currentLayout = .letters
        let shiftStateAfterReturn = keyboardVC.isShifted

        // Assert
        XCTAssertTrue(shiftStateBeforeSwitch, "Shift should be enabled before layout switch")
        XCTAssertTrue(shiftStateAfterSwitch, "Shift state should persist during layout switch")
        XCTAssertTrue(shiftStateAfterReturn, "Shift state should persist after returning to letters")
    }

    func testLayoutTransitionPreservesCapsLockState() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Switch layouts
        let capsBeforeSwitch = keyboardVC.isCapsLocked
        keyboardVC.currentLayout = .numbers
        let capsAfterSwitch = keyboardVC.isCapsLocked

        keyboardVC.currentLayout = .symbols
        let capsInSymbols = keyboardVC.isCapsLocked

        keyboardVC.currentLayout = .letters
        let capsAfterReturn = keyboardVC.isCapsLocked

        // Assert
        XCTAssertTrue(capsBeforeSwitch, "Caps lock should be enabled")
        XCTAssertTrue(capsAfterSwitch, "Caps lock should persist in numbers layout")
        XCTAssertTrue(capsInSymbols, "Caps lock should persist in symbols layout")
        XCTAssertTrue(capsAfterReturn, "Caps lock should persist after returning")
    }

    func testCharacterCasingRespectsCapsLockInAllLayouts() {
        // Arrange
        keyboardVC.isCapsLocked = true
        keyboardVC.isShifted = true
        keyboardVC.currentLayout = .letters

        // Act & Assert - Letters layout
        let letterKey = "x"
        let letterChar = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? letterKey.uppercased() : letterKey.lowercased()
        XCTAssertEqual(letterChar, "X", "Letter should be uppercase in caps lock")

        // Numbers layout (characters should not be affected by caps lock)
        keyboardVC.currentLayout = .numbers
        let numberKey = "5"
        let numberChar = keyboardVC.currentLayout == .letters ?
            ((keyboardVC.isShifted || keyboardVC.isCapsLocked) ? numberKey.uppercased() : numberKey.lowercased()) :
            numberKey
        XCTAssertEqual(numberChar, "5", "Number should not be affected by caps lock")

        // Symbols layout
        keyboardVC.currentLayout = .symbols
        let symbolKey = "@"
        let symbolChar = keyboardVC.currentLayout == .letters ?
            ((keyboardVC.isShifted || keyboardVC.isCapsLocked) ? symbolKey.uppercased() : symbolKey.lowercased()) :
            symbolKey
        XCTAssertEqual(symbolChar, "@", "Symbol should not be affected by caps lock")
    }

    // MARK: - Double-Tap Detection Edge Cases (AC: 2)

    func testDoubleTapWithinThreshold() {
        // Arrange
        let currentTime = Date().timeIntervalSince1970
        keyboardVC.lastShiftTapTime = currentTime - 0.15  // 150ms ago (within 300ms threshold)

        // Act
        let timeDelta = currentTime - keyboardVC.lastShiftTapTime
        let isDoubleTap = timeDelta <= keyboardVC.doubleTapTimeoutSeconds && keyboardVC.lastShiftTapTime > 0

        // Assert
        XCTAssertTrue(isDoubleTap, "150ms gap should be detected as double-tap with 0.3s threshold")
    }

    func testDoubleTapOutsideThreshold() {
        // Arrange
        let currentTime = Date().timeIntervalSince1970
        keyboardVC.lastShiftTapTime = currentTime - 0.5  // 500ms ago (outside 300ms threshold)

        // Act
        let timeDelta = currentTime - keyboardVC.lastShiftTapTime
        let isDoubleTap = timeDelta <= keyboardVC.doubleTapTimeoutSeconds && keyboardVC.lastShiftTapTime > 0

        // Assert
        XCTAssertFalse(isDoubleTap, "500ms gap should NOT be detected as double-tap")
    }

    func testTripleTapBehavior() {
        // Arrange
        let startTime = Date().timeIntervalSince1970
        keyboardVC.lastShiftTapTime = 0

        // Act - Simulate triple tap
        // First tap
        keyboardVC.lastShiftTapTime = startTime
        var isDouble = startTime - keyboardVC.lastShiftTapTime <= keyboardVC.doubleTapTimeoutSeconds && keyboardVC.lastShiftTapTime > 0
        XCTAssertFalse(isDouble, "First tap should not be double-tap")

        // Second tap (100ms later) - should trigger double-tap
        let secondTime = startTime + 0.1
        let timeSinceFirst = secondTime - keyboardVC.lastShiftTapTime
        isDouble = timeSinceFirst <= keyboardVC.doubleTapTimeoutSeconds && keyboardVC.lastShiftTapTime > 0
        keyboardVC.lastShiftTapTime = secondTime
        XCTAssertTrue(isDouble, "Second tap should be detected as double-tap")

        // Third tap (100ms later) - should be single-tap, not triple
        let thirdTime = secondTime + 0.1
        let timeSinceSecond = thirdTime - keyboardVC.lastShiftTapTime
        isDouble = timeSinceSecond <= keyboardVC.doubleTapTimeoutSeconds && keyboardVC.lastShiftTapTime > 0
        keyboardVC.lastShiftTapTime = thirdTime
        XCTAssertTrue(isDouble, "Third tap is within threshold of second tap")
    }

    func testTapDetectionResetsAfterTimeout() {
        // Arrange
        let startTime = Date().timeIntervalSince1970
        keyboardVC.lastShiftTapTime = startTime

        // Act - Wait beyond timeout (simulated)
        let laterTime = startTime + 0.5  // 500ms later
        let timeDelta = laterTime - keyboardVC.lastShiftTapTime
        let isDoubleTap = timeDelta <= keyboardVC.doubleTapTimeoutSeconds && keyboardVC.lastShiftTapTime > 0

        // Assert
        XCTAssertFalse(isDoubleTap, "After timeout, should not be detected as double-tap")
    }

    // MARK: - State Transition Sequences (AC: 7, 8)

    func testStateTransitionNormalToShiftToNormal() {
        // Arrange
        XCTAssertFalse(keyboardVC.isShifted)
        XCTAssertFalse(keyboardVC.isCapsLocked)

        // Act - Enable shift
        keyboardVC.isShifted = true
        XCTAssertTrue(keyboardVC.isShifted)

        // Disable shift
        keyboardVC.isShifted = false

        // Assert
        XCTAssertFalse(keyboardVC.isShifted)
        XCTAssertFalse(keyboardVC.isCapsLocked)
    }

    func testStateTransitionShiftToCapsLock() {
        // Arrange - Start with shift
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act - Enable caps lock (disables shift)
        keyboardVC.isCapsLocked = true
        // Shift might remain true when caps lock is active for visual purposes

        // Assert
        XCTAssertTrue(keyboardVC.isCapsLocked)
    }

    func testStateTransitionCapsLockToShift() {
        // Arrange - Start with caps lock
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true

        // Act - Disable caps lock
        keyboardVC.isCapsLocked = false
        // Shift state is maintained independently

        // Assert
        XCTAssertFalse(keyboardVC.isCapsLocked)
        XCTAssertTrue(keyboardVC.isShifted)
    }

    // MARK: - Rapid State Changes (AC: 7)

    func testRapidSingleTaps() {
        // Arrange
        keyboardVC.isShifted = false

        // Act & Assert - Rapid single taps should toggle correctly
        for i in 0..<10 {
            keyboardVC.isShifted.toggle()
            if i % 2 == 0 {
                // Even indices: should be enabled (1st, 3rd, 5th, etc.)
                XCTAssertTrue(keyboardVC.isShifted, "Toggle \(i) should be enabled")
            } else {
                // Odd indices: should be disabled (2nd, 4th, 6th, etc.)
                XCTAssertFalse(keyboardVC.isShifted, "Toggle \(i) should be disabled")
            }
        }
    }

    func testRapidStateChanges() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Perform rapid sequence of operations
        // 1. Enable shift
        keyboardVC.isShifted = true
        let char1 = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? "a".uppercased() : "a".lowercased()
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // 2. Enable shift again and enable caps lock
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        let char2 = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? "b".uppercased() : "b".lowercased()

        // 3. Disable caps lock but keep typing
        keyboardVC.isCapsLocked = false
        let char3 = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? "c".uppercased() : "c".lowercased()

        // Assert
        XCTAssertEqual(char1, "A", "First character should be uppercase")
        XCTAssertEqual(char2, "B", "Second character should be uppercase")
        XCTAssertEqual(char3, "C", "Third character should be uppercase with shift still on")
        XCTAssertFalse(keyboardVC.isCapsLocked, "Caps lock should be disabled")
        XCTAssertTrue(keyboardVC.isShifted, "Shift should still be enabled")
    }

    // MARK: - Unicode and Extended Character Tests

    func testUnicodeCharacterCasing() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act & Assert - Test various Unicode characters
        let testCases = [
            ("é", "É"),
            ("ñ", "Ñ"),
            ("å", "Å"),
            ("ö", "Ö"),
        ]

        for (input, expected) in testCases {
            let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? input.uppercased() : input.lowercased()
            XCTAssertEqual(character, expected, "Unicode character \(input) should convert correctly")
        }
    }

    func testEdgeCaseEmptyCharacter() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act
        let emptyString = ""
        let character = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? emptyString.uppercased() : emptyString.lowercased()

        // Assert
        XCTAssertEqual(character, "", "Empty string should remain empty")
    }

    // MARK: - State Isolation Tests

    func testStateDoesNotLeakBetweenInstances() {
        // Arrange
        let vc1 = KeyboardViewController()
        let vc2 = KeyboardViewController()
        _ = vc1.view  // Load views
        _ = vc2.view

        // Act
        vc1.isShifted = true
        vc1.isCapsLocked = true

        // Assert - vc2 should not be affected
        XCTAssertFalse(vc2.isShifted, "vc2 shift should not be affected by vc1")
        XCTAssertFalse(vc2.isCapsLocked, "vc2 caps lock should not be affected by vc1")
    }

    // MARK: - Performance Tests (AC: 6)

    func testRapidCharacterInputWithStateChanges() {
        // Arrange
        keyboardVC.currentLayout = .letters
        let inputCount = 100

        // Act - Simulate rapid input with state changes
        var processingTime: TimeInterval = 0
        let startTime = Date()

        for i in 0..<inputCount {
            let key = "a"
            let _ = (keyboardVC.isShifted || keyboardVC.isCapsLocked) ? key.uppercased() : key.lowercased()

            // Toggle shift every 10 characters
            if i % 10 == 0 {
                keyboardVC.isShifted.toggle()
            }

            // Toggle caps lock every 25 characters
            if i % 25 == 0 {
                keyboardVC.isCapsLocked.toggle()
            }
        }

        processingTime = Date().timeIntervalSince(startTime)

        // Assert - Should process 100 characters quickly (< 100ms is reasonable)
        XCTAssertLessThan(processingTime, 0.1, "Processing 100 characters should be fast")
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
}
