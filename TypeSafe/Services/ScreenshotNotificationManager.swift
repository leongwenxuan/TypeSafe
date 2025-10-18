//
//  ScreenshotNotificationManager.swift
//  TypeSafe
//
//  Story 4.1: Screenshot Detection & Notification
//  Manages screenshot detection and notification via App Group
//

import Foundation
import UIKit

/// Manages screenshot detection and notification handling
/// Detects when user takes screenshots and writes notifications to App Group storage
class ScreenshotNotificationManager {
    
    // MARK: - Singleton
    
    /// Shared instance for screenshot notification management
    static let shared = ScreenshotNotificationManager()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Properties
    
    /// Minimum time interval between notifications (5 seconds)
    private let debounceInterval: TimeInterval = 5.0
    
    /// Timestamp of last screenshot notification
    private var lastNotificationTimestamp: Date?
    
    /// Observer token for cleanup
    private var screenshotObserver: NSObjectProtocol?
    
    /// Whether screenshot detection is currently enabled
    private var isEnabled: Bool = true
    
    /// Queue for thread-safe operations
    private let notificationQueue = DispatchQueue(label: "com.typesafe.screenshot-notifications", qos: .userInitiated)
    
    // MARK: - Public Methods
    
    /// Registers for screenshot notifications
    /// Should be called during app initialization
    func registerForScreenshotNotifications() {
        // Remove existing observer if any
        if let observer = screenshotObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Register for screenshot notifications
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🟢 SCREENSHOT DETECTED! Notification received")
            self?.handleScreenshotTaken()
        }
        
        print("🟢 ScreenshotNotificationManager: Registered for screenshot notifications")
        print("🟢 Observer registered: \(screenshotObserver != nil)")
    }
    
    /// Unregisters from screenshot notifications
    /// Should be called during cleanup or when disabling feature
    func unregisterFromScreenshotNotifications() {
        if let observer = screenshotObserver {
            NotificationCenter.default.removeObserver(observer)
            screenshotObserver = nil
        }
        
        print("ScreenshotNotificationManager: Unregistered from screenshot notifications")
    }
    
    /// Handles screenshot detection event
    /// Applies debouncing and writes notification to App Group
    func handleScreenshotTaken() {
        print("🟡 handleScreenshotTaken() called")
        
        notificationQueue.async { [weak self] in
            guard let self = self else { 
                print("🔴 self is nil in handleScreenshotTaken")
                return
            }
            
            print("🟡 Checking if enabled... isEnabled = \(self.isEnabled)")
            
            // Check if feature is enabled
            guard self.isEnabled else {
                print("🔴 ScreenshotNotificationManager: Screenshot detection disabled")
                return
            }
            
            // Apply debouncing
            let now = Date()
            if let lastTimestamp = self.lastNotificationTimestamp {
                let timeSinceLastNotification = now.timeIntervalSince(lastTimestamp)
                if timeSinceLastNotification < self.debounceInterval {
                    print("ScreenshotNotificationManager: Debounced screenshot (too soon: \(timeSinceLastNotification)s)")
                    return
                }
            }
            
            // Create new notification
            let notification = ScreenshotNotification(timestamp: now)
            
            // Validate privacy compliance
            guard notification.isPrivacySafe else {
                print("ScreenshotNotificationManager: Privacy validation failed for notification")
                return
            }
            
            // Write to App Group storage
            print("🟡 Writing notification to App Group...")
            let success = self.writeNotificationToAppGroup(notification)
            
            if success {
                self.lastNotificationTimestamp = now
                print("🟢 ScreenshotNotificationManager: Screenshot notification created - ID: \(notification.id)")
                print("🟢 Notification saved successfully!")
            } else {
                print("🔴 ScreenshotNotificationManager: Failed to write screenshot notification")
            }
        }
    }
    
    /// Enables or disables screenshot detection
    /// - Parameter enabled: Whether to enable screenshot detection
    func setEnabled(_ enabled: Bool) {
        notificationQueue.async { [weak self] in
            self?.isEnabled = enabled
            print("ScreenshotNotificationManager: Screenshot detection \(enabled ? "enabled" : "disabled")")
        }
    }
    
    /// Gets active notifications from App Group storage
    /// - Returns: Array of active (non-expired) notifications
    func getActiveNotifications() -> [ScreenshotNotification] {
        return notificationQueue.sync {
            return self.readNotificationsFromAppGroup().filter { $0.isValid }
        }
    }
    
    /// Cleans up expired notifications from App Group storage
    /// - Returns: Number of notifications removed
    @discardableResult
    func cleanupExpiredNotifications() -> Int {
        return notificationQueue.sync {
            let allNotifications = self.readNotificationsFromAppGroup()
            let activeNotifications = allNotifications.filter { $0.isValid }
            let expiredCount = allNotifications.count - activeNotifications.count
            
            if expiredCount > 0 {
                self.writeNotificationsToAppGroup(activeNotifications)
                print("ScreenshotNotificationManager: Cleaned up \(expiredCount) expired notifications")
            }
            
            return expiredCount
        }
    }
    
    /// Clears all notifications (for testing or reset)
    func clearAllNotifications() {
        notificationQueue.async { [weak self] in
            self?.writeNotificationsToAppGroup([])
            self?.lastNotificationTimestamp = nil
            print("ScreenshotNotificationManager: Cleared all notifications")
        }
    }
    
    // MARK: - Private Methods
    
    /// Writes a new notification to App Group storage
    /// - Parameter notification: Notification to write
    /// - Returns: Success status
    private func writeNotificationToAppGroup(_ notification: ScreenshotNotification) -> Bool {
        // Get existing notifications
        var notifications = readNotificationsFromAppGroup()
        
        // Remove expired notifications before adding new one
        notifications = notifications.filter { $0.isValid }
        
        // Add new notification
        notifications.append(notification)
        
        // Limit to last 10 notifications to prevent storage bloat
        if notifications.count > 10 {
            notifications = Array(notifications.suffix(10))
        }
        
        // Write back to storage
        return writeNotificationsToAppGroup(notifications)
    }
    
    /// Reads all notifications from App Group storage
    /// - Returns: Array of all stored notifications
    private func readNotificationsFromAppGroup() -> [ScreenshotNotification] {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.typesafe.shared") else {
            print("ScreenshotNotificationManager: Failed to access App Group storage")
            return []
        }
        
        guard let data = sharedDefaults.data(forKey: "screenshot_notifications") else {
            return []
        }
        
        do {
            let notifications = try JSONDecoder().decode([ScreenshotNotification].self, from: data)
            return notifications
        } catch {
            print("ScreenshotNotificationManager: Failed to decode notifications - \(error)")
            return []
        }
    }
    
    /// Writes notifications array to App Group storage
    /// - Parameter notifications: Array of notifications to write
    /// - Returns: Success status
    private func writeNotificationsToAppGroup(_ notifications: [ScreenshotNotification]) -> Bool {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.typesafe.shared") else {
            print("ScreenshotNotificationManager: Failed to access App Group storage")
            return false
        }
        
        do {
            let data = try JSONEncoder().encode(notifications)
            sharedDefaults.set(data, forKey: "screenshot_notifications")
            sharedDefaults.synchronize() // Force immediate write
            return true
        } catch {
            print("ScreenshotNotificationManager: Failed to encode notifications - \(error)")
            return false
        }
    }
}

// MARK: - App Group Integration Extension

extension ScreenshotNotificationManager {
    
    /// Gets the total size of stored notifications for monitoring
    /// - Returns: Approximate size in bytes
    func getStoredNotificationsSize() -> Int {
        let notifications = readNotificationsFromAppGroup()
        return notifications.reduce(0) { $0 + $1.estimatedSize }
    }
    
    /// Validates privacy compliance of stored notifications
    /// - Returns: True if all stored notifications are privacy-safe
    func validatePrivacyCompliance() -> Bool {
        let notifications = readNotificationsFromAppGroup()
        return notifications.allSatisfy { $0.isPrivacySafe }
    }
}

