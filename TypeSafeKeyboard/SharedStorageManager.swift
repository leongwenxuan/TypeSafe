//
//  SharedStorageManager.swift
//  TypeSafeKeyboard
//
//  Story 2.7: App Group Shared State
//  Manages shared state between keyboard extension and companion app
//

import Foundation

/// Manages shared state between keyboard extension and companion app via App Group
/// Stores minimal, privacy-safe data including scan results, settings, and timestamps
class SharedStorageManager {
    
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
        
        let keys = [
            Keys.latestScanResult,
            Keys.lastAnalysisTimestamp,
            Keys.alertPreferences,
            Keys.privacySettings
        ]
        
        for key in keys {
            if let data = sharedDefaults?.data(forKey: key) {
                totalSize += data.count
            } else if let _ = sharedDefaults?.object(forKey: key) {
                // Estimate 8 bytes for Date objects
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
        
        // Validate scan result privacy
        if let scanResult = getLatestScanResult() {
            guard scanResult.isPrivacySafe else {
                print("SharedStorageManager: Privacy violation - scan result contains unsafe data")
                return false
            }
        }
        
        print("SharedStorageManager: Privacy compliance validated - \(dataSize) bytes stored")
        return true
    }
}
