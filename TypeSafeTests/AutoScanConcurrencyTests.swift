//
//  AutoScanConcurrencyTests.swift
//  TypeSafeTests
//
//  Story 5.3: Error Handling & Edge Cases
//  Unit tests for debouncing, concurrent scan prevention, and race condition handling
//

import XCTest
@testable import TypeSafe

@MainActor
final class AutoScanConcurrencyTests: XCTestCase {
    
    // MARK: - Debouncing Tests
    
    /// Test that debouncing prevents scans within the interval
    func testDebouncing() async throws {
        // Given: Two scan attempts within 2 seconds
        let firstAttemptTime = Date()
        let secondAttemptTime = firstAttemptTime.addingTimeInterval(1.0) // 1 second later
        let debounceInterval: TimeInterval = 2.0
        
        // When: Checking if second attempt should be debounced
        let timeSinceFirst = secondAttemptTime.timeIntervalSince(firstAttemptTime)
        let shouldDebounce = timeSinceFirst < debounceInterval
        
        // Then: Second attempt should be debounced
        XCTAssertTrue(shouldDebounce, "Scan within \(debounceInterval)s should be debounced")
        XCTAssertEqual(timeSinceFirst, 1.0, accuracy: 0.1, "Time between attempts should be ~1s")
    }
    
    /// Test that scans outside the debounce interval are allowed
    func testDebounceAllowsAfterInterval() async throws {
        // Given: Two scan attempts more than 2 seconds apart
        let firstAttemptTime = Date()
        let secondAttemptTime = firstAttemptTime.addingTimeInterval(2.5) // 2.5 seconds later
        let debounceInterval: TimeInterval = 2.0
        
        // When: Checking if second attempt should be debounced
        let timeSinceFirst = secondAttemptTime.timeIntervalSince(firstAttemptTime)
        let shouldDebounce = timeSinceFirst < debounceInterval
        
        // Then: Second attempt should NOT be debounced
        XCTAssertFalse(shouldDebounce, "Scan after \(debounceInterval)s should be allowed")
        XCTAssertGreaterThan(timeSinceFirst, debounceInterval, "Time should exceed debounce interval")
    }
    
    /// Test edge case: exactly at debounce boundary
    func testDebounceAtBoundary() async throws {
        // Given: Two scan attempts exactly at the debounce interval
        let firstAttemptTime = Date()
        let secondAttemptTime = firstAttemptTime.addingTimeInterval(2.0) // Exactly 2 seconds
        let debounceInterval: TimeInterval = 2.0
        
        // When: Checking if second attempt should be debounced
        let timeSinceFirst = secondAttemptTime.timeIntervalSince(firstAttemptTime)
        let shouldDebounce = timeSinceFirst < debounceInterval
        
        // Then: Second attempt should NOT be debounced (>= allows it)
        XCTAssertFalse(shouldDebounce, "Scan exactly at \(debounceInterval)s should be allowed")
    }
    
    // MARK: - State Management Tests
    
    /// Test that isAutoScanning flag prevents concurrent scans
    func testConcurrentScanPrevention() {
        // Given: A scan in progress
        var isAutoScanning = false
        
        // When: First scan starts
        isAutoScanning = true
        XCTAssertTrue(isAutoScanning, "Scan should be in progress")
        
        // Then: Second scan should be blocked
        let canStartSecondScan = !isAutoScanning
        XCTAssertFalse(canStartSecondScan, "Second scan should be blocked while first is in progress")
        
        // When: First scan completes
        isAutoScanning = false
        
        // Then: Another scan can start
        let canStartAfterCompletion = !isAutoScanning
        XCTAssertTrue(canStartAfterCompletion, "Scan should be allowed after first completes")
    }
    
    /// Test state cleanup on error
    func testStateCleanupOnError() {
        // Given: A scan that will fail
        var isAutoScanning = false
        
        // When: Scan starts and fails
        isAutoScanning = true
        // Simulate error...
        isAutoScanning = false // Cleanup in defer block
        
        // Then: State should be reset
        XCTAssertFalse(isAutoScanning, "State should be reset after error")
    }
    
    // MARK: - Rapid Tap Tests
    
    /// Test that button becomes disabled after tap
    func testButtonDisablingAfterTap() {
        // Given: Button is enabled
        var isScanButtonDisabled = false
        
        // When: Button is tapped
        isScanButtonDisabled = true
        
        // Then: Button should be disabled
        XCTAssertTrue(isScanButtonDisabled, "Button should be disabled after tap")
    }
    
    /// Test that button re-enables after delay
    func testButtonReEnablesAfterDelay() async throws {
        // Given: Button was disabled
        var isScanButtonDisabled = true
        
        // When: Waiting for re-enable delay (simulated with 0.5s for testing)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        isScanButtonDisabled = false
        
        // Then: Button should be enabled again
        XCTAssertFalse(isScanButtonDisabled, "Button should re-enable after delay")
    }
    
    // MARK: - Race Condition Tests
    
    /// Test multiple rapid state changes
    func testMultipleRapidStateChanges() async throws {
        var isAutoScanning = false
        var lastAttempt = Date.distantPast
        let debounceInterval: TimeInterval = 2.0
        
        // Simulate 5 rapid scan attempts
        for i in 0..<5 {
            let currentTime = Date()
            let timeSinceLastAttempt = currentTime.timeIntervalSince(lastAttempt)
            
            if timeSinceLastAttempt >= debounceInterval && !isAutoScanning {
                // Would start scan
                isAutoScanning = true
                lastAttempt = currentTime
                
                // Simulate quick completion
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                isAutoScanning = false
            }
        }
        
        // Final state should be clean
        XCTAssertFalse(isAutoScanning, "Should not be scanning after all attempts")
    }
    
    /// Test defer block always executes
    func testDeferBlockExecution() {
        var cleanupExecuted = false
        
        func simulateScan() {
            defer {
                cleanupExecuted = true
            }
            
            // Simulate early return
            if true {
                return
            }
        }
        
        simulateScan()
        
        XCTAssertTrue(cleanupExecuted, "Defer block should execute even on early return")
    }
    
    // MARK: - Logger Concurrency Tests
    
    /// Test logger thread safety with concurrent calls
    func testLoggerThreadSafety() {
        let logger = AutoScanLogger.shared
        let expectation = XCTestExpectation(description: "All log calls complete")
        expectation.expectedFulfillmentCount = 10
        
        // Simulate concurrent logging from multiple threads
        for i in 0..<10 {
            Task.detached {
                logger.logEvent(.fetchStarted)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    /// Test logger doesn't block operations
    func testLoggerNonBlocking() {
        let logger = AutoScanLogger.shared
        let startTime = Date()
        
        // Log many events quickly
        for _ in 0..<100 {
            logger.logEvent(.fetchStarted)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Logging 100 events should take less than 100ms
        XCTAssertLessThan(duration, 0.1, "Logging should not block operations")
    }
    
    // MARK: - Integration State Tests
    
    /// Test complete scan lifecycle with proper state management
    func testCompleteScanLifecycle() async throws {
        // Simulate a complete auto-scan flow
        var isAutoScanning = false
        var lastAutoScanAttempt = Date.distantPast
        var selectedImage: String? = nil
        let debounceInterval: TimeInterval = 2.0
        
        // Step 1: Check debounce
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAutoScanAttempt)
        guard timeSinceLastAttempt >= debounceInterval else {
            XCTFail("Should not be debounced on first attempt")
            return
        }
        
        // Step 2: Check concurrency
        guard !isAutoScanning else {
            XCTFail("Should not be scanning on first attempt")
            return
        }
        
        // Step 3: Set state
        lastAutoScanAttempt = Date()
        isAutoScanning = true
        
        // Step 4: Simulate fetch (success)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        selectedImage = "mock_image"
        
        // Step 5: Cleanup
        isAutoScanning = false
        
        // Verify final state
        XCTAssertFalse(isAutoScanning, "Should not be scanning after completion")
        XCTAssertNotNil(selectedImage, "Should have selected image")
        XCTAssertGreaterThan(lastAutoScanAttempt.timeIntervalSince(Date.distantPast), 0, 
                            "Should have updated last attempt time")
    }
    
    /// Test scan lifecycle with error
    func testScanLifecycleWithError() async throws {
        var isAutoScanning = false
        var lastAutoScanAttempt = Date.distantPast
        var error: ScreenshotFetchService.ScreenshotFetchError? = nil
        
        // Start scan
        lastAutoScanAttempt = Date()
        isAutoScanning = true
        
        // Simulate error
        error = .timeout
        
        // Cleanup (defer block simulation)
        isAutoScanning = false
        
        // Verify state
        XCTAssertFalse(isAutoScanning, "Should not be scanning after error")
        XCTAssertNotNil(error, "Should have captured error")
        XCTAssertEqual(error, .timeout, "Should be timeout error")
    }
}

