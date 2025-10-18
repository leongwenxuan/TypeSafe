//
//  AppSettings.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Data model for app-wide settings and privacy controls
//

import Foundation

/// Comprehensive app settings model with privacy controls
/// Stores user preferences for privacy, notifications, and data management
struct AppSettings: Codable, Equatable {
    
    // MARK: - Privacy Controls
    
    /// Full Access permission status (read-only, detected from system)
    var fullAccessEnabled: Bool = false
    
    /// User opt-in for sending screenshot images to backend (default: OFF for privacy)
    var sendScreenshotImages: Bool = false
    
    /// Enable voice alerts for accessibility (default: OFF, future feature)
    var voiceAlertsEnabled: Bool = false
    
    /// Show scan result banner notifications in keyboard (default: ON)
    var scanResultNotifications: Bool = true
    
    /// Enable screenshot detection notifications (default: ON) - Story 4.1
    var screenshotDetectionEnabled: Bool = true
    
    /// Enable automatic screenshot scanning (default: ON) - Story 5.1
    var automaticScreenshotScanEnabled: Bool = true
    
    // MARK: - User Context (Story 5.5)
    
    /// User's country code (ISO 3166-1 alpha-2, e.g., "US", "GB", "SG")
    /// Auto-detected from device locale, used for phone number scam detection
    var userCountryCode: String = Locale.current.region?.identifier ?? "US"
    
    /// User's phone region code (e.g., "+1", "+44", "+65")
    /// Derived from country code, used for detecting foreign numbers
    var userPhoneRegion: String = ""
    
    // MARK: - Data Management
    
    /// Data retention period in days (fixed at 7 for MVP)
    var dataRetentionDays: Int = 7
    
    /// Track if user has accepted privacy policy
    var privacyPolicyAccepted: Bool = false
    
    /// Last time settings were synced to App Group
    var lastSettingsSync: Date = Date()
    
    // MARK: - Initialization
    
    /// Creates default settings with privacy-first defaults
    init() {
        // All defaults are set via property initialization
    }
    
    /// Creates settings from individual values
    init(
        fullAccessEnabled: Bool = false,
        sendScreenshotImages: Bool = false,
        voiceAlertsEnabled: Bool = false,
        scanResultNotifications: Bool = true,
        screenshotDetectionEnabled: Bool = true,
        automaticScreenshotScanEnabled: Bool = true,
        dataRetentionDays: Int = 7,
        privacyPolicyAccepted: Bool = false,
        lastSettingsSync: Date = Date()
    ) {
        self.fullAccessEnabled = fullAccessEnabled
        self.sendScreenshotImages = sendScreenshotImages
        self.voiceAlertsEnabled = voiceAlertsEnabled
        self.scanResultNotifications = scanResultNotifications
        self.screenshotDetectionEnabled = screenshotDetectionEnabled
        self.automaticScreenshotScanEnabled = automaticScreenshotScanEnabled
        self.dataRetentionDays = dataRetentionDays
        self.privacyPolicyAccepted = privacyPolicyAccepted
        self.lastSettingsSync = lastSettingsSync
    }
    
    // MARK: - Validation
    
    /// Validates settings are within acceptable ranges
    var isValid: Bool {
        // Data retention must be positive
        guard dataRetentionDays > 0 else { return false }
        
        // Data retention should be reasonable (1-30 days)
        guard dataRetentionDays <= 30 else { return false }
        
        return true
    }
    
    /// Returns privacy-safe settings for App Group sync (excludes sensitive data)
    var privacySafeSettings: [String: Any] {
        return [
            "send_screenshot_images": sendScreenshotImages,
            "voice_alerts_enabled": voiceAlertsEnabled,
            "scan_result_notifications": scanResultNotifications,
            "screenshot_detection_enabled": screenshotDetectionEnabled,
            "automatic_screenshot_scan_enabled": automaticScreenshotScanEnabled,
            "user_country_code": userCountryCode,
            "user_phone_region": userPhoneRegion,
            "last_settings_sync": lastSettingsSync
        ]
    }
}

