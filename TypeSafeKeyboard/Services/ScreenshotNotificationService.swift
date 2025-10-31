//
//  ScreenshotNotificationService.swift
//  TypeSafeKeyboard
//
//  Story 4.2: Screenshot Alert Prompt in Keyboard
//  Handles polling for screenshot notifications and coordinating banner display
//

import Foundation
import UIKit

/// Service responsible for polling screenshot notifications and managing their lifecycle
/// Polls App Group storage every 2 seconds for new screenshot notifications from the companion app
class ScreenshotNotificationService {
    
    // MARK: - Properties
    
    /// Shared storage manager for accessing App Group data
    private let storageManager: SharedStorageManager
    
    /// Timer for polling screenshot notifications
    private var pollingTimer: Timer?
    
    /// Set of processed notification IDs to prevent duplicate displays
    private var processedNotificationIds: Set<String> = []
    
    /// Polling interval in seconds (2 seconds as per requirements)
    private let pollingInterval: TimeInterval = 2.0
    
    /// Callback when a new screenshot notification is detected
    var onNewNotification: ((ScreenshotNotification) -> Void)?
    
    /// Whether polling is currently active
    private(set) var isPolling: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a new screenshot notification service
    /// - Parameter storageManager: Storage manager to use (defaults to shared instance)
    init(storageManager: SharedStorageManager = .shared) {
        self.storageManager = storageManager
    }
    
    // MARK: - Public Methods
    
    /// Starts polling for screenshot notifications
    /// Safe to call multiple times - will stop existing timer first
    func startPolling() {
        // Stop any existing timer
        stopPolling()
        
        
        
        // Check if feature is enabled via settings
        guard isScreenshotPromptsEnabled() else {
            
            return
        }
        
        isPolling = true
        
        // Create timer with 2-second intervals
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForNotifications()
        }
        
        // Also check immediately on start
        checkForNotifications()
    }
    
    /// Stops polling for screenshot notifications
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPolling = false
        
    }
    
    /// Marks a notification as processed to prevent duplicate displays
    /// - Parameter notificationId: ID of the notification to mark
    func markAsProcessed(_ notificationId: String) {
        processedNotificationIds.insert(notificationId)
        
    }
    
    /// Clears all processed notification IDs
    /// Useful for testing or when keyboard is dismissed
    func clearProcessedNotifications() {
        processedNotificationIds.removeAll()
        
    }
    
    // MARK: - Private Methods
    
    /// Checks for new screenshot notifications in background queue
    private func checkForNotifications() {
        // Use background queue to prevent UI blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // Check if feature is still enabled (settings might have changed)
            guard self.isScreenshotPromptsEnabled() else {
                return
            }
            
            // Get active notifications from shared storage
            let notifications = self.storageManager.getActiveScreenshotNotifications()
            
            // Filter to only new, unprocessed notifications
            let newNotifications = notifications.filter { notification in
                // Skip if already processed
                guard !self.processedNotificationIds.contains(notification.id) else {
                    return false
                }
                
                // Skip if expired (double-check even though storage filters)
                guard notification.isValid else {
                    return false
                }
                
                // Skip if older than 60 seconds (as per requirements)
                let age = Date().timeIntervalSince(notification.timestamp)
                guard age <= 60 else {
                    return false
                }
                
                return true
            }
            
            // Process each new notification on main thread
            for notification in newNotifications {
                DispatchQueue.main.async {
                    self.processNewNotification(notification)
                }
            }
        }
    }
    
    /// Processes a new notification by calling the callback and marking as processed
    /// - Parameter notification: The notification to process
    private func processNewNotification(_ notification: ScreenshotNotification) {
        
        // Mark as processed immediately to prevent duplicates
        markAsProcessed(notification.id)
        
        // Notify listener (KeyboardViewController)
        onNewNotification?(notification)
    }
    
    /// Checks if screenshot prompts are enabled in settings
    /// - Returns: True if enabled, false otherwise
    private func isScreenshotPromptsEnabled() -> Bool {
        // Check both screenshot detection (Story 4.1) and scan prompts (Story 4.2)
        // Both must be enabled for prompts to show
        let detectionEnabled = storageManager.getScreenshotDetectionEnabled()
        let promptsEnabled = storageManager.getScreenshotScanPromptsEnabled()
        
        return detectionEnabled && promptsEnabled
    }
}

// MARK: - Memory Management

extension ScreenshotNotificationService {
    
    /// Cleans up resources and stops polling
    func cleanup() {
        stopPolling()
        clearProcessedNotifications()
    }
}

