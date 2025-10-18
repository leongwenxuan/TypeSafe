//
//  SettingsManagerTests.swift
//  TypeSafeTests
//
//  Story 3.8: Privacy Controls & Settings
//  Unit tests for SettingsManager functionality
//

import XCTest
@testable import TypeSafe

final class SettingsManagerTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    var testUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults suite
        testUserDefaults = UserDefaults(suiteName: "com.typesafe.tests")!
        testUserDefaults.removePersistentDomain(forName: "com.typesafe.tests")
        
        // Initialize SettingsManager with test UserDefaults
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        // Clean up test data
        testUserDefaults.removePersistentDomain(forName: "com.typesafe.tests")
        testUserDefaults = nil
        settingsManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithDefaultSettings() {
        // Given: Fresh SettingsManager
        // When: Initialized
        // Then: Should have default values
        XCTAssertFalse(settingsManager.settings.fullAccessEnabled)
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        XCTAssertFalse(settingsManager.settings.voiceAlertsEnabled)
        XCTAssertTrue(settingsManager.settings.scanResultNotifications)
        XCTAssertEqual(settingsManager.settings.dataRetentionDays, 7)
        XCTAssertFalse(settingsManager.settings.privacyPolicyAccepted)
    }
    
    func testInitializationLoadsExistingSettings() {
        // Given: Settings saved to UserDefaults
        var savedSettings = AppSettings()
        savedSettings.sendScreenshotImages = true
        savedSettings.voiceAlertsEnabled = true
        savedSettings.privacyPolicyAccepted = true
        
        let data = try! JSONEncoder().encode(savedSettings)
        testUserDefaults.set(data, forKey: "typesafe.app_settings")
        
        // When: New SettingsManager initialized
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        
        // Then: Should load saved settings
        XCTAssertTrue(newManager.settings.sendScreenshotImages)
        XCTAssertTrue(newManager.settings.voiceAlertsEnabled)
        XCTAssertTrue(newManager.settings.privacyPolicyAccepted)
    }
    
    // MARK: - Persistence Tests
    
    func testSaveSettings() {
        // Given: Modified settings
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.settings.voiceAlertsEnabled = true
        
        // When: Settings saved
        let success = settingsManager.saveSettings()
        
        // Then: Should save successfully
        XCTAssertTrue(success)
        
        // And: Settings should persist
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertTrue(newManager.settings.sendScreenshotImages)
        XCTAssertTrue(newManager.settings.voiceAlertsEnabled)
    }
    
    func testSaveSettingsValidation() {
        // Given: Invalid settings (negative retention days)
        settingsManager.settings.dataRetentionDays = -1
        
        // When: Attempting to save
        let success = settingsManager.saveSettings()
        
        // Then: Should fail validation
        XCTAssertFalse(success)
    }
    
    func testResetSettings() {
        // Given: Modified settings
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.settings.voiceAlertsEnabled = true
        settingsManager.settings.privacyPolicyAccepted = true
        settingsManager.saveSettings()
        
        // When: Settings reset
        settingsManager.resetSettings()
        
        // Then: Should return to defaults
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        XCTAssertFalse(settingsManager.settings.voiceAlertsEnabled)
        XCTAssertFalse(settingsManager.settings.privacyPolicyAccepted)
    }
    
    // MARK: - Individual Setting Update Tests
    
    func testUpdateScreenshotImageSetting() {
        // Given: Default screenshot setting (false)
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        
        // When: Updating to true
        settingsManager.updateScreenshotImageSetting(true)
        
        // Then: Should update and persist
        XCTAssertTrue(settingsManager.settings.sendScreenshotImages)
        
        // Verify persistence
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertTrue(newManager.settings.sendScreenshotImages)
    }
    
    func testUpdateVoiceAlertsSetting() {
        // Given: Default voice alerts setting (false)
        XCTAssertFalse(settingsManager.settings.voiceAlertsEnabled)
        
        // When: Updating to true
        settingsManager.updateVoiceAlertsSetting(true)
        
        // Then: Should update and persist
        XCTAssertTrue(settingsManager.settings.voiceAlertsEnabled)
    }
    
    func testUpdateNotificationsSetting() {
        // Given: Default notifications setting (true)
        XCTAssertTrue(settingsManager.settings.scanResultNotifications)
        
        // When: Updating to false
        settingsManager.updateNotificationsSetting(false)
        
        // Then: Should update and persist
        XCTAssertFalse(settingsManager.settings.scanResultNotifications)
    }
    
    func testAcceptPrivacyPolicy() {
        // Given: Privacy policy not accepted
        XCTAssertFalse(settingsManager.settings.privacyPolicyAccepted)
        
        // When: Accepting privacy policy
        settingsManager.acceptPrivacyPolicy()
        
        // Then: Should update and persist
        XCTAssertTrue(settingsManager.settings.privacyPolicyAccepted)
    }
    
    // MARK: - Data Deletion Tests
    
    func testDeleteAllUserData() {
        // Given: Settings and data exist
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.settings.voiceAlertsEnabled = true
        settingsManager.settings.privacyPolicyAccepted = true
        settingsManager.saveSettings()
        
        testUserDefaults.set("test-session", forKey: "TypeSafe.SessionID")
        testUserDefaults.set(true, forKey: "TypeSafe.ImageUploadEnabled")
        
        // When: Deleting all user data
        let success = settingsManager.deleteAllUserData()
        
        // Then: Should succeed
        XCTAssertTrue(success)
        
        // And: All settings reset to defaults
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        XCTAssertFalse(settingsManager.settings.voiceAlertsEnabled)
        XCTAssertFalse(settingsManager.settings.privacyPolicyAccepted)
        
        // And: Session ID regenerated
        let newSessionID = testUserDefaults.string(forKey: "TypeSafe.SessionID")
        XCTAssertNotNil(newSessionID)
        XCTAssertNotEqual(newSessionID, "test-session")
        
        // And: Other data cleared
        XCTAssertNil(testUserDefaults.object(forKey: "TypeSafe.ImageUploadEnabled"))
    }
    
    // MARK: - Full Access Detection Tests
    
    func testUpdateFullAccessStatus() {
        // Given: Full Access not enabled
        XCTAssertFalse(settingsManager.settings.fullAccessEnabled)
        
        // When: Updating Full Access status
        settingsManager.updateFullAccessStatus(true)
        
        // Then: Should update (but not persist to UserDefaults - system-detected only)
        XCTAssertTrue(settingsManager.settings.fullAccessEnabled)
        
        // Verify it doesn't persist (system-detected value)
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        XCTAssertFalse(newManager.settings.fullAccessEnabled)
    }
    
    // MARK: - Settings Dictionary Tests
    
    func testSettingsDictionary() {
        // Given: Settings with known values
        settingsManager.settings.fullAccessEnabled = true
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.settings.voiceAlertsEnabled = false
        settingsManager.settings.scanResultNotifications = true
        settingsManager.settings.dataRetentionDays = 7
        settingsManager.settings.privacyPolicyAccepted = true
        
        // When: Getting settings dictionary
        let dict = settingsManager.settingsDictionary
        
        // Then: Should contain all settings
        XCTAssertEqual(dict["fullAccessEnabled"] as? Bool, true)
        XCTAssertEqual(dict["sendScreenshotImages"] as? Bool, true)
        XCTAssertEqual(dict["voiceAlertsEnabled"] as? Bool, false)
        XCTAssertEqual(dict["scanResultNotifications"] as? Bool, true)
        XCTAssertEqual(dict["dataRetentionDays"] as? Int, 7)
        XCTAssertEqual(dict["privacyPolicyAccepted"] as? Bool, true)
        XCTAssertNotNil(dict["lastSettingsSync"])
    }
    
    // MARK: - Performance Tests
    
    func testSaveSettingsPerformance() {
        measure {
            // Save settings 100 times
            for _ in 0..<100 {
                settingsManager.settings.sendScreenshotImages.toggle()
                settingsManager.saveSettings()
            }
        }
    }
    
    func testLoadSettingsPerformance() {
        // Save some settings first
        settingsManager.saveSettings()
        
        measure {
            // Load settings 100 times
            for _ in 0..<100 {
                _ = SettingsManager(userDefaults: testUserDefaults)
            }
        }
    }
}

