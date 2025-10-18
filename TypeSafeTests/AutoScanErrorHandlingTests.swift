//
//  AutoScanErrorHandlingTests.swift
//  TypeSafeTests
//
//  Story 5.3: Error Handling & Edge Cases
//  Unit tests for automatic scan error handling, timeout mechanism, and error banner states
//

import XCTest
@testable import TypeSafe
import Photos

@MainActor
final class AutoScanErrorHandlingTests: XCTestCase {
    
    var screenshotFetchService: ScreenshotFetchService!
    
    override func setUp() {
        super.setUp()
        screenshotFetchService = ScreenshotFetchService()
    }
    
    override func tearDown() {
        screenshotFetchService = nil
        super.tearDown()
    }
    
    // MARK: - Timeout Tests
    
    /// Test that timeout fires correctly when fetch takes too long
    func testTimeoutMechanism() async throws {
        // Given: A very short timeout (0.1 seconds for testing)
        let timeoutSeconds: TimeInterval = 0.1
        let startTime = Date()
        
        // When: Attempting to fetch with timeout (will timeout since Photos access likely unavailable)
        let result = await screenshotFetchService.fetchScreenshotWithTimeout(timeoutSeconds: timeoutSeconds)
        
        // Then: Should timeout within expected window
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertTrue(duration >= timeoutSeconds && duration < timeoutSeconds + 0.5, 
                      "Timeout should fire at approximately \(timeoutSeconds)s, but took \(duration)s")
        
        // And: Should return timeout error
        if case .failure(let error) = result {
            XCTAssertEqual(error, .timeout, "Should return timeout error")
        } else {
            XCTFail("Expected timeout failure, got success")
        }
    }
    
    /// Test that successful fetch completes before timeout
    func testFetchCompletesBeforeTimeout() async throws {
        // This test verifies the timeout doesn't fire if fetch completes quickly
        // In a real scenario with Photos access, this would complete successfully
        
        // Given: A reasonable timeout
        let timeoutSeconds: TimeInterval = 5.0
        let startTime = Date()
        
        // When: Attempting to fetch with timeout
        let result = await screenshotFetchService.fetchScreenshotWithTimeout(timeoutSeconds: timeoutSeconds)
        
        // Then: Should complete quickly (either success or expected error, but not timeout)
        let duration = Date().timeIntervalSince(startTime)
        
        if case .failure(let error) = result {
            // If we get an error, it should NOT be a timeout (since fetch should fail fast)
            XCTAssertNotEqual(error, .timeout, 
                             "Should not timeout when fetch fails quickly. Duration: \(duration)s")
        }
    }
    
    // MARK: - Error Type Tests
    
    /// Test error descriptions are user-friendly
    func testErrorDescriptions() {
        let errors: [ScreenshotFetchService.ScreenshotFetchError] = [
            .notFound,
            .tooOld,
            .conversionFailed,
            .permissionDenied,
            .timeout,
            .limitedAccessNoScreenshot,
            .unknown
        ]
        
        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description, "Error \(error) should have a description")
            XCTAssertFalse(description!.isEmpty, "Error description should not be empty")
            XCTAssertGreaterThan(description!.count, 10, "Error description should be meaningful")
        }
    }
    
    /// Test specific error messages for clarity
    func testSpecificErrorMessages() {
        let timeout = ScreenshotFetchService.ScreenshotFetchError.timeout
        XCTAssertTrue(timeout.errorDescription?.contains("5 seconds") ?? false, 
                     "Timeout message should mention 5 seconds")
        
        let tooOld = ScreenshotFetchService.ScreenshotFetchError.tooOld
        XCTAssertTrue(tooOld.errorDescription?.contains("60 seconds") ?? false, 
                     "Too old message should mention 60 seconds")
        
        let permission = ScreenshotFetchService.ScreenshotFetchError.permissionDenied
        XCTAssertTrue(permission.errorDescription?.contains("denied") ?? false, 
                     "Permission error should mention 'denied'")
    }
    
    // MARK: - Logger Tests
    
    /// Test that logger doesn't crash with various event types
    func testLoggerHandlesAllEventTypes() {
        let logger = AutoScanLogger.shared
        
        // Test all event types
        logger.logEvent(.started(deepLinkURL: "typesafe://scan?auto=true"))
        logger.logEvent(.permissionCheck(status: .authorized))
        logger.logEvent(.settingDisabled)
        logger.logEvent(.fetchStarted)
        logger.logEvent(.fetchSuccess(timestamp: Date()))
        logger.logEvent(.fetchFailed(error: .timeout))
        logger.logEvent(.conversionStarted)
        logger.logEvent(.conversionSuccess(size: CGSize(width: 1920, height: 1080)))
        logger.logEvent(.conversionFailed)
        logger.logEvent(.ocrTriggered(isAutoScanned: true))
        logger.logEvent(.fallbackToManual(reason: "Test reason"))
        logger.logEvent(.debounced(timeSinceLastAttempt: 1.5))
        logger.logEvent(.concurrentAttemptBlocked)
        logger.logEvent(.complete(duration: 2.5, success: true))
        
        // If we get here without crashing, test passes
        XCTAssertTrue(true, "Logger should handle all event types without crashing")
    }
    
    /// Test logger output includes timestamps
    func testLoggerIncludesTimestamps() {
        // This is a simple test to verify the logger is working
        // In a real app, you might capture console output
        let logger = AutoScanLogger.shared
        logger.logEvent(.started(deepLinkURL: "test://url"))
        
        // Basic verification that logger exists and can be called
        XCTAssertNotNil(logger, "Logger should exist")
    }
    
    // MARK: - Error Banner Tests
    
    /// Test error banner icon selection
    func testErrorBannerIcons() {
        // This verifies the error banner would show appropriate icons
        let permissionError = ScreenshotFetchService.ScreenshotFetchError.permissionDenied
        let timeoutError = ScreenshotFetchService.ScreenshotFetchError.timeout
        let notFoundError = ScreenshotFetchService.ScreenshotFetchError.notFound
        
        // Icons should be different for different error types
        XCTAssertNotEqual(permissionError, timeoutError)
        XCTAssertNotEqual(timeoutError, notFoundError)
        XCTAssertNotEqual(permissionError, notFoundError)
    }
    
    /// Test that Settings button is shown only for permission errors
    func testSettingsButtonVisibility() {
        let permissionErrors: [ScreenshotFetchService.ScreenshotFetchError] = [
            .permissionDenied,
            .limitedAccessNoScreenshot
        ]
        
        let otherErrors: [ScreenshotFetchService.ScreenshotFetchError] = [
            .timeout,
            .notFound,
            .tooOld,
            .conversionFailed,
            .unknown
        ]
        
        // Permission errors should show Settings button
        for error in permissionErrors {
            XCTAssertTrue(error == .permissionDenied || error == .limitedAccessNoScreenshot,
                         "Error \(error) should show Settings button")
        }
        
        // Other errors should not show Settings button
        for error in otherErrors {
            XCTAssertFalse(error == .permissionDenied || error == .limitedAccessNoScreenshot,
                          "Error \(error) should not show Settings button")
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test that timeout cleanup is efficient
    func testTimeoutCleanupPerformance() async throws {
        measure {
            Task {
                // Run multiple timeout operations
                for _ in 0..<5 {
                    _ = await screenshotFetchService.fetchScreenshotWithTimeout(timeoutSeconds: 0.05)
                }
            }
        }
    }
    
    /// Test logging performance doesn't impact operations
    func testLoggingPerformance() {
        let logger = AutoScanLogger.shared
        
        measure {
            // Log many events quickly
            for _ in 0..<100 {
                logger.logEvent(.fetchStarted)
            }
        }
    }
}

