//
//  ScreenshotNotification.swift
//  TypeSafe
//
//  Story 4.1: Screenshot Detection & Notification
//  Data model for screenshot notification metadata shared via App Group
//

import Foundation

/// Privacy-safe screenshot notification metadata for App Group sharing
/// Contains only timestamp and expiration data, no screenshot content
struct ScreenshotNotification: Codable, Equatable, Identifiable {
    
    // MARK: - Properties
    
    /// Unique identifier for deduplication
    let id: String
    
    /// When the screenshot was taken
    let timestamp: Date
    
    /// Whether this notification is still active/valid
    let isActive: Bool
    
    /// When this notification expires (timestamp + 60 seconds)
    let expiresAt: Date
    
    // MARK: - Initialization
    
    /// Creates a new screenshot notification with automatic ID generation
    /// - Parameter timestamp: When the screenshot was taken (defaults to now)
    init(timestamp: Date = Date()) {
        self.id = UUID().uuidString
        self.timestamp = timestamp
        self.isActive = true
        self.expiresAt = timestamp.addingTimeInterval(60) // 60-second TTL
    }
    
    /// Creates a screenshot notification with explicit values (for testing)
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - timestamp: When the screenshot was taken
    ///   - isActive: Whether notification is active
    ///   - expiresAt: When notification expires
    init(id: String, timestamp: Date, isActive: Bool, expiresAt: Date) {
        self.id = id
        self.timestamp = timestamp
        self.isActive = isActive
        self.expiresAt = expiresAt
    }
    
    // MARK: - Validation
    
    /// Checks if this notification has expired
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    /// Checks if this notification is still valid (active and not expired)
    var isValid: Bool {
        return isActive && !isExpired
    }
    
    /// Validates data integrity and privacy compliance
    var isPrivacySafe: Bool {
        // Validate ID format (should be UUID-like)
        guard !id.isEmpty && id.count <= 50 else {
            return false
        }
        
        // Validate timestamp is reasonable (not too far in past or future)
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let oneHourFromNow = now.addingTimeInterval(3600)
        
        guard timestamp >= oneHourAgo && timestamp <= oneHourFromNow else {
            return false
        }
        
        // Validate expiration is after timestamp
        guard expiresAt > timestamp else {
            return false
        }
        
        return true
    }
    
    /// Estimated size in bytes for App Group storage tracking
    var estimatedSize: Int {
        return id.utf8.count +  // ~36 bytes for UUID
               8 +              // Date (timestamp)
               1 +              // Bool (isActive)
               8                // Date (expiresAt)
        // Total: ~53 bytes per notification
    }
    
    // MARK: - Utility Methods
    
    /// Creates a copy of this notification marked as inactive
    /// - Returns: New ScreenshotNotification with isActive set to false
    func markAsInactive() -> ScreenshotNotification {
        return ScreenshotNotification(
            id: id,
            timestamp: timestamp,
            isActive: false,
            expiresAt: expiresAt
        )
    }
    
    /// Time remaining until expiration
    var timeUntilExpiration: TimeInterval {
        return max(0, expiresAt.timeIntervalSinceNow)
    }
    
    /// Age of the notification in seconds
    var age: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Extensions

extension ScreenshotNotification {
    
    /// Creates a sample notification for testing
    static func sample() -> ScreenshotNotification {
        return ScreenshotNotification(timestamp: Date())
    }
    
    /// Creates an expired notification for testing
    static func expired() -> ScreenshotNotification {
        let pastTime = Date().addingTimeInterval(-120) // 2 minutes ago
        return ScreenshotNotification(timestamp: pastTime)
    }
}

