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
        let enableHapticFeedback: Bool
        let riskThreshold: String  // "low", "medium", "high"
        
        static let `default` = AlertPreferences(
            showBanners: true,
            enableHapticFeedback: true,
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
}
