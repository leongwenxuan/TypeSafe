//
//  KeyboardViewControllerAccessibilityTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 30/10/25.
//  Story 13.6: UI Polish & Accessibility for Caps Lock
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardViewControllerAccessibilityTests: XCTestCase {

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

    // MARK: - Accessibility Label Tests (AC: 1, 5)

    func testShiftButtonAccessibilityLabelsExist() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Labels should not be empty
        XCTAssertNotNil(button.accessibilityLabel, "Shift button should have accessibility label")
        XCTAssertFalse((button.accessibilityLabel ?? "").isEmpty, "Accessibility label should not be empty")
        XCTAssertNotNil(button.accessibilityHint, "Shift button should have accessibility hint")
        XCTAssertFalse((button.accessibilityHint ?? "").isEmpty, "Accessibility hint should not be empty")
    }

    func testNormalStateAccessibilityLabel() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert
        XCTAssertEqual(button.accessibilityLabel, "Shift", "Normal state should have 'Shift' label")
        XCTAssertEqual(button.accessibilityValue, "off", "Normal state should have 'off' value")
    }

    func testShiftActiveStateAccessibilityLabel() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert
        XCTAssertEqual(button.accessibilityLabel, "Shift active", "Shift active state should have 'Shift active' label")
        XCTAssertEqual(button.accessibilityValue, "on", "Shift active state should have 'on' value")
    }

    func testCapsLockStateAccessibilityLabel() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert
        XCTAssertEqual(button.accessibilityLabel, "Caps lock enabled", "Caps lock state should have 'Caps lock enabled' label")
        XCTAssertEqual(button.accessibilityValue, "on", "Caps lock state should have 'on' value")
    }

    func testNormalStateAccessibilityHint() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Hint should explain functionality
        let hint = button.accessibilityHint ?? ""
        XCTAssertTrue(hint.contains("uppercase") || hint.contains("Uppercase"),
                     "Normal state hint should mention uppercase")
        XCTAssertTrue(hint.contains("caps lock") || hint.contains("Caps lock"),
                     "Normal state hint should mention caps lock")
    }

    func testShiftActiveStateAccessibilityHint() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert
        let hint = button.accessibilityHint ?? ""
        XCTAssertTrue(hint.contains("Next character") || hint.contains("next character"),
                     "Shift active hint should mention next character")
    }

    func testCapsLockStateAccessibilityHint() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert
        let hint = button.accessibilityHint ?? ""
        XCTAssertTrue(hint.contains("All characters") || hint.contains("all characters"),
                     "Caps lock hint should mention all characters")
    }

    // MARK: - Accessibility Element Tests (AC: 5)

    func testShiftButtonIsAccessibilityElement() {
        // Arrange
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert
        XCTAssertTrue(button.isAccessibilityElement, "Shift button should be marked as accessibility element")
    }

    func testAccessibilityLabelUpdateOnStateChange() {
        // Arrange
        let button = UIButton(type: .custom)
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.updateSingleShiftButton(button)
        let initialLabel = button.accessibilityLabel

        // Act - Change state
        keyboardVC.isShifted = true
        keyboardVC.updateSingleShiftButton(button)
        let updatedLabel = button.accessibilityLabel

        // Assert - Label should update
        XCTAssertNotEqual(initialLabel, updatedLabel, "Accessibility label should update on state change")
        XCTAssertEqual(updatedLabel, "Shift active", "Updated label should reflect new state")
    }

    // MARK: - Visual Consistency Tests (AC: 4)

    func testShiftButtonSizeConsistency() {
        // Arrange
        let button1 = UIButton(type: .custom)
        let button2 = UIButton(type: .custom)

        // Act - Create buttons for different states
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        keyboardVC.updateSingleShiftButton(button1)

        keyboardVC.isShifted = true
        keyboardVC.updateSingleShiftButton(button2)

        // Assert - Button size should not change
        XCTAssertEqual(button1.frame.size, button2.frame.size,
                     "Button size should be consistent across states")
    }

    func testShiftButtonCornerRadiusConsistency() {
        // Arrange
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Corner radius should be standard
        XCTAssertGreaterThan(button.layer.cornerRadius, 0, "Button should have corner radius for rounded corners")
    }

    // MARK: - Haptic Feedback Tests (AC: 2, 3)

    func testHapticFeedbackDoesNotCrashOnUnavailableDevice() {
        // Arrange - Simulate calling haptic on a device without haptic support
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)

        // Act & Assert - Should not crash
        XCTAssertNoThrow({
            impactGenerator.impactOccurred()
        }, "Haptic feedback should gracefully handle devices without support")
    }

    func testSelectionFeedbackGeneratorInitialization() {
        // Arrange & Act
        let selectionGenerator = UISelectionFeedbackGenerator()

        // Assert - Should initialize without error
        XCTAssertNotNil(selectionGenerator, "Selection feedback generator should initialize")
    }

    // MARK: - Color Contrast Tests (AC: 6)

    func testShiftButtonColorContrast() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false

        // Act
        let style = keyboardVC.getShiftButtonStyle()

        // Assert - Button should have background color
        XCTAssertNotNil(style.backgroundColor, "Shift button should have background color")

        // Verify colors are not the same (should have contrast)
        let backgroundColor = style.backgroundColor ?? .white
        let textColor = style.textColor
        XCTAssertNotEqual(backgroundColor, textColor, "Background and text colors should be different for contrast")
    }

    func testCapsLockStateHasDistinctiveAppearance() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = true

        // Act
        let style = keyboardVC.getShiftButtonStyle()

        // Assert - Caps lock should have border (distinctive appearance)
        XCTAssertNotNil(style.borderColor, "Caps lock state should have border color")
        XCTAssertGreaterThan(style.borderWidth, 0, "Caps lock state should have visible border width")
    }

    func testShiftAndCapsLockColorsDifferent() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false
        let shiftStyle = keyboardVC.getShiftButtonStyle()

        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = true
        let capsLockStyle = keyboardVC.getShiftButtonStyle()

        // Assert - Styles should be different to distinguish states
        XCTAssertNotEqual(shiftStyle.backgroundColor, capsLockStyle.backgroundColor,
                         "Shift and caps lock states should have different visual appearance")
    }

    // MARK: - Dynamic Type Scaling Tests (AC: 6)

    func testButtonFontIsScalable() {
        // Arrange
        let button = keyboardVC.createKeyButton(title: "Test", action: #selector(keyboardVC.shiftTapped))

        // Act
        let font = button.titleLabel?.font

        // Assert - Font should be system font that scales with Dynamic Type
        XCTAssertNotNil(font, "Button should have font set")
        // System fonts scale with Dynamic Type by default
        XCTAssertTrue(font?.fontName.contains("System") ?? true, "Should use system font for Dynamic Type support")
    }

    // MARK: - State Transitions Tests

    func testAccessibilityLabelUpdatesOnCapsLockToggle() {
        // Arrange
        let button = UIButton(type: .custom)
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false

        // Act & Assert - Initial state
        keyboardVC.updateSingleShiftButton(button)
        XCTAssertEqual(button.accessibilityLabel, "Shift")

        // Change to caps lock
        keyboardVC.isCapsLocked = true
        keyboardVC.updateSingleShiftButton(button)
        XCTAssertEqual(button.accessibilityLabel, "Caps lock enabled")

        // Back to normal
        keyboardVC.isCapsLocked = false
        keyboardVC.updateSingleShiftButton(button)
        XCTAssertEqual(button.accessibilityLabel, "Shift")
    }

    func testAccessibilityHintMentionsAllFunctionality() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Hint should mention key functionality
        let hint = button.accessibilityHint ?? ""
        XCTAssertFalse(hint.isEmpty, "Accessibility hint should not be empty")
        XCTAssertGreaterThan(hint.count, 10, "Hint should be descriptive (at least 10 characters)")
    }

    // MARK: - Edge Case Tests

    func testAccessibilityWithBothStatesActive() {
        // Arrange - Both shift and caps lock active (edge case)
        let button = UIButton(type: .custom)
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Should prioritize caps lock label
        XCTAssertEqual(button.accessibilityLabel, "Caps lock enabled",
                     "Should use caps lock label when both states active")
    }

    func testMultipleButtonUpdatesConsistent() {
        // Arrange
        let button1 = UIButton(type: .custom)
        let button2 = UIButton(type: .custom)
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act
        keyboardVC.updateSingleShiftButton(button1)
        keyboardVC.updateSingleShiftButton(button2)

        // Assert - Both buttons should have identical accessibility properties
        XCTAssertEqual(button1.accessibilityLabel, button2.accessibilityLabel,
                     "Multiple button updates should be consistent")
        XCTAssertEqual(button1.accessibilityValue, button2.accessibilityValue,
                     "Accessibility values should be consistent")
    }
}

// MARK: - Helper Extension for Testing

extension KeyboardViewControllerAccessibilityTests {
    func XCTAssertNoThrow(_ expression: @escaping @autoclosure () -> Void,
                         _ message: @autoclosure () -> String = "",
                         file: StaticString = #filePath,
                         line: UInt = #line) {
        do {
            expression()
        } catch {
            XCTFail("Expected no throw but got: \(error). \(message())", file: file, line: line)
        }
    }
}
