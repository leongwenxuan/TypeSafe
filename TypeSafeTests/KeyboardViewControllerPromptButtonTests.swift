//
//  KeyboardViewControllerPromptButtonTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 20/10/25.
//  Story 9.1: Keyboard Layout Reorganization - Prompt Button Tests
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardViewControllerPromptButtonTests: XCTestCase {

    // MARK: - Test Properties
    var keyboardVC: KeyboardViewController!

    override func setUp() {
        super.setUp()
        keyboardVC = KeyboardViewController()
        // Load view to trigger viewDidLoad and setupTopToolbar
        _ = keyboardVC.view
    }

    override func tearDown() {
        keyboardVC = nil
        super.tearDown()
    }

    // MARK: - Button Existence Tests

    func testPromptButtonExistsInToolbar() {
        // Arrange & Act - Button is created in setUp via viewDidLoad

        // Assert - Check that prompt button exists in view hierarchy
        let promptButtonExists = keyboardVC.view.subviews.contains { view in
            view.subviews.contains { subview in
                if let button = subview as? UIButton,
                   button.titleLabel?.text?.contains("🔍") == true {
                    return true
                }
                return false
            }
        }

        XCTAssertTrue(promptButtonExists, "Prompt button should exist in toolbar")
    }

    func testSettingsButtonMovedToLeft() {
        // Arrange & Act - Layout is set in setUp

        // Assert - Find settings button and check it's on the left side
        var settingsButton: UIButton?
        for view in keyboardVC.view.subviews {
            for subview in view.subviews {
                if let button = subview as? UIButton,
                   button.titleLabel?.text == "⚙️" {
                    settingsButton = button
                    break
                }
            }
        }

        XCTAssertNotNil(settingsButton, "Settings button should exist")

        // Check that settings button is positioned on the left (frame x should be small)
        if let button = settingsButton {
            XCTAssertLessThan(button.frame.minX, 100, "Settings button should be on the left side")
        }
    }

    func testPromptButtonOnRight() {
        // Arrange & Act - Layout is set in setUp

        // Assert - Find prompt button and check it's on the right side
        var promptButton: UIButton?
        for view in keyboardVC.view.subviews {
            for subview in view.subviews {
                if let button = subview as? UIButton,
                   button.titleLabel?.text?.contains("🔍") == true {
                    promptButton = button
                    break
                }
            }
        }

        XCTAssertNotNil(promptButton, "Prompt button should exist")

        // Check that prompt button is positioned on the right (frame x should be large)
        if let button = promptButton {
            let screenWidth = keyboardVC.view.frame.width
            XCTAssertGreaterThan(button.frame.maxX, screenWidth - 100, "Prompt button should be on the right side")
        }
    }

    // MARK: - Button State Management Tests

    func testPromptButtonDisabledWhenTextEmpty() {
        // Arrange - Keyboard just loaded, no text input

        // Act - Trigger state update with empty text (simulate viewDidLoad call)
        keyboardVC.textDidChange(nil)

        // Wait for UI update
        let expectation = XCTestExpectation(description: "Button state updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert - Find prompt button and verify it's disabled
        var promptButton: UIButton?
        for view in keyboardVC.view.subviews {
            for subview in view.subviews {
                if let button = subview as? UIButton,
                   button.titleLabel?.text?.contains("🔍") == true {
                    promptButton = button
                    break
                }
            }
        }

        XCTAssertNotNil(promptButton, "Prompt button should exist")
        if let button = promptButton {
            XCTAssertFalse(button.isEnabled, "Prompt button should be disabled when text is empty")
            XCTAssertEqual(button.alpha, 0.5, accuracy: 0.01, "Prompt button alpha should be 0.5 when disabled")
        }
    }

    // MARK: - Button Styling Tests

    func testPromptButtonStyling() {
        // Arrange & Act - Button is styled in setUp

        // Assert - Find prompt button and verify styling
        var promptButton: UIButton?
        for view in keyboardVC.view.subviews {
            for subview in view.subviews {
                if let button = subview as? UIButton,
                   button.titleLabel?.text?.contains("🔍") == true {
                    promptButton = button
                    break
                }
            }
        }

        XCTAssertNotNil(promptButton, "Prompt button should exist")

        if let button = promptButton {
            // Check corner radius
            XCTAssertEqual(button.layer.cornerRadius, 6, accuracy: 0.1, "Button should have corner radius of 6")

            // Check font
            XCTAssertEqual(button.titleLabel?.font.pointSize, 14, accuracy: 0.1, "Button font size should be 14")

            // Check background color (should have blue tint)
            XCTAssertNotNil(button.backgroundColor, "Button should have background color")

            // Check title color
            XCTAssertEqual(button.titleColor(for: .normal), .systemBlue, "Button title color should be system blue")
        }
    }

    // MARK: - Button Tap Tests

    func testPromptButtonTapTriggersHandler() {
        // Arrange - Find prompt button
        var promptButton: UIButton?
        for view in keyboardVC.view.subviews {
            for subview in view.subviews {
                if let button = subview as? UIButton,
                   button.titleLabel?.text?.contains("🔍") == true {
                    promptButton = button
                    break
                }
            }
        }

        XCTAssertNotNil(promptButton, "Prompt button should exist")

        // Act - Simulate button tap
        if let button = promptButton {
            // Enable button first
            button.isEnabled = true

            // Trigger tap action
            button.sendActions(for: .touchUpInside)

            // Wait for action to process
            let expectation = XCTestExpectation(description: "Button tap processed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)

            // Assert - Check that toast message was created (tag 9999)
            let toastExists = keyboardVC.view.subviews.contains { $0.tag == 9999 }
            XCTAssertTrue(toastExists, "Toast message should appear after button tap")
        }
    }

    // MARK: - Layout Tests

    func testButtonDimensionsAreCorrect() {
        // Arrange & Act - Layout is set in setUp

        // Wait for layout to complete
        let expectation = XCTestExpectation(description: "Layout completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert - Find prompt button and verify dimensions
        var promptButton: UIButton?
        for view in keyboardVC.view.subviews {
            for subview in view.subviews {
                if let button = subview as? UIButton,
                   button.titleLabel?.text?.contains("🔍") == true {
                    promptButton = button
                    break
                }
            }
        }

        XCTAssertNotNil(promptButton, "Prompt button should exist")

        if let button = promptButton {
            // Check width (should be around 80pt)
            XCTAssertGreaterThan(button.frame.width, 60, "Button width should be at least 60pt")
            XCTAssertLessThan(button.frame.width, 100, "Button width should be at most 100pt")

            // Check height (should be around 28pt)
            XCTAssertGreaterThan(button.frame.height, 20, "Button height should be at least 20pt")
            XCTAssertLessThan(button.frame.height, 40, "Button height should be at most 40pt")
        }
    }
}
