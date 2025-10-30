//
//  KeyboardViewControllerShiftButtonVisualTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 29/10/25.
//  Story 13.2: Shift Button Visual Indicators - Visual Testing
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardViewControllerShiftButtonVisualTests: XCTestCase {

    // MARK: - Test Properties
    var keyboardVC: KeyboardViewController!
    var testButton: UIButton!

    override func setUp() {
        super.setUp()
        keyboardVC = KeyboardViewController()
        // Load view to trigger viewDidLoad
        _ = keyboardVC.view

        // Create a test button for visual updates
        testButton = UIButton(type: .custom)
        testButton.setTitle("⇧", for: .normal)
    }

    override func tearDown() {
        testButton = nil
        keyboardVC = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Helper to access the shift button from keyboard view hierarchy
    func findShiftButton() -> UIButton? {
        // Recursively search for shift button with "⇧" or "⇪" symbol
        func findButton(in view: UIView) -> UIButton? {
            if let button = view as? UIButton,
               let title = button.titleLabel?.text,
               (title.contains("⇧") || title.contains("⇪")) {
                return button
            }

            for subview in view.subviews {
                if let button = findButton(in: subview) {
                    return button
                }
            }
            return nil
        }

        return findButton(in: keyboardVC.view)
    }

    // MARK: - Normal State Tests

    func testShiftButtonNormalStateAppearance() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false

        // Act
        if let button = findShiftButton() {
            // Simulate the style getter indirectly by checking button properties
            let style = keyboardVC.getShiftButtonStyle()

            // Assert - Normal state should have default colors
            XCTAssertEqual(style.backgroundColor, keyboardVC.lightShiftNormalColor,
                         "Normal state should use normal shift color in light mode")
            XCTAssertNil(style.borderColor, "Normal state should have no border")
            XCTAssertEqual(style.borderWidth, 0, "Normal state border width should be 0")
        }
    }

    func testShiftButtonNormalStateSymbol() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false

        // Act
        if let button = findShiftButton() {
            keyboardVC.updateSingleShiftButton(button)

            // Assert
            let title = button.titleLabel?.text
            XCTAssertEqual(title, "⇧", "Normal state should display shift symbol ⇧")
        }
    }

    // MARK: - Shift Active State Tests

    func testShiftButtonActiveStateAppearance() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act
        let style = keyboardVC.getShiftButtonStyle()

        // Assert - Shift active state should have highlight color
        XCTAssertNotNil(style.backgroundColor, "Shift active state should have background color")
        XCTAssertNil(style.borderColor, "Shift active state should have no border")
        XCTAssertEqual(style.borderWidth, 0, "Shift active state border width should be 0")
    }

    func testShiftButtonActiveStateSymbol() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act
        if let button = findShiftButton() {
            keyboardVC.updateSingleShiftButton(button)

            // Assert
            let title = button.titleLabel?.text
            XCTAssertEqual(title, "⇧", "Shift active state should display shift symbol ⇧")
        }
    }

    // MARK: - Caps Lock State Tests

    func testShiftButtonCapsLockStateAppearance() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = true

        // Act
        let style = keyboardVC.getShiftButtonStyle()

        // Assert - Caps lock state should have distinctive appearance
        XCTAssertNotNil(style.backgroundColor, "Caps lock state should have background color")
        XCTAssertNotNil(style.borderColor, "Caps lock state should have border color")
        XCTAssertEqual(style.borderWidth, 2.0, "Caps lock state should have 2pt border")
        XCTAssertEqual(style.textColor, UIColor.white, "Caps lock state should have white text")
    }

    func testShiftButtonCapsLockStateSymbol() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = true

        // Act
        if let button = findShiftButton() {
            keyboardVC.updateSingleShiftButton(button)

            // Assert
            let title = button.titleLabel?.text
            XCTAssertEqual(title, "⇪", "Caps lock state should display caps lock symbol ⇪")
        }
    }

    // MARK: - State Priority Tests

    func testCapsLockTakesPriorityOverShift() {
        // Arrange - Both states active (shouldn't normally happen, but test priority)
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = true

        // Act
        let style = keyboardVC.getShiftButtonStyle()

        // Assert - Caps lock appearance should take priority
        XCTAssertNotNil(style.borderColor, "Caps lock priority should show border")
        XCTAssertEqual(style.borderWidth, 2.0, "Caps lock priority should maintain 2pt border")
        XCTAssertEqual(style.textColor, UIColor.white, "Caps lock priority should maintain white text")
    }

    // MARK: - Light/Dark Mode Tests

    func testShiftButtonNormalStateLightMode() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        // Set light mode (default)

        // Act
        let style = keyboardVC.getShiftButtonStyle()

        // Assert - Light mode colors
        XCTAssertEqual(style.backgroundColor, keyboardVC.lightShiftNormalColor,
                     "Light mode normal state should use light shift normal color")
    }

    func testShiftButtonActiveStateLightMode() {
        // Arrange
        keyboardVC.isShifted = true
        keyboardVC.isCapsLocked = false

        // Act
        let style = keyboardVC.getShiftButtonStyle()

        // Assert - Light mode shift active color
        XCTAssertEqual(style.backgroundColor, keyboardVC.lightShiftActiveColor,
                     "Light mode shift active should use light shift active color")
    }

    func testShiftButtonCapsLockLightMode() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = true

        // Act
        let style = keyboardVC.getShiftButtonStyle()

        // Assert - Light mode caps lock color
        XCTAssertEqual(style.backgroundColor, keyboardVC.lightCapsLockColor,
                     "Light mode caps lock should use light caps lock color")
    }

    // MARK: - Visual Update Tests

    func testUpdateSingleShiftButtonAppliesCorrectColors() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Button colors should match style
        XCTAssertNotNil(button.backgroundColor, "Button should have background color set")
        let expectedStyle = keyboardVC.getShiftButtonStyle()
        XCTAssertEqual(button.backgroundColor, expectedStyle.backgroundColor,
                     "Button background should match style")
    }

    func testUpdateSingleShiftButtonAppliesBorder() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = true
        let button = UIButton(type: .custom)
        button.layer.borderWidth = 0

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Caps lock state should have border
        XCTAssertEqual(button.layer.borderWidth, 2.0, "Caps lock state should apply 2pt border")
    }

    func testUpdateSingleShiftButtonRemovesBorderWhenNotCapsLock() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = false
        let button = UIButton(type: .custom)
        button.layer.borderWidth = 2.0  // Start with border

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Normal/shift states should have no border
        XCTAssertEqual(button.layer.borderWidth, 0, "Normal state should remove border")
    }

    func testUpdateSingleShiftButtonAppliesTextColor() {
        // Arrange
        keyboardVC.isShifted = false
        keyboardVC.isCapsLocked = true
        let button = UIButton(type: .custom)

        // Act
        keyboardVC.updateSingleShiftButton(button)

        // Assert - Text color should be set
        let titleColor = button.titleColor(for: .normal)
        XCTAssertEqual(titleColor, UIColor.white, "Caps lock state should use white text color")
    }

    // MARK: - Contrast/Accessibility Tests

    func testCapsLockColorHasAdequateContrast() {
        // Arrange - Orange color should have good contrast with white text
        let capsLockColor = keyboardVC.lightCapsLockColor

        // Act - Calculate relative luminance (simplified WCAG calculation)
        let components = capsLockColor.cgColor.components ?? [1, 1, 1, 1]
        let r = components[0]
        let g = components[1]
        let b = components[2]

        let luminance = 0.299 * r + 0.587 * g + 0.114 * b

        // Assert - Orange should have luminance between 0.2 and 0.8 for good contrast
        // White text luminance = 1.0, so luminance difference should be significant
        XCTAssertGreaterThan(luminance, 0.3, "Caps lock color should have sufficient luminance")
        XCTAssertLessThan(luminance, 0.9, "Caps lock color should not be too bright")
    }

    // MARK: - State Transition Tests

    func testShiftStateTransitionNormalToActive() {
        // Arrange
        keyboardVC.isShifted = false
        let style1 = keyboardVC.getShiftButtonStyle()

        // Act
        keyboardVC.isShifted = true
        let style2 = keyboardVC.getShiftButtonStyle()

        // Assert - Colors should change
        XCTAssertNotEqual(style1.backgroundColor, style2.backgroundColor,
                        "Colors should change from normal to shift active")
    }

    func testShiftStateTransitionActiveToNormal() {
        // Arrange
        keyboardVC.isShifted = true
        let style1 = keyboardVC.getShiftButtonStyle()

        // Act
        keyboardVC.isShifted = false
        let style2 = keyboardVC.getShiftButtonStyle()

        // Assert - Colors should revert
        XCTAssertNotEqual(style1.backgroundColor, style2.backgroundColor,
                        "Colors should revert from shift active to normal")
    }

    func testCapsLockStateTransitionNormalToCapsLock() {
        // Arrange
        keyboardVC.isCapsLocked = false
        let style1 = keyboardVC.getShiftButtonStyle()

        // Act
        keyboardVC.isCapsLocked = true
        let style2 = keyboardVC.getShiftButtonStyle()

        // Assert - Border should be added and colors should change
        XCTAssertNil(style1.borderColor, "Normal state should not have border")
        XCTAssertNotNil(style2.borderColor, "Caps lock state should have border")
    }

    func testCapsLockStateTransitionToCapsLockToNormal() {
        // Arrange
        keyboardVC.isCapsLocked = true
        let style1 = keyboardVC.getShiftButtonStyle()

        // Act
        keyboardVC.isCapsLocked = false
        let style2 = keyboardVC.getShiftButtonStyle()

        // Assert - Border should be removed
        XCTAssertNotNil(style1.borderColor, "Caps lock state should have border")
        XCTAssertNil(style2.borderColor, "Normal state should not have border")
    }

    // MARK: - Color Constants Tests

    func testColorConstantsAreDefined() {
        // Arrange & Act - Access color constants
        let lightNormal = keyboardVC.lightShiftNormalColor
        let lightActive = keyboardVC.lightShiftActiveColor
        let lightCapsLock = keyboardVC.lightCapsLockColor

        let darkNormal = keyboardVC.darkShiftNormalColor
        let darkActive = keyboardVC.darkShiftActiveColor
        let darkCapsLock = keyboardVC.darkCapsLockColor

        // Assert - All colors should be defined and not nil
        XCTAssertNotNil(lightNormal, "Light normal color should be defined")
        XCTAssertNotNil(lightActive, "Light active color should be defined")
        XCTAssertNotNil(lightCapsLock, "Light caps lock color should be defined")
        XCTAssertNotNil(darkNormal, "Dark normal color should be defined")
        XCTAssertNotNil(darkActive, "Dark active color should be defined")
        XCTAssertNotNil(darkCapsLock, "Dark caps lock color should be defined")
    }

    func testColorConstantsAreDifferentiated() {
        // Arrange & Act
        let lightNormal = keyboardVC.lightShiftNormalColor
        let lightActive = keyboardVC.lightShiftActiveColor
        let lightCapsLock = keyboardVC.lightCapsLockColor

        // Assert - Each state should have distinct color
        XCTAssertNotEqual(lightNormal, lightActive, "Normal and active colors should differ")
        XCTAssertNotEqual(lightActive, lightCapsLock, "Active and caps lock colors should differ")
        XCTAssertNotEqual(lightNormal, lightCapsLock, "Normal and caps lock colors should differ")
    }
}
