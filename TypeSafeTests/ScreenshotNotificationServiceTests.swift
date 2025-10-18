//
//  ScreenshotNotificationServiceTests.swift
//  TypeSafeTests
//
//  Story 4.2: Screenshot Alert Prompt in Keyboard
//  Unit tests for screenshot notification polling service
//

import XCTest
@testable import TypeSafeKeyboard

class ScreenshotNotificationServiceTests: XCTestCase {
    
    var service: ScreenshotNotificationService!
    var mockStorageManager: MockSharedStorageManager!
    
    override func setUp() {
        super.setUp()
        mockStorageManager = MockSharedStorageManager()
        service = ScreenshotNotificationService(storageManager: mockStorageManager)
    }
    
    override func tearDown() {
        service.stopPolling()
        service = nil
        mockStorageManager = nil
        super.tearDown()
    }
    
    // MARK: - Polling Lifecycle Tests
    
    func testStartPolling_SetsIsPollingToTrue() {
        // When
        service.startPolling()
        
        // Then
        XCTAssertTrue(service.isPolling, "Service should be polling after start")
    }
    
    func testStopPolling_SetsIsPollingToFalse() {
        // Given
        service.startPolling()
        
        // When
        service.stopPolling()
        
        // Then
        XCTAssertFalse(service.isPolling, "Service should not be polling after stop")
    }
    
    func testStartPolling_WhenAlreadyPolling_StopsExistingTimer() {
        // Given
        service.startPolling()
        let expectation = XCTestExpectation(description: "First notification received")
        var callCount = 0
        
        service.onNewNotification = { _ in
            callCount += 1
            expectation.fulfill()
        }
        
        // Add a notification
        mockStorageManager.addNotification(ScreenshotNotification(timestamp: Date()))
        
        // When
        service.startPolling() // Start again
        
        // Then - should only get called once
        wait(for: [expectation], timeout: 0.5)
        XCTAssertEqual(callCount, 1, "Should only receive one notification")
    }
    
    // MARK: - Notification Detection Tests
    
    func testNewNotification_TriggersCallback() {
        // Given
        let expectation = XCTestExpectation(description: "New notification callback")
        var receivedNotification: ScreenshotNotification?
        
        service.onNewNotification = { notification in
            receivedNotification = notification
            expectation.fulfill()
        }
        
        let testNotification = ScreenshotNotification(timestamp: Date())
        mockStorageManager.addNotification(testNotification)
        
        // When
        service.startPolling()
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        XCTAssertNotNil(receivedNotification, "Should receive notification")
        XCTAssertEqual(receivedNotification?.id, testNotification.id, "Should receive correct notification")
    }
    
    func testDuplicateNotification_DoesNotTriggerCallbackTwice() {
        // Given
        let expectation = XCTestExpectation(description: "Single notification callback")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        
        service.onNewNotification = { _ in
            expectation.fulfill()
        }
        
        let testNotification = ScreenshotNotification(timestamp: Date())
        mockStorageManager.addNotification(testNotification)
        
        // When
        service.startPolling()
        
        // Then - Wait longer than polling interval to ensure it doesn't fire twice
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExpiredNotification_DoesNotTriggerCallback() {
        // Given
        let expectation = XCTestExpectation(description: "No callback for expired")
        expectation.isInverted = true
        
        service.onNewNotification = { _ in
            expectation.fulfill()
        }
        
        // Create expired notification (2 minutes old)
        let expiredTimestamp = Date().addingTimeInterval(-120)
        let expiredNotification = ScreenshotNotification(timestamp: expiredTimestamp)
        mockStorageManager.addNotification(expiredNotification)
        
        // When
        service.startPolling()
        
        // Then
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testNotificationOlderThan60Seconds_DoesNotTriggerCallback() {
        // Given
        let expectation = XCTestExpectation(description: "No callback for old notification")
        expectation.isInverted = true
        
        service.onNewNotification = { _ in
            expectation.fulfill()
        }
        
        // Create notification 61 seconds old
        let oldTimestamp = Date().addingTimeInterval(-61)
        let oldNotification = ScreenshotNotification(timestamp: oldTimestamp)
        mockStorageManager.addNotification(oldNotification)
        
        // When
        service.startPolling()
        
        // Then
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Settings Integration Tests
    
    func testStartPolling_WhenDisabledInSettings_DoesNotPoll() {
        // Given
        mockStorageManager.screenshotDetectionEnabled = false
        let expectation = XCTestExpectation(description: "No polling when disabled")
        expectation.isInverted = true
        
        service.onNewNotification = { _ in
            expectation.fulfill()
        }
        
        mockStorageManager.addNotification(ScreenshotNotification(timestamp: Date()))
        
        // When
        service.startPolling()
        
        // Then
        XCTAssertFalse(service.isPolling, "Should not be polling when disabled")
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testPolling_IgnoresNotificationsWhenSettingDisabled() {
        // Given
        let expectation = XCTestExpectation(description: "No notifications after disable")
        expectation.isInverted = true
        
        service.onNewNotification = { _ in
            expectation.fulfill()
        }
        
        service.startPolling()
        
        // When - Disable setting and add notification
        mockStorageManager.screenshotDetectionEnabled = false
        mockStorageManager.addNotification(ScreenshotNotification(timestamp: Date()))
        
        // Then
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testMarkAsProcessed_PreventsReprocessing() {
        // Given
        let testNotification = ScreenshotNotification(timestamp: Date())
        
        // When
        service.markAsProcessed(testNotification.id)
        
        // Then - Add same notification and verify not processed
        let expectation = XCTestExpectation(description: "No callback for marked")
        expectation.isInverted = true
        
        service.onNewNotification = { _ in
            expectation.fulfill()
        }
        
        mockStorageManager.addNotification(testNotification)
        service.startPolling()
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testClearProcessedNotifications_AllowsReprocessing() {
        // Given
        let testNotification = ScreenshotNotification(timestamp: Date())
        service.markAsProcessed(testNotification.id)
        
        // When
        service.clearProcessedNotifications()
        
        // Then - Should now receive the notification
        let expectation = XCTestExpectation(description: "Notification after clear")
        
        service.onNewNotification = { _ in
            expectation.fulfill()
        }
        
        mockStorageManager.addNotification(testNotification)
        service.startPolling()
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testCleanup_StopsPollingAndClearsState() {
        // Given
        service.startPolling()
        service.markAsProcessed("test-id")
        
        // When
        service.cleanup()
        
        // Then
        XCTAssertFalse(service.isPolling, "Should stop polling after cleanup")
    }
    
    // MARK: - Performance Tests
    
    func testPollingInterval_IsApproximately2Seconds() {
        // Given
        let expectation = XCTestExpectation(description: "Multiple polls")
        expectation.expectedFulfillmentCount = 3
        
        var pollTimes: [Date] = []
        
        service.onNewNotification = { _ in
            pollTimes.append(Date())
            expectation.fulfill()
        }
        
        // Add new notification for each poll
        var notificationCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            notificationCount += 1
            self.mockStorageManager.addNotification(
                ScreenshotNotification(
                    id: "test-\(notificationCount)",
                    timestamp: Date(),
                    isActive: true,
                    expiresAt: Date().addingTimeInterval(60)
                )
            )
        }
        
        // When
        service.startPolling()
        
        // Then
        wait(for: [expectation], timeout: 8.0)
        timer.invalidate()
        
        // Verify intervals are approximately 2 seconds
        if pollTimes.count >= 2 {
            let interval = pollTimes[1].timeIntervalSince(pollTimes[0])
            XCTAssertGreaterThanOrEqual(interval, 1.8, "Poll interval should be at least 1.8s")
            XCTAssertLessThanOrEqual(interval, 2.5, "Poll interval should be at most 2.5s")
        }
    }
}

// MARK: - Mock Storage Manager

class MockSharedStorageManager: SharedStorageManager {
    
    private var notifications: [ScreenshotNotification] = []
    var screenshotDetectionEnabled = true
    var screenshotScanPromptsEnabled = true
    
    func addNotification(_ notification: ScreenshotNotification) {
        notifications.append(notification)
    }
    
    override func getActiveScreenshotNotifications() -> [ScreenshotNotification] {
        return notifications.filter { $0.isValid }
    }
    
    override func getScreenshotDetectionEnabled() -> Bool {
        return screenshotDetectionEnabled
    }
    
    override func getScreenshotScanPromptsEnabled() -> Bool {
        return screenshotScanPromptsEnabled
    }
}

