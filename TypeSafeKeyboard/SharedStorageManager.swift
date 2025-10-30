//
//  SharedStorageManager.swift
//  TypeSafeKeyboard
//
//  Story 2.7: App Group Shared State
//  Manages shared state between keyboard extension and companion app
//

import Foundation

// Import SharedScanResult from main app target
// Note: This will be available through the shared App Group container

/// Manages shared state between keyboard extension and companion app via App Group
/// Stores minimal, privacy-safe data including scan results, settings, and timestamps
class SharedStorageManager {
    
    // MARK: - Singleton
    
    /// Shared instance for accessing storage manager
    static let shared = SharedStorageManager()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Properties
    
    /// App Group identifier for sharing data between keyboard and main app
    private let appGroupIdentifier = "group.com.typesafe.shared"
    
    /// Shared UserDefaults instance for App Group
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - UserDefaults Keys
    
    private struct Keys {
        static let latestScanResult = "typesafe.latest_scan_result"
        static let sharedScanResult = "typesafe.shared_scan_result"
        static let scanResultVersion = "typesafe.scan_result_version"
        static let lastKeyboardCheck = "typesafe.last_keyboard_check"
        static let lastAnalysisTimestamp = "typesafe.last_analysis_timestamp"
        static let alertPreferences = "typesafe.alert_preferences"
        static let privacySettings = "typesafe.privacy_settings"
        
        // Story 3.8: Settings Sync Keys
        static let sendScreenshotImages = "send_screenshot_images"
        static let voiceAlertsEnabled = "voice_alerts_enabled"
        static let scanResultNotifications = "scan_result_notifications"
        static let lastSettingsSync = "last_settings_sync"
        
        // Story 4.1: Screenshot Notification Keys
        static let screenshotNotifications = "screenshot_notifications"
        static let screenshotDetectionEnabled = "screenshot_detection_enabled"
        
        // Story 4.2: Screenshot Scan Prompts Key
        static let screenshotScanPromptsEnabled = "screenshot_scan_prompts_enabled"
        
        // Story 11.4: Keyboard Sounds Key
        static let keyboardSoundsEnabled = "keyboard_sounds_enabled"

        // Story 12.1: Feature Flag Keys
        static let featureFlagPrefix = "feature_flag_"
    }
    
    // MARK: - Data Models
    
    /// Privacy-safe scan result data (no raw text or PII)
    struct ScanResult: Codable {
        let riskLevel: String      // "low", "medium", "high"
        let category: String       // "financial", "personal", "work", etc.
        let timestamp: Date
        let hasRisks: Bool
        
        /// Validates that no PII is present in the scan result
        var isPrivacySafe: Bool {
            // Ensure risk level and category are from predefined sets
            let validRiskLevels = ["low", "medium", "high", "none"]
            let validCategories = ["financial", "personal", "work", "social", "unknown"]
            
            return validRiskLevels.contains(riskLevel.lowercased()) &&
                   validCategories.contains(category.lowercased())
        }
    }
    
    /// User alert preferences
    struct AlertPreferences: Codable {
        let showBanners: Bool
        let riskThreshold: String  // "low", "medium", "high"
        
        static let `default` = AlertPreferences(
            showBanners: true,
            riskThreshold: "medium"
        )
    }
    
    /// Privacy settings
    struct PrivacySettings: Codable {
        let enableAnalytics: Bool
        let shareAnonymousData: Bool
        
        static let `default` = PrivacySettings(
            enableAnalytics: false,
            shareAnonymousData: false
        )
    }
    
    // MARK: - Scan Result Methods
    
    /// Stores the latest scan result (privacy-safe data only)
    /// - Parameter scanResult: Scan result with no PII or raw text
    /// - Returns: Success status
    @discardableResult
    func storeLatestScanResult(_ scanResult: ScanResult) -> Bool {
        guard scanResult.isPrivacySafe else {
            print("SharedStorageManager: Rejected scan result - privacy validation failed")
            return false
        }
        
        do {
            let data = try JSONEncoder().encode(scanResult)
            sharedDefaults?.set(data, forKey: Keys.latestScanResult)
            print("SharedStorageManager: Stored scan result - risk: \(scanResult.riskLevel), category: \(scanResult.category)")
            return true
        } catch {
            print("SharedStorageManager: Failed to encode scan result - \(error)")
            return false
        }
    }
    
    /// Retrieves the latest scan result
    /// - Returns: Latest scan result or nil if none exists
    func getLatestScanResult() -> ScanResult? {
        guard let data = sharedDefaults?.data(forKey: Keys.latestScanResult) else {
            return nil
        }
        
        do {
            let scanResult = try JSONDecoder().decode(ScanResult.self, from: data)
            return scanResult.isPrivacySafe ? scanResult : nil
        } catch {
            print("SharedStorageManager: Failed to decode scan result - \(error)")
            return nil
        }
    }
    
    // MARK: - Shared Scan Result Methods (Story 3.7)
    
    /// Stores the latest screenshot scan result for keyboard sync
    /// - Parameter result: SharedScanResult with privacy-safe data
    /// - Returns: Success status
    @discardableResult
    func setLatestScanResult(_ result: SharedScanResult) -> Bool {
        guard result.isPrivacySafe else {
            print("SharedStorageManager: Rejected shared scan result - privacy validation failed")
            return false
        }
        
        do {
            let data = try JSONEncoder().encode(result)
            
            // Store the scan result
            sharedDefaults?.set(data, forKey: Keys.sharedScanResult)
            
            // Increment version for change detection
            let currentVersion = sharedDefaults?.integer(forKey: Keys.scanResultVersion) ?? 0
            sharedDefaults?.set(currentVersion + 1, forKey: Keys.scanResultVersion)
            
            print("SharedStorageManager: Stored shared scan result - ID: \(result.scanId), risk: \(result.riskLevel), category: \(result.category)")
            return true
        } catch {
            print("SharedStorageManager: Failed to encode shared scan result - \(error)")
            return false
        }
    }
    
    /// Retrieves the latest screenshot scan result if it's new for the keyboard
    /// - Returns: SharedScanResult if new, nil if no new results
    func getLatestSharedScanResult() -> SharedScanResult? {
        guard let data = sharedDefaults?.data(forKey: Keys.sharedScanResult) else {
            return nil
        }
        
        do {
            let scanResult = try JSONDecoder().decode(SharedScanResult.self, from: data)
            
            // Validate privacy compliance
            guard scanResult.isPrivacySafe else {
                print("SharedStorageManager: Shared scan result failed privacy validation")
                return nil
            }
            
            // Only return if it's marked as new
            return scanResult.isNew ? scanResult : nil
        } catch {
            print("SharedStorageManager: Failed to decode shared scan result - \(error)")
            return nil
        }
    }
    
    /// Marks a scan result as read by the keyboard
    /// - Parameter scanId: ID of the scan result to mark as read
    /// - Returns: Success status
    @discardableResult
    func markScanResultAsRead(_ scanId: String) -> Bool {
        guard let data = sharedDefaults?.data(forKey: Keys.sharedScanResult) else {
            return false
        }
        
        do {
            let scanResult = try JSONDecoder().decode(SharedScanResult.self, from: data)
            
            // Only mark as read if it matches the provided ID
            guard scanResult.scanId == scanId else {
                print("SharedStorageManager: Scan ID mismatch - cannot mark as read")
                return false
            }
            
            // Create updated result marked as read
            let updatedResult = scanResult.markAsRead()
            let updatedData = try JSONEncoder().encode(updatedResult)
            
            sharedDefaults?.set(updatedData, forKey: Keys.sharedScanResult)
            sharedDefaults?.set(Date(), forKey: Keys.lastKeyboardCheck)
            
            print("SharedStorageManager: Marked scan result as read - ID: \(scanId)")
            return true
        } catch {
            print("SharedStorageManager: Failed to mark scan result as read - \(error)")
            return false
        }
    }
    
    /// Clears old scan results (older than 24 hours)
    /// - Returns: Number of results cleared
    @discardableResult
    func clearOldScanResults() -> Int {
        let twentyFourHoursAgo: TimeInterval = 24 * 60 * 60
        var clearedCount = 0
        
        // Check if current result is old
        if let data = sharedDefaults?.data(forKey: Keys.sharedScanResult) {
            do {
                let scanResult = try JSONDecoder().decode(SharedScanResult.self, from: data)
                if scanResult.isOlderThan(twentyFourHoursAgo) {
                    sharedDefaults?.removeObject(forKey: Keys.sharedScanResult)
                    clearedCount += 1
                    print("SharedStorageManager: Cleared old scan result - ID: \(scanResult.scanId)")
                }
            } catch {
                // If we can't decode it, remove it anyway
                sharedDefaults?.removeObject(forKey: Keys.sharedScanResult)
                clearedCount += 1
                print("SharedStorageManager: Cleared corrupted scan result data")
            }
        }
        
        return clearedCount
    }
    
    /// Gets the current scan result version for change detection
    /// - Returns: Current version number
    func getScanResultVersion() -> Int {
        return sharedDefaults?.integer(forKey: Keys.scanResultVersion) ?? 0
    }
    
    /// Updates the last keyboard check timestamp
    func updateLastKeyboardCheck() {
        sharedDefaults?.set(Date(), forKey: Keys.lastKeyboardCheck)
    }
    
    /// Gets the last keyboard check timestamp
    /// - Returns: Last keyboard check timestamp or nil
    func getLastKeyboardCheck() -> Date? {
        return sharedDefaults?.object(forKey: Keys.lastKeyboardCheck) as? Date
    }
    
    // MARK: - Timestamp Methods
    
    /// Updates the last analysis timestamp
    /// - Parameter timestamp: Timestamp of the last text analysis
    func updateLastAnalysisTimestamp(_ timestamp: Date = Date()) {
        sharedDefaults?.set(timestamp, forKey: Keys.lastAnalysisTimestamp)
        print("SharedStorageManager: Updated analysis timestamp: \(timestamp)")
    }
    
    /// Retrieves the last analysis timestamp
    /// - Returns: Last analysis timestamp or nil if none exists
    func getLastAnalysisTimestamp() -> Date? {
        return sharedDefaults?.object(forKey: Keys.lastAnalysisTimestamp) as? Date
    }
    
    // MARK: - Settings Methods
    
    /// Stores alert preferences
    /// - Parameter preferences: User alert preferences
    /// - Returns: Success status
    @discardableResult
    func storeAlertPreferences(_ preferences: AlertPreferences) -> Bool {
        do {
            let data = try JSONEncoder().encode(preferences)
            sharedDefaults?.set(data, forKey: Keys.alertPreferences)
            print("SharedStorageManager: Stored alert preferences")
            return true
        } catch {
            print("SharedStorageManager: Failed to encode alert preferences - \(error)")
            return false
        }
    }
    
    /// Retrieves alert preferences
    /// - Returns: Alert preferences or default values if none exist
    func getAlertPreferences() -> AlertPreferences {
        guard let data = sharedDefaults?.data(forKey: Keys.alertPreferences) else {
            return AlertPreferences.default
        }
        
        do {
            return try JSONDecoder().decode(AlertPreferences.self, from: data)
        } catch {
            print("SharedStorageManager: Failed to decode alert preferences - \(error)")
            return AlertPreferences.default
        }
    }
    
    /// Stores privacy settings
    /// - Parameter settings: User privacy settings
    /// - Returns: Success status
    @discardableResult
    func storePrivacySettings(_ settings: PrivacySettings) -> Bool {
        do {
            let data = try JSONEncoder().encode(settings)
            sharedDefaults?.set(data, forKey: Keys.privacySettings)
            print("SharedStorageManager: Stored privacy settings")
            return true
        } catch {
            print("SharedStorageManager: Failed to encode privacy settings - \(error)")
            return false
        }
    }
    
    /// Retrieves privacy settings
    /// - Returns: Privacy settings or default values if none exist
    func getPrivacySettings() -> PrivacySettings {
        guard let data = sharedDefaults?.data(forKey: Keys.privacySettings) else {
            return PrivacySettings.default
        }
        
        do {
            return try JSONDecoder().decode(PrivacySettings.self, from: data)
        } catch {
            print("SharedStorageManager: Failed to decode privacy settings - \(error)")
            return PrivacySettings.default
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clears all shared data (useful for testing or reset)
    func clearAllSharedData() {
        let keys = [
            Keys.latestScanResult,
            Keys.sharedScanResult,
            Keys.scanResultVersion,
            Keys.lastKeyboardCheck,
            Keys.lastAnalysisTimestamp,
            Keys.alertPreferences,
            Keys.privacySettings
        ]
        
        for key in keys {
            sharedDefaults?.removeObject(forKey: key)
        }
        
        print("SharedStorageManager: Cleared all shared data")
    }
    
    /// Gets the total size of stored data (for privacy compliance)
    /// - Returns: Approximate size in bytes
    func getStoredDataSize() -> Int {
        var totalSize = 0
        
        let dataKeys = [
            Keys.latestScanResult,
            Keys.sharedScanResult,
            Keys.alertPreferences,
            Keys.privacySettings
        ]
        
        let primitiveKeys = [
            Keys.scanResultVersion,
            Keys.lastKeyboardCheck,
            Keys.lastAnalysisTimestamp
        ]
        
        // Count data objects
        for key in dataKeys {
            if let data = sharedDefaults?.data(forKey: key) {
                totalSize += data.count
            }
        }
        
        // Count primitive objects (estimate 8 bytes each)
        for key in primitiveKeys {
            if sharedDefaults?.object(forKey: key) != nil {
                totalSize += 8
            }
        }
        
        return totalSize
    }
    
    /// Validates that stored data meets privacy requirements
    /// - Returns: True if all data is privacy-compliant
    func validatePrivacyCompliance() -> Bool {
        // Check data size limit (< 1KB as per requirements)
        let dataSize = getStoredDataSize()
        guard dataSize < 1024 else {
            print("SharedStorageManager: Privacy violation - data size exceeds 1KB: \(dataSize) bytes")
            return false
        }
        
        // Validate legacy scan result privacy
        if let legacyScanResult = getLatestScanResult() {
            guard legacyScanResult.isPrivacySafe else {
                print("SharedStorageManager: Privacy violation - legacy scan result contains unsafe data")
                return false
            }
        }
        
        // Validate shared scan result privacy
        if let data = sharedDefaults?.data(forKey: Keys.sharedScanResult) {
            do {
                let sharedScanResult = try JSONDecoder().decode(SharedScanResult.self, from: data)
                guard sharedScanResult.isPrivacySafe else {
                    print("SharedStorageManager: Privacy violation - shared scan result contains unsafe data")
                    return false
                }
            } catch {
                print("SharedStorageManager: Privacy warning - corrupted shared scan result data")
            }
        }
        
        print("SharedStorageManager: Privacy compliance validated - \(dataSize) bytes stored")
        return true
    }
    
    // MARK: - Settings Sync Methods (Story 3.8)
    
    /// Gets the screenshot image upload setting
    /// - Returns: True if screenshot images should be sent to backend
    func getSendScreenshotImagesSetting() -> Bool {
        return sharedDefaults?.bool(forKey: Keys.sendScreenshotImages) ?? false
    }
    
    /// Gets the voice alerts enabled setting
    /// - Returns: True if voice alerts are enabled
    func getVoiceAlertsEnabledSetting() -> Bool {
        return sharedDefaults?.bool(forKey: Keys.voiceAlertsEnabled) ?? false
    }
    
    /// Gets the scan result notifications setting
    /// - Returns: True if scan result notifications should be shown in keyboard
    func getScanResultNotificationsSetting() -> Bool {
        return sharedDefaults?.bool(forKey: Keys.scanResultNotifications) ?? true
    }
    
    /// Gets the last settings sync timestamp
    /// - Returns: Last settings sync date or nil
    func getLastSettingsSync() -> Date? {
        return sharedDefaults?.object(forKey: Keys.lastSettingsSync) as? Date
    }
    
    // MARK: - Screenshot Notification Methods (Story 4.1)
    
    /// Gets active screenshot notifications (non-expired)
    /// - Returns: Array of active notifications
    func getActiveScreenshotNotifications() -> [ScreenshotNotification] {
        guard let data = sharedDefaults?.data(forKey: Keys.screenshotNotifications) else {
            return []
        }
        
        do {
            let notifications = try JSONDecoder().decode([ScreenshotNotification].self, from: data)
            // Filter to only active and non-expired notifications
            return notifications.filter { $0.isValid }
        } catch {
            print("SharedStorageManager: Failed to decode screenshot notifications - \(error)")
            return []
        }
    }
    
    /// Writes screenshot notification to App Group storage
    /// Automatically cleans up expired notifications
    /// - Parameter notification: Notification to write
    /// - Returns: Success status
    @discardableResult
    func writeScreenshotNotification(_ notification: ScreenshotNotification) -> Bool {
        guard notification.isPrivacySafe else {
            print("SharedStorageManager: Rejected screenshot notification - privacy validation failed")
            return false
        }
        
        do {
            // Get existing notifications and filter to active ones
            var notifications = getActiveScreenshotNotifications()
            
            // Add new notification
            notifications.append(notification)
            
            // Limit to last 10 notifications to prevent storage bloat
            if notifications.count > 10 {
                notifications = Array(notifications.suffix(10))
            }
            
            // Encode and store
            let data = try JSONEncoder().encode(notifications)
            sharedDefaults?.set(data, forKey: Keys.screenshotNotifications)
            
            print("SharedStorageManager: Wrote screenshot notification - ID: \(notification.id)")
            return true
        } catch {
            print("SharedStorageManager: Failed to encode screenshot notification - \(error)")
            return false
        }
    }
    
    /// Cleans up expired screenshot notifications (older than 60 seconds)
    /// - Returns: Number of notifications removed
    @discardableResult
    func cleanupExpiredScreenshotNotifications() -> Int {
        guard let data = sharedDefaults?.data(forKey: Keys.screenshotNotifications) else {
            return 0
        }
        
        do {
            let allNotifications = try JSONDecoder().decode([ScreenshotNotification].self, from: data)
            let activeNotifications = allNotifications.filter { $0.isValid }
            let expiredCount = allNotifications.count - activeNotifications.count
            
            if expiredCount > 0 {
                let updatedData = try JSONEncoder().encode(activeNotifications)
                sharedDefaults?.set(updatedData, forKey: Keys.screenshotNotifications)
                print("SharedStorageManager: Cleaned up \(expiredCount) expired screenshot notifications")
            }
            
            return expiredCount
        } catch {
            print("SharedStorageManager: Failed to cleanup screenshot notifications - \(error)")
            return 0
        }
    }
    
    /// Gets screenshot detection enabled setting
    /// - Returns: True if screenshot detection is enabled (default: true)
    func getScreenshotDetectionEnabled() -> Bool {
        // Default to true if not set
        return sharedDefaults?.object(forKey: Keys.screenshotDetectionEnabled) as? Bool ?? true
    }
    
    /// Sets screenshot detection enabled setting
    /// - Parameter enabled: Whether screenshot detection should be enabled
    func setScreenshotDetectionEnabled(_ enabled: Bool) {
        sharedDefaults?.set(enabled, forKey: Keys.screenshotDetectionEnabled)
        print("SharedStorageManager: Screenshot detection \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Screenshot Scan Prompts Methods (Story 4.2)
    
    /// Gets screenshot scan prompts enabled setting
    /// - Returns: True if screenshot scan prompts should be shown (default: true)
    func getScreenshotScanPromptsEnabled() -> Bool {
        // Default to true if not set (enabled by default)
        return sharedDefaults?.object(forKey: Keys.screenshotScanPromptsEnabled) as? Bool ?? true
    }
    
    /// Sets screenshot scan prompts enabled setting
    /// - Parameter enabled: Whether screenshot scan prompts should be shown in keyboard
    func setScreenshotScanPromptsEnabled(_ enabled: Bool) {
        sharedDefaults?.set(enabled, forKey: Keys.screenshotScanPromptsEnabled)
        print("SharedStorageManager: Screenshot scan prompts \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Keyboard Sounds Settings Methods (Story 11.4)
    
    /// Gets whether keyboard sounds are enabled (default: true)
    /// - Returns: True if keyboard sounds should play (default: true)
    func getKeyboardSoundsEnabled() -> Bool {
        guard sharedDefaults != nil else {
            print("⚠️ SharedStorageManager: sharedDefaults is nil, returning default (true)")
            return true
        }
        
        // If never set, return default (true)
        if sharedDefaults?.object(forKey: Keys.keyboardSoundsEnabled) == nil {
            return true
        }
        
        let enabled = sharedDefaults?.bool(forKey: Keys.keyboardSoundsEnabled) ?? true
        print("📱 SharedStorageManager: Keyboard sounds preference - \(enabled ? "enabled" : "disabled")")
        return enabled
    }
    
    /// Sets whether keyboard sounds are enabled
    /// - Parameter enabled: Whether keyboard sounds should play
    func setKeyboardSoundsEnabled(_ enabled: Bool) {
        guard sharedDefaults != nil else {
            print("⚠️ SharedStorageManager: sharedDefaults is nil, cannot save preference")
            return
        }
        
        sharedDefaults?.set(enabled, forKey: Keys.keyboardSoundsEnabled)
        sharedDefaults?.synchronize()  // Force immediate save
        print("💾 SharedStorageManager: Keyboard sounds \(enabled ? "enabled" : "disabled")")
        
        // Post notification for KeyboardSoundService
        NotificationCenter.default.post(
            name: .keyboardSoundsPreferenceChanged,
            object: enabled
        )
        print("📢 SharedStorageManager: Posted keyboardSoundsPreferenceChanged notification")
    }

    // MARK: - Feature Flag Methods (Story 12.1)

    /// Gets feature flag enabled state
    /// - Parameter key: Feature flag identifier (e.g., "analyse_text")
    /// - Returns: True if feature is enabled, false if disabled
    func getFeatureFlagEnabled(_ key: String) -> Bool {
        let storageKey = Keys.featureFlagPrefix + key

        // Default to false for all features (disabled by default)
        guard sharedDefaults != nil else {
            print("⚠️ SharedStorageManager: sharedDefaults is nil, returning default (false)")
            return false
        }

        // If never set, return default (false)
        if sharedDefaults?.object(forKey: storageKey) == nil {
            print("📱 SharedStorageManager: Feature flag '\(key)' not set, returning default (false)")
            return false
        }

        let enabled = sharedDefaults?.bool(forKey: storageKey) ?? false
        print("📱 SharedStorageManager: Feature flag '\(key)' - \(enabled ? "enabled" : "disabled")")
        return enabled
    }

    /// Sets feature flag enabled state
    /// - Parameters:
    ///   - key: Feature flag identifier (e.g., "analyse_text")
    ///   - enabled: Whether feature should be enabled
    func setFeatureFlagEnabled(_ key: String, _ enabled: Bool) {
        let storageKey = Keys.featureFlagPrefix + key

        guard sharedDefaults != nil else {
            print("⚠️ SharedStorageManager: sharedDefaults is nil, cannot save feature flag '\(key)'")
            return
        }

        sharedDefaults?.set(enabled, forKey: storageKey)
        sharedDefaults?.synchronize()  // Force immediate save
        print("💾 SharedStorageManager: Feature flag '\(key)' \(enabled ? "enabled" : "disabled")")

        // Post notification for observers
        let notificationName = Notification.Name("featureFlagChanged_\(key)")
        NotificationCenter.default.post(
            name: notificationName,
            object: enabled
        )
        print("📢 SharedStorageManager: Posted \(notificationName.rawValue) notification")
    }

    /// Clears specific feature flag (resets to default)
    /// - Parameter key: Feature flag identifier to clear
    func clearFeatureFlag(_ key: String) {
        let storageKey = Keys.featureFlagPrefix + key
        sharedDefaults?.removeObject(forKey: storageKey)
        print("🗑️ SharedStorageManager: Cleared feature flag '\(key)'")
    }

    /// Gets all active feature flags (for debugging)
    /// - Returns: Dictionary of feature flag keys and their enabled states
    func getAllFeatureFlags() -> [String: Bool] {
        var flags: [String: Bool] = [:]

        // Known feature flags
        let knownFlags = ["analyse_text"]

        for flag in knownFlags {
            flags[flag] = getFeatureFlagEnabled(flag)
        }

        return flags
    }
}
