//
//  ScreenshotNotificationManagerTests.swift
//  TypeSafeTests
//
//  Story 4.1: Screenshot Detection & Notification
//  Unit tests for screenshot notification detection and management
//

import XCTest
@testable import TypeSafe

final class ScreenshotNotificationManagerTests: XCTestCase {
    
    var manager: ScreenshotNotificationManager!
    var appGroupDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        // Use test-specific App Group suite
        appGroupDefaults = UserDefaults(suiteName: "group.com.typesafe.shared.test")
        
        // Clear any existing test data
        appGroupDefaults.removePersistentDomain(forName: "group.com.typesafe.shared.test")
        
        manager = ScreenshotNotificationManager.shared
        manager.clearAllNotifications()
    }
    
    override func tearDown() {
        // Clean up test data
        manager.clearAllNotifications()
        appGroupDefaults.removePersistentDomain(forName: "group.com.typesafe.shared.test")
        
        manager = nil
        appGroupDefaults = nil
        
        super.tearDown()
    }
    
    // MARK: - Screenshot Notification Model Tests
    
    func testScreenshotNotificationCreation() {
        // Given: A new screenshot notification
        let notification = ScreenshotNotification()
        
        // Then: Should have valid properties
        XCTAssertFalse(notification.id.isEmpty, "ID should not be empty")
        XCTAssertTrue(notification.isActive, "Should be active on creation")
        XCTAssertFalse(notification.isExpired, "Should not be expired immediately")
        XCTAssertTrue(notification.isValid, "Should be valid on creation")
        
        // Check expiration is 60 seconds from timestamp
        let expectedExpiration = notification.timestamp.addingTimeInterval(60)
        XCTAssertEqual(notification.expiresAt.timeIntervalSince1970, 
                       expectedExpiration.timeIntervalSince1970, 
                       accuracy: 1.0,
                       "Expiration should be 60 seconds after timestamp")
    }
    
    func testScreenshotNotificationExpiration() {
        // Given: A notification from 2 minutes ago
        let pastTime = Date().addingTimeInterval(-120)
        let notification = ScreenshotNotification(timestamp: pastTime)
        
        // Then: Should be expired and invalid
        XCTAssertTrue(notification.isExpired, "Should be expired")
        XCTAssertFalse(notification.isValid, "Should be invalid when expired")
    }
    
    func testScreenshotNotificationPrivacyValidation() {
        // Given: A valid notification
        let validNotification = ScreenshotNotification()
        
        // Then: Should pass privacy validation
        XCTAssertTrue(validNotification.isPrivacySafe, "Valid notification should be privacy-safe")
        
        // Given: A notification with invalid timestamp (too far in future)
        let futureTime = Date().addingTimeInterval(7200) // 2 hours from now
        let invalidNotification = ScreenshotNotification(
            id: UUID().uuidString,
            timestamp: futureTime,
            isActive: true,
            expiresAt: futureTime.addingTimeInterval(60)
        )
        
        // Then: Should fail privacy validation
        XCTAssertFalse(invalidNotification.isPrivacySafe, "Future notification should fail privacy check")
    }
    
    func testScreenshotNotificationSize() {
        // Given: A notification
        let notification = ScreenshotNotification()
        
        // Then: Size should be reasonable (< 100 bytes)
        XCTAssertLessThan(notification.estimatedSize, 100, "Notification size should be under 100 bytes")
    }
    
    // MARK: - Screenshot Detection Tests
    
    func testScreenshotDetectionCreatesNotification() {
        // Given: Screenshot detection is enabled
        manager.setEnabled(true)
        
        // When: Screenshot is taken
        manager.handleScreenshotTaken()
        
        // Wait briefly for async processing
        let expectation = XCTestExpectation(description: "Notification created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: Should have one active notification
        let activeNotifications = manager.getActiveNotifications()
        XCTAssertEqual(activeNotifications.count, 1, "Should have one notification")
        XCTAssertTrue(activeNotifications.first?.isValid ?? false, "Notification should be valid")
    }
    
    func testScreenshotDetectionDebouncing() {
        // Given: Screenshot detection is enabled
        manager.setEnabled(true)
        
        // When: Multiple screenshots are taken rapidly
        manager.handleScreenshotTaken()
        manager.handleScreenshotTaken()
        manager.handleScreenshotTaken()
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Processing complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: Should only have one notification (debounced)
        let activeNotifications = manager.getActiveNotifications()
        XCTAssertEqual(activeNotifications.count, 1, "Should only create one notification (debounced)")
    }
    
    func testScreenshotDetectionRespectsDebouncingInterval() {
        // Given: Screenshot detection is enabled
        manager.setEnabled(true)
        
        // When: First screenshot is taken
        manager.handleScreenshotTaken()
        
        // Wait for initial processing
        let firstExpectation = XCTestExpectation(description: "First notification")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            firstExpectation.fulfill()
        }
        wait(for: [firstExpectation], timeout: 1.0)
        
        // Then: Should have one notification
        XCTAssertEqual(manager.getActiveNotifications().count, 1)
        
        // When: Second screenshot after 6 seconds (beyond debounce interval)
        let secondExpectation = XCTestExpectation(description: "Second notification")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.manager.handleScreenshotTaken()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                secondExpectation.fulfill()
            }
        }
        wait(for: [secondExpectation], timeout: 8.0)
        
        // Then: Should have two notifications
        XCTAssertEqual(manager.getActiveNotifications().count, 2, "Should create second notification after debounce interval")
    }
    
    func testScreenshotDetectionWhenDisabled() {
        // Given: Screenshot detection is disabled
        manager.setEnabled(false)
        
        // When: Screenshot is taken
        manager.handleScreenshotTaken()
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Processing complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: Should not create any notifications
        let activeNotifications = manager.getActiveNotifications()
        XCTAssertEqual(activeNotifications.count, 0, "Should not create notifications when disabled")
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupExpiredNotifications() {
        // Given: One active and one expired notification
        let activeNotification = ScreenshotNotification(timestamp: Date())
        let expiredNotification = ScreenshotNotification(timestamp: Date().addingTimeInterval(-120))
        
        // Manually add both to storage for testing
        // (In real usage, manager handles this automatically)
        let sharedDefaults = UserDefaults(suiteName: "group.com.typesafe.shared")
        let notifications = [activeNotification, expiredNotification]
        let data = try! JSONEncoder().encode(notifications)
        sharedDefaults?.set(data, forKey: "screenshot_notifications")
        
        // When: Cleanup is performed
        let removedCount = manager.cleanupExpiredNotifications()
        
        // Then: Should remove one expired notification
        XCTAssertEqual(removedCount, 1, "Should remove one expired notification")
        
        // And: Should only have active notification remaining
        let remaining = manager.getActiveNotifications()
        XCTAssertEqual(remaining.count, 1, "Should have one notification remaining")
        XCTAssertTrue(remaining.first?.isValid ?? false, "Remaining notification should be valid")
    }
    
    func testClearAllNotifications() {
        // Given: Multiple notifications
        manager.setEnabled(true)
        manager.handleScreenshotTaken()
        
        // Wait for processing
        let createExpectation = XCTestExpectation(description: "Notifications created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            createExpectation.fulfill()
        }
        wait(for: [createExpectation], timeout: 1.0)
        
        XCTAssertGreaterThan(manager.getActiveNotifications().count, 0, "Should have notifications")
        
        // When: All notifications are cleared
        manager.clearAllNotifications()
        
        // Wait for processing
        let clearExpectation = XCTestExpectation(description: "Notifications cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 1.0)
        
        // Then: Should have no notifications
        XCTAssertEqual(manager.getActiveNotifications().count, 0, "Should have no notifications")
    }
    
    // MARK: - Privacy Compliance Tests
    
    func testPrivacyCompliance() {
        // Given: Multiple notifications
        manager.setEnabled(true)
        manager.handleScreenshotTaken()
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Notifications created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: All notifications should be privacy-compliant
        XCTAssertTrue(manager.validatePrivacyCompliance(), "All notifications should be privacy-safe")
    }
    
    func testStorageSizeRemainsMini mal() {
        // Given: Multiple notifications
        manager.setEnabled(true)
        for _ in 0..<5 {
            manager.handleScreenshotTaken()
            Thread.sleep(forTimeInterval: 6) // Wait between to avoid debouncing
        }
        
        // Then: Storage size should remain small (< 500 bytes for 5 notifications)
        let size = manager.getStoredNotificationsSize()
        XCTAssertLessThan(size, 500, "Storage size should remain small")
    }
    
    // MARK: - Storage Limit Tests
    
    func testStorageLimitEnforcement() {
        // Given: Screenshot detection is enabled
        manager.setEnabled(true)
        
        // When: More than 10 screenshots are taken (with time between to avoid debouncing)
        for _ in 0..<15 {
            manager.handleScreenshotTaken()
            Thread.sleep(forTimeInterval: 6) // Wait to avoid debouncing
        }
        
        // Then: Should only keep last 10 notifications
        let allNotifications = manager.getActiveNotifications()
        XCTAssertLessThanOrEqual(allNotifications.count, 10, "Should not exceed 10 notifications")
    }
}

