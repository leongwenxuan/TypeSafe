//
//  SettingsManager.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Manages app settings persistence and App Group synchronization
//

import Foundation
import Combine

/// Manages app settings persistence and synchronization between main app and keyboard
/// Handles UserDefaults storage and App Group synchronization
class SettingsManager: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    static let shared = SettingsManager()
    
    // MARK: - Properties
    
    /// Published settings for SwiftUI binding
    @Published var settings: AppSettings
    
    /// UserDefaults for main app storage
    private let userDefaults: UserDefaults
    
    /// App Group UserDefaults for keyboard synchronization
    private let appGroupDefaults: UserDefaults?
    
    /// App Group identifier
    private let appGroupIdentifier = "group.com.typesafe.shared"
    
    // MARK: - UserDefaults Keys
    
    private struct Keys {
        static let settings = "typesafe.app_settings"
        static let sessionID = "TypeSafe.SessionID"
        
        // App Group Keys (for keyboard sync)
        static let sendScreenshotImages = "send_screenshot_images"
        static let voiceAlertsEnabled = "voice_alerts_enabled"
        static let scanResultNotifications = "scan_result_notifications"
        static let screenshotDetectionEnabled = "screenshot_detection_enabled"
        static let automaticScreenshotScanEnabled = "automatic_screenshot_scan_enabled"
        static let lastSettingsSync = "last_settings_sync"
    }
    
    // MARK: - Initialization
    
    /// Initialize with optional custom UserDefaults (for testing)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier)
        
        // Load settings from storage
        if let data = userDefaults.data(forKey: Keys.settings),
           let loadedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = loadedSettings
            print("SettingsManager: Loaded existing settings")
        } else {
            // Use default settings
            self.settings = AppSettings()
            print("SettingsManager: Initialized with default settings")
        }
        
        // Sync with App Group on initialization
        loadSettingsFromAppGroup()
    }
    
    // MARK: - Persistence Methods
    
    /// Saves settings to UserDefaults
    /// - Returns: Success status
    @discardableResult
    func saveSettings() -> Bool {
        guard settings.isValid else {
            print("SettingsManager: Settings validation failed")
            return false
        }
        
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Keys.settings)
            
            // Update sync timestamp
            settings.lastSettingsSync = Date()
            
            // Sync to App Group
            syncSettingsToAppGroup()
            
            print("SettingsManager: Settings saved successfully")
            return true
        } catch {
            print("SettingsManager: Failed to save settings - \(error)")
            return false
        }
    }
    
    /// Resets settings to default values
    func resetSettings() {
        settings = AppSettings()
        saveSettings()
        print("SettingsManager: Settings reset to defaults")
    }
    
    // MARK: - App Group Synchronization
    
    /// Syncs keyboard-relevant settings to App Group for keyboard access
    func syncSettingsToAppGroup() {
        guard let appGroupDefaults = appGroupDefaults else {
            print("SettingsManager: App Group not available")
            return
        }
        
        // Sync only keyboard-relevant settings (no sensitive data)
        appGroupDefaults.set(settings.sendScreenshotImages, forKey: Keys.sendScreenshotImages)
        appGroupDefaults.set(settings.voiceAlertsEnabled, forKey: Keys.voiceAlertsEnabled)
        appGroupDefaults.set(settings.scanResultNotifications, forKey: Keys.scanResultNotifications)
        appGroupDefaults.set(settings.screenshotDetectionEnabled, forKey: Keys.screenshotDetectionEnabled)
        appGroupDefaults.set(settings.automaticScreenshotScanEnabled, forKey: Keys.automaticScreenshotScanEnabled)
        appGroupDefaults.set(Date(), forKey: Keys.lastSettingsSync)
        
        // Notify ScreenshotNotificationManager of setting change (Story 4.1)
        ScreenshotNotificationManager.shared.setEnabled(settings.screenshotDetectionEnabled)
        
        print("SettingsManager: Synced settings to App Group")
        print("  - Screenshot images: \(settings.sendScreenshotImages)")
        print("  - Voice alerts: \(settings.voiceAlertsEnabled)")
        print("  - Notifications: \(settings.scanResultNotifications)")
        print("  - Screenshot detection: \(settings.screenshotDetectionEnabled)")
        print("  - Automatic scan: \(settings.automaticScreenshotScanEnabled)")
    }
    
    /// Loads settings from App Group (if keyboard modified them)
    func loadSettingsFromAppGroup() {
        guard let appGroupDefaults = appGroupDefaults else {
            print("SettingsManager: App Group not available")
            return
        }
        
        // Check if App Group has settings
        if appGroupDefaults.object(forKey: Keys.sendScreenshotImages) != nil {
            settings.sendScreenshotImages = appGroupDefaults.bool(forKey: Keys.sendScreenshotImages)
            settings.voiceAlertsEnabled = appGroupDefaults.bool(forKey: Keys.voiceAlertsEnabled)
            settings.scanResultNotifications = appGroupDefaults.bool(forKey: Keys.scanResultNotifications)
            
            // Load screenshot detection setting (Story 4.1)
            if appGroupDefaults.object(forKey: Keys.screenshotDetectionEnabled) != nil {
                settings.screenshotDetectionEnabled = appGroupDefaults.bool(forKey: Keys.screenshotDetectionEnabled)
            }
            
            // Load automatic screenshot scan setting (Story 5.1)
            if appGroupDefaults.object(forKey: Keys.automaticScreenshotScanEnabled) != nil {
                settings.automaticScreenshotScanEnabled = appGroupDefaults.bool(forKey: Keys.automaticScreenshotScanEnabled)
            }
            
            if let syncDate = appGroupDefaults.object(forKey: Keys.lastSettingsSync) as? Date {
                settings.lastSettingsSync = syncDate
            }
            
            print("SettingsManager: Loaded settings from App Group")
        }
    }
    
    // MARK: - Individual Setting Updates
    
    /// Updates screenshot image upload setting
    func updateScreenshotImageSetting(_ enabled: Bool) {
        settings.sendScreenshotImages = enabled
        saveSettings()
    }
    
    /// Updates voice alerts setting
    func updateVoiceAlertsSetting(_ enabled: Bool) {
        settings.voiceAlertsEnabled = enabled
        saveSettings()
    }
    
    /// Updates scan result notifications setting
    func updateNotificationsSetting(_ enabled: Bool) {
        settings.scanResultNotifications = enabled
        saveSettings()
    }
    
    /// Updates screenshot detection setting (Story 4.1)
    func updateScreenshotDetectionSetting(_ enabled: Bool) {
        settings.screenshotDetectionEnabled = enabled
        saveSettings()
    }
    
    /// Updates automatic screenshot scan setting (Story 5.1)
    func updateAutomaticScanSetting(_ enabled: Bool) {
        settings.automaticScreenshotScanEnabled = enabled
        saveSettings()
    }
    
    /// Updates privacy policy acceptance
    func acceptPrivacyPolicy() {
        settings.privacyPolicyAccepted = true
        saveSettings()
    }
    
    // MARK: - Data Deletion
    
    /// Deletes all user data and resets app to initial state
    /// - Returns: Success status
    @discardableResult
    func deleteAllUserData() -> Bool {
        print("SettingsManager: Starting complete data deletion")
        
        // 1. Clear main app UserDefaults
        clearMainAppData()
        
        // 2. Clear App Group storage
        clearAppGroupData()
        
        // 3. Clear Core Data (if Story 3.6 implemented)
        clearScanHistory()
        
        // 4. Generate new session ID
        resetSessionID()
        
        // 5. Reset settings to defaults
        settings = AppSettings()
        saveSettings()
        
        print("SettingsManager: Data deletion complete")
        return true
    }
    
    /// Clears all data from main app UserDefaults
    private func clearMainAppData() {
        let keysToRemove = [
            Keys.settings,
            Keys.sessionID,
            "TypeSafe.ImageUploadEnabled",  // PrivacyManager key
            "typesafe.privacy_policy_accepted"
        ]
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
        
        print("SettingsManager: Cleared main app data")
    }
    
    /// Clears all data from App Group UserDefaults
    private func clearAppGroupData() {
        guard let appGroupDefaults = appGroupDefaults else { return }
        
        let keysToRemove = [
            Keys.sendScreenshotImages,
            Keys.voiceAlertsEnabled,
            Keys.scanResultNotifications,
            Keys.screenshotDetectionEnabled,
            Keys.lastSettingsSync,
            "typesafe.latest_scan_result",
            "typesafe.shared_scan_result",
            "typesafe.scan_result_version",
            "typesafe.last_keyboard_check",
            "typesafe.last_analysis_timestamp",
            "screenshot_notifications"  // Story 4.1
        ]
        
        for key in keysToRemove {
            appGroupDefaults.removeObject(forKey: key)
        }
        
        print("SettingsManager: Cleared App Group data")
    }
    
    /// Clears scan history from Core Data
    private func clearScanHistory() {
        // This will be implemented in Story 3.6
        // For now, we'll just log that this step is pending
        print("SettingsManager: Core Data clearing pending (Story 3.6)")
    }
    
    /// Resets session ID to create new anonymous session
    private func resetSessionID() {
        let newSessionID = UUID().uuidString
        userDefaults.set(newSessionID, forKey: Keys.sessionID)
        print("SettingsManager: Generated new session ID: \(newSessionID)")
    }
    
    // MARK: - Full Access Detection
    
    /// Updates Full Access status (to be called from keyboard extension)
    /// Note: This is a read-only value detected by the system
    func updateFullAccessStatus(_ enabled: Bool) {
        settings.fullAccessEnabled = enabled
        // Don't save to UserDefaults as this is system-detected, not user-controlled
        print("SettingsManager: Full Access status updated: \(enabled)")
    }
    
    // MARK: - Utility Methods
    
    /// Gets current settings as dictionary for debugging
    var settingsDictionary: [String: Any] {
        return [
            "fullAccessEnabled": settings.fullAccessEnabled,
            "sendScreenshotImages": settings.sendScreenshotImages,
            "voiceAlertsEnabled": settings.voiceAlertsEnabled,
            "scanResultNotifications": settings.scanResultNotifications,
            "screenshotDetectionEnabled": settings.screenshotDetectionEnabled,
            "automaticScreenshotScanEnabled": settings.automaticScreenshotScanEnabled,
            "dataRetentionDays": settings.dataRetentionDays,
            "privacyPolicyAccepted": settings.privacyPolicyAccepted,
            "lastSettingsSync": settings.lastSettingsSync
        ]
    }
}

