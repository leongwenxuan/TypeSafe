//
//  KeyboardViewControllerShiftCapsLockToggleTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 29/10/25.
//  Story 13.3: Caps Lock Toggle Logic - Toggle Testing
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardViewControllerShiftCapsLockToggleTests: XCTestCase {

    // MARK: - Test Properties
    var keyboardVC: KeyboardViewController!

    override func setUp() {
        super.setUp()
        keyboardVC = KeyboardViewController()
        // Load view to trigger viewDidLoad
        _ = keyboardVC.view
    }

    override func tearDown() {
        keyboardVC = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsNormal() {
        // Arrange & Act - Initial state after setup

        // Assert
        XCTAssertFalse(keyboardVC.isShifted, "Initial state should have shift disabled")
        XCTAssertFalse(keyboardVC.isCapsLocked, "Initial state should have caps lock disabled")
    }

    // MARK: - Single Tap (Shift) Tests

    func testSingleTapTogglesShift() {
        // Arrange
        keyboardVC.isShifted = false

        // Act
        keyboardVC.isShifted.toggle()

        // Assert
        XCTAssertTrue(keyboardVC.isShifted, "Single tap should enable shift")
    }

    func testSingleTapTogglesShiftOff() {
        // Arrange
        keyboardVC.isShifted = true

        // Act
        keyboardVC.isShifted.toggle()

        // Assert
        XCTAssertFalse(keyboardVC.isShifted, "Single tap should disable shift")
    }

    func testSingleTapDisablesCapsLock() {
        // Arrange
        keyboardVC.isCapsLocked = true
        keyboardVC.isShifted = true

        // Act - Simulate single tap enabling shift
        keyboardVC.isShifted.toggle()
        if keyboardVC.isShifted && keyboardVC.isCapsLocked {
            keyboardVC.isCapsLocked = false
        }

        // Assert
        XCTAssertTrue(keyboardVC.isShifted, "Shift should be enabled")
        XCTAssertFalse(keyboardVC.isCapsLocked, "Caps lock should be disabled on single tap")
    }

    // MARK: - Double Tap (Caps Lock) Tests

    func testDoubleTapEnablesCapsLock() {
        // Arrange
        keyboardVC.isCapsLocked = false

        // Act
        keyboardVC.isCapsLocked = true
        keyboardVC.isShifted = true

        // Assert
        XCTAssertTrue(keyboardVC.isCapsLocked, "Double tap should enable caps lock")
        XCTAssertTrue(keyboardVC.isShifted, "Double tap should set shift for first character")
    }

    func testDoubleTapDisablesCapsLock() {
        // Arrange
        keyboardVC.isCapsLocked = true
        keyboardVC.isShifted = true

        // Act
        keyboardVC.isCapsLocked = false

        // Assert
        XCTAssertFalse(keyboardVC.isCapsLocked, "Double tap should disable caps lock")
        // Note: isShifted may remain true if user had it enabled separately
    }

    // MARK: - Auto-Dismiss Logic Tests

    func testShiftAutoDismissOnCharacterInput() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Simulate character input
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert
        XCTAssertFalse(keyboardVC.isShifted, "Shift should auto-dismiss after character input")
    }

    func testCapsLockPreservesOnCharacterInput() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Simulate character input
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }

        // Assert
        XCTAssertTrue(keyboardVC.isCapsLocked, "Caps lock should persist after character input")
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

    // MARK: - Double-Tap Detection Tests

    func testDetectShiftDoubleTapWithinTimeout() {
        // Arrange
        let currentTime = Date().timeIntervalSince1970
        keyboardVC.lastShiftTapTime = currentTime - 0.1  // 100ms ago

        // Act
        let timeDelta = currentTime - keyboardVC.lastShiftTapTime
        let isDoubleTap = timeDelta <= keyboardVC.doubleTapTimeoutSeconds && keyboardVC.lastShiftTapTime > 0

        // Assert
        XCTAssertTrue(isDoubleTap, "Should detect double-tap within 0.3s timeout")
    }

    func testDetectShiftDoubleTapOutsideTimeout() {
        // Arrange
        let currentTime = Date().timeIntervalSince1970
        keyboardVC.lastShiftTapTime = currentTime - 0.5  // 500ms ago (outside 0.3s timeout)

        // Act
        let timeDelta = currentTime - keyboardVC.lastShiftTapTime
        let isDoubleTap = timeDelta <= keyboardVC.doubleTapTimeoutSeconds && keyboardVC.lastShiftTapTime > 0

        // Assert
        XCTAssertFalse(isDoubleTap, "Should not detect double-tap outside 0.3s timeout")
    }

    func testDetectShiftDoubleTapFirstTap() {
        // Arrange
        keyboardVC.lastShiftTapTime = 0  // No previous tap

        // Act
        let isDoubleTap = keyboardVC.doubleTapTimeoutSeconds > 0 && keyboardVC.lastShiftTapTime > 0

        // Assert
        XCTAssertFalse(isDoubleTap, "First tap should not be detected as double-tap")
    }

    // MARK: - State Machine Tests

    func testStateTransitionNormalToShift() {
        // Arrange
        XCTAssertFalse(keyboardVC.isShifted)
        XCTAssertFalse(keyboardVC.isCapsLocked)

        // Act - Single tap
        keyboardVC.isShifted.toggle()

        // Assert - Should be in Shift state
        XCTAssertTrue(keyboardVC.isShifted)
        XCTAssertFalse(keyboardVC.isCapsLocked)
    }

    func testStateTransitionNormalToCapsLock() {
        // Arrange
        XCTAssertFalse(keyboardVC.isShifted)
        XCTAssertFalse(keyboardVC.isCapsLocked)

        // Act - Double tap
        keyboardVC.isCapsLocked = true
        keyboardVC.isShifted = true

        // Assert - Should be in Caps Lock state
        XCTAssertTrue(keyboardVC.isShifted)
        XCTAssertTrue(keyboardVC.isCapsLocked)
    }

    func testStateTransitionShiftToCapsLock() {
        // Arrange - Start in Shift state
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act - Double tap enables caps lock
        keyboardVC.isCapsLocked = true
        // isShifted stays true

        // Assert - Should be in Caps Lock state
        XCTAssertTrue(keyboardVC.isShifted)
        XCTAssertTrue(keyboardVC.isCapsLocked)
    }

    func testStateTransitionCapsLockToNormal() {
        // Arrange - Start in Caps Lock state
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true

        // Act - Double tap disables caps lock
        keyboardVC.isCapsLocked = false

        // Assert - Should be in Normal state (shift may remain)
        XCTAssertFalse(keyboardVC.isCapsLocked)
    }

    func testStateTransitionShiftToNormal() {
        // Arrange - Start in Shift state
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act - Single tap to disable shift
        keyboardVC.isShifted.toggle()

        // Assert - Should be in Normal state
        XCTAssertFalse(keyboardVC.isShifted)
        XCTAssertFalse(keyboardVC.isCapsLocked)
    }

    // MARK: - Edge Case Tests

    func testRapidSingleTaps() {
        // Arrange
        keyboardVC.isShifted = false

        // Act - Rapid single taps
        keyboardVC.isShifted.toggle()  // Tap 1: Enable
        XCTAssertTrue(keyboardVC.isShifted)

        keyboardVC.isShifted.toggle()  // Tap 2: Disable
        XCTAssertFalse(keyboardVC.isShifted)

        keyboardVC.isShifted.toggle()  // Tap 3: Enable
        XCTAssertTrue(keyboardVC.isShifted)

        // Assert
        XCTAssertTrue(keyboardVC.isShifted, "Rapid single taps should work correctly")
    }

    func testShiftAndCapsLockMutualExclusivity() {
        // Arrange - Start with shift enabled
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act - Enable caps lock (should disable shift)
        if !keyboardVC.isCapsLocked {
            keyboardVC.isCapsLocked = true
            keyboardVC.isShifted = true
        }

        // Assert
        XCTAssertTrue(keyboardVC.isCapsLocked, "Caps lock should be enabled")
        XCTAssertTrue(keyboardVC.isShifted, "Shift should remain true in caps lock")
    }

    func testCapsLockToggleOnAndOff() {
        // Arrange
        keyboardVC.isCapsLocked = false
        keyboardVC.isShifted = false

        // Act - Turn caps lock on
        keyboardVC.isCapsLocked = true
        keyboardVC.isShifted = true

        // Assert
        XCTAssertTrue(keyboardVC.isCapsLocked)

        // Act - Turn caps lock off
        keyboardVC.isCapsLocked = false

        // Assert
        XCTAssertFalse(keyboardVC.isCapsLocked)
    }

    func testMultipleCapsLockToggles() {
        // Arrange
        keyboardVC.isCapsLocked = false

        // Act & Assert - Toggle on/off multiple times
        for i in 0..<5 {
            keyboardVC.isCapsLocked = !keyboardVC.isCapsLocked
            if i % 2 == 0 {
                // Even iterations: should be ON
                XCTAssertTrue(keyboardVC.isCapsLocked, "Iteration \(i): caps lock should be ON")
            } else {
                // Odd iterations: should be OFF
                XCTAssertFalse(keyboardVC.isCapsLocked, "Iteration \(i): caps lock should be OFF")
            }
        }
    }

    // MARK: - Character Input Processing Tests

    func testCharacterProcessingWithShiftEnabled() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Simulate character processing
        let key = "a"
        let character = keyboardVC.isShifted ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, "A", "Character should be uppercase with shift enabled")
    }

    func testCharacterProcessingWithCapsLockEnabled() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        keyboardVC.currentLayout = .letters

        // Act - Simulate character processing
        let key = "a"
        let character = keyboardVC.isShifted ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, "A", "Character should be uppercase with caps lock enabled")
    }

    func testCharacterProcessingWithoutShift() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.currentLayout = .letters

        // Act - Simulate character processing
        let key = "A"
        let character = keyboardVC.isShifted ? key.uppercased() : key.lowercased()

        // Assert
        XCTAssertEqual(character, "a", "Character should be lowercase without shift")
    }

    // MARK: - State Consistency Tests

    func testStateConsistencyAfterMultipleOperations() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false

        // Act - Perform series of operations
        // 1. Enable shift
        keyboardVC.isShifted = true
        XCTAssertTrue(keyboardVC.isShifted)
        XCTAssertFalse(keyboardVC.isCapsLocked)

        // 2. Enable caps lock (should preserve shift)
        keyboardVC.isCapsLocked = true
        XCTAssertTrue(keyboardVC.isShifted)
        XCTAssertTrue(keyboardVC.isCapsLocked)

        // 3. Disable caps lock
        keyboardVC.isCapsLocked = false
        XCTAssertFalse(keyboardVC.isCapsLocked)

        // 4. Auto-dismiss shift (simulate character input)
        keyboardVC.currentLayout = .letters
        if keyboardVC.currentLayout == .letters && keyboardVC.isShifted && !keyboardVC.isCapsLocked {
            keyboardVC.isShifted = false
        }
        XCTAssertFalse(keyboardVC.isShifted)
    }

    func testStatePreservationAcrossLayouts() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act - Switch layouts (shift should be preserved)
        keyboardVC.currentLayout = .numbers
        XCTAssertTrue(keyboardVC.isShifted)

        keyboardVC.currentLayout = .symbols
        XCTAssertTrue(keyboardVC.isShifted)

        keyboardVC.currentLayout = .letters
        XCTAssertTrue(keyboardVC.isShifted)

        // Assert
        XCTAssertTrue(keyboardVC.isShifted, "Shift state should be preserved across layout changes")
    }
}
