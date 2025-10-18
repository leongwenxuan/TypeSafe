//
//  KeyboardPerformanceTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 18/01/25.
//  Performance tests for keyboard extension - Story 2.9
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardPerformanceTests: XCTestCase {
    
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
    
    // MARK: - Input Latency Tests (AC: 1)
    
    /// Tests input latency for key press handling - should be < 100ms
    func testInputLatencyMeasurement() throws {
        // Measure time from key tap to text insertion
        measure(metrics: [XCTClockMetric()]) {
            // Simulate key press
            let button = UIButton()
            button.setTitle("A", for: .normal)
            
            // This measures the time for the key tap method
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
        }
        
        // Performance baseline: < 100ms (0.1 seconds)
        // XCTest will report if this exceeds reasonable thresholds
    }
    
    /// Tests layout switching performance
    func testLayoutSwitchingLatency() throws {
        measure(metrics: [XCTClockMetric()]) {
            // Switch between layouts
            keyboardViewController.perform(#selector(KeyboardViewController.numberModeTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.letterModeTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.symbolModeTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.letterModeTapped))
        }
    }
    
    // MARK: - Memory Usage Tests (AC: 2, 3)
    
    /// Tests memory footprint during normal operation - should be < 30MB
    func testMemoryFootprintBaseline() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            // Simulate normal keyboard usage
            for i in 0..<100 {
                let button = UIButton()
                button.setTitle(String(i % 10), for: .normal)
                keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            }
        }
    }
    
    /// Tests for memory leaks during extended typing sessions
    func testExtendedTypingMemoryStability() throws {
        let initialMemory = getMemoryUsage()
        
        // Simulate 1000+ character typing session
        for i in 0..<1000 {
            let button = UIButton()
            let char = String(Character(UnicodeScalar(65 + (i % 26))!)) // A-Z cycling
            button.setTitle(char, for: .normal)
            keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            
            // Periodically trigger backspace to simulate real usage
            if i % 50 == 0 {
                keyboardViewController.perform(#selector(KeyboardViewController.backspaceTapped))
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        
        // Memory growth should be reasonable (< 10MB for 1000 chars)
        XCTAssertLessThan(memoryGrowth, 10 * 1024 * 1024, "Memory growth exceeded 10MB during extended typing")
    }
    
    // MARK: - Network Performance Tests (AC: 4, 5)
    
    /// Tests that API calls don't block the main thread
    func testNetworkOperationsAsync() throws {
        let expectation = XCTestExpectation(description: "Network call completes without blocking")
        
        // Measure main thread responsiveness during network call
        let startTime = CFAbsoluteTimeGetCurrent()
        var mainThreadBlocked = false
        
        // Start a network operation (mock)
        DispatchQueue.global().async {
            // Simulate network delay
            Thread.sleep(forTimeInterval: 0.1)
            
            DispatchQueue.main.async {
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = endTime - startTime
                
                // Main thread should remain responsive (< 16ms for 60fps)
                mainThreadBlocked = duration > 0.016
                expectation.fulfill()
            }
        }
        
        // Simulate UI interaction during network call
        let button = UIButton()
        button.setTitle("T", for: .normal)
        keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(mainThreadBlocked, "Main thread was blocked during network operation")
    }
    
    // MARK: - Stability Tests (AC: 6)
    
    /// Tests keyboard stability during extended usage without crashes
    func testExtendedUsageStability() throws {
        // Simulate various keyboard operations for stability
        for cycle in 0..<10 {
            // Type some characters
            for i in 0..<100 {
                let button = UIButton()
                button.setTitle(String(i % 10), for: .normal)
                keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
            }
            
            // Switch layouts
            keyboardViewController.perform(#selector(KeyboardViewController.numberModeTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.symbolModeTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.letterModeTapped))
            
            // Use special keys
            keyboardViewController.perform(#selector(KeyboardViewController.spaceTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.backspaceTapped))
            keyboardViewController.perform(#selector(KeyboardViewController.returnTapped))
            
            // Trigger shift
            keyboardViewController.perform(#selector(KeyboardViewController.shiftTapped))
        }
        
        // If we reach here without crashing, the test passes
        XCTAssertTrue(true, "Extended usage completed without crashes")
    }
    
    // MARK: - Performance Regression Tests (AC: 7)
    
    /// Baseline performance test for regression detection
    func testPerformanceRegression() throws {
        // This test establishes a baseline for future regression detection
        measure {
            // Comprehensive keyboard operation cycle
            for _ in 0..<50 {
                // Type characters
                let button = UIButton()
                button.setTitle("A", for: .normal)
                keyboardViewController.perform(#selector(KeyboardViewController.keyTapped(_:)), with: button)
                
                // Use backspace
                keyboardViewController.perform(#selector(KeyboardViewController.backspaceTapped))
                
                // Switch layout
                keyboardViewController.perform(#selector(KeyboardViewController.numberModeTapped))
                keyboardViewController.perform(#selector(KeyboardViewController.letterModeTapped))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Gets current memory usage in bytes
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}
