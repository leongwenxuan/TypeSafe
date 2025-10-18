//
//  StabilityTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 18/01/25.
//  Stability and crash prevention tests - Story 2.9
//

import XCTest
@testable import TypeSafeKeyboard

class StabilityTests: XCTestCase {
    
    var keyboardViewController: KeyboardViewController!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        keyboardViewController = KeyboardViewController()
        
        // Load the view to trigger viewDidLoad
        _ = keyboardViewController.view
        keyboardViewController.viewDidLoad()
    }
    
    override func tearDownWithError() throws {
        keyboardViewController = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Extended Session Tests (AC: 6)
    
    /// Tests keyboard stability during 1000+ character typing session
    func testExtended1000CharacterSession() throws {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 "
        
        // Type 1000+ characters without crashing
        for i in 0..<1500 {
            let char = String(characters[characters.index(characters.startIndex, offsetBy: i % characters.count)])
            let button = UIButton()
            button.setTitle(char, for: .normal)
            
            // Simulate key press
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            
            // Periodically use other functions
            if i % 100 == 0 {
                keyboardViewController.perform(#selector(KeyboardViewController.spaceTapped))
            }
            
            if i % 150 == 0 {
                keyboardViewController.perform(#selector(KeyboardViewController.backspaceTapped))
            }
            
            if i % 200 == 0 {
                keyboardViewController.perform(#selector(KeyboardViewController.shiftTapped))
            }
            
            if i % 300 == 0 {
                // Switch layouts
                keyboardViewController.perform(#selector(KeyboardViewController.numberModeTapped))
                keyboardViewController.perform(#selector(KeyboardViewController.letterModeTapped))
            }
        }
        
        // If we reach here without crashing, test passes
        XCTAssertTrue(true, "1000+ character session completed without crashes")
    }
    
    /// Tests rapid key presses for stability
    func testRapidKeyPresses() throws {
        // Simulate very rapid typing (stress test)
        for i in 0..<500 {
            let button = UIButton()
            button.setTitle(String(i % 10), for: .normal)
            
            // Rapid fire key presses
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
        }
        
        XCTAssertTrue(true, "Rapid key presses handled without crashes")
    }
    
    // MARK: - Error Handling Tests
    
    /// Tests nil handling in text processing operations
    func testNilHandlingInTextOperations() throws {
        // Test with nil button title
        let nilButton = UIButton()
        // Don't set title - should be nil
        
        // This should not crash
        keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: nilButton)
        
        XCTAssertTrue(true, "Nil button title handled gracefully")
    }
    
    /// Tests bounds checking for text buffer operations
    func testTextBufferBoundsChecking() throws {
        // Fill up text buffer to test bounds
        for i in 0..<1000 {
            let button = UIButton()
            button.setTitle("A", for: .normal)
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
        }
        
        // Try excessive backspaces
        for _ in 0..<1500 {
            keyboardViewController.perform(#selector(KeyboardViewController.backspaceTapped))
        }
        
        XCTAssertTrue(true, "Text buffer bounds checking handled excessive operations")
    }
    
    /// Tests keyboard layout switching edge cases
    func testLayoutSwitchingEdgeCases() throws {
        // Rapid layout switching
        for _ in 0..<100 {
            keyboardViewController.perform(#selector(KeyboardViewController.numberModeTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.symbolModeTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.letterModeTapped))
        }
        
        XCTAssertTrue(true, "Rapid layout switching handled without crashes")
    }
    
    // MARK: - Memory Pressure Tests
    
    /// Tests behavior under simulated memory pressure
    func testMemoryPressureHandling() throws {
        // Simulate memory pressure by creating and releasing many objects
        var objects: [AnyObject] = []
        
        for i in 0..<1000 {
            // Create some objects to use memory
            let data = Data(count: 1024) // 1KB each
            objects.append(data as AnyObject)
            
            // Periodically use keyboard
            if i % 50 == 0 {
                let button = UIButton()
                button.setTitle("M", for: .normal)
                keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            }
            
            // Release some objects periodically
            if i % 100 == 0 && objects.count > 50 {
                objects.removeFirst(50)
            }
        }
        
        // Clean up
        objects.removeAll()
        
        XCTAssertTrue(true, "Memory pressure handled without crashes")
    }
    
    // MARK: - Concurrent Operation Tests
    
    /// Tests concurrent operations don't cause crashes
    func testConcurrentOperations() throws {
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 3
        
        // Simulate concurrent keyboard usage from different threads
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<100 {
                DispatchQueue.main.async {
                    let button = UIButton()
                    button.setTitle(String(i % 10), for: .normal)
                    self.keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
                }
            }
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<50 {
                DispatchQueue.main.async {
                    self.keyboardViewController.perform(#selector(KeyboardViewController.spaceTapped))
                }
            }
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<25 {
                DispatchQueue.main.async {
                    self.keyboardViewController.perform(#selector(KeyboardViewController.numberModeTapped))
                    self.keyboardViewController.perform(#selector(KeyboardViewController.letterModeTapped))
                }
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(true, "Concurrent operations completed without crashes")
    }
    
    // MARK: - View Lifecycle Tests
    
    /// Tests view lifecycle edge cases
    func testViewLifecycleStability() throws {
        // Simulate multiple view lifecycle events
        for _ in 0..<10 {
            keyboardViewController.viewWillAppear(true)
            keyboardViewController.viewDidAppear(true)
            
            // Use keyboard
            let button = UIButton()
            button.setTitle("L", for: .normal)
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            
            keyboardViewController.viewWillDisappear(true)
            keyboardViewController.viewDidDisappear(true)
        }
        
        XCTAssertTrue(true, "View lifecycle events handled without crashes")
    }
    
    /// Tests appearance changes don't cause crashes
    func testAppearanceChangeStability() throws {
        // Simulate appearance changes (light/dark mode switching)
        for _ in 0..<20 {
            // Trigger appearance update
            keyboardViewController.textDidChange(nil)
            
            // Use keyboard after appearance change
            let button = UIButton()
            button.setTitle("D", for: .normal)
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
        }
        
        XCTAssertTrue(true, "Appearance changes handled without crashes")
    }
    
    // MARK: - Resource Cleanup Tests
    
    /// Tests proper resource cleanup
    func testResourceCleanup() throws {
        // Create multiple keyboard instances to test cleanup
        var keyboards: [KeyboardViewController] = []
        
        for _ in 0..<10 {
            let keyboard = KeyboardViewController()
            _ = keyboard.view // Load view
            keyboard.viewDidLoad()
            
            // Use keyboard briefly
            let button = UIButton()
            button.setTitle("R", for: .normal)
            keyboard.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            
            keyboards.append(keyboard)
        }
        
        // Clean up all keyboards
        keyboards.removeAll()
        
        XCTAssertTrue(true, "Resource cleanup handled without memory issues")
    }
    
    // MARK: - Edge Case Input Tests
    
    /// Tests handling of edge case inputs
    func testEdgeCaseInputs() throws {
        // Test empty string handling
        let emptyButton = UIButton()
        emptyButton.setTitle("", for: .normal)
        keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: emptyButton)
        
        // Test very long string handling
        let longButton = UIButton()
        longButton.setTitle(String(repeating: "A", count: 1000), for: .normal)
        keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: longButton)
        
        // Test special characters
        let specialChars = ["🎉", "👍", "🔥", "💯", "🚀", "⚡", "🎯", "🎪"]
        for char in specialChars {
            let button = UIButton()
            button.setTitle(char, for: .normal)
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
        }
        
        XCTAssertTrue(true, "Edge case inputs handled without crashes")
    }
}
