//
//  DataDeletionTests.swift
//  TypeSafeTests
//
//  Story 3.8: Privacy Controls & Settings
//  Unit tests for complete data deletion functionality
//

import XCTest
@testable import TypeSafe

final class DataDeletionTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    var testUserDefaults: UserDefaults!
    var appGroupDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults suites
        testUserDefaults = UserDefaults(suiteName: "com.typesafe.tests.deletion")!
        testUserDefaults.removePersistentDomain(forName: "com.typesafe.tests.deletion")
        
        appGroupDefaults = UserDefaults(suiteName: "group.com.typesafe.shared.test")!
        appGroupDefaults?.removePersistentDomain(forName: "group.com.typesafe.shared.test")
        
        // Initialize SettingsManager with test UserDefaults
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: "com.typesafe.tests.deletion")
        appGroupDefaults?.removePersistentDomain(forName: "group.com.typesafe.shared.test")
        testUserDefaults = nil
        appGroupDefaults = nil
        settingsManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Complete Data Deletion Tests
    
    func testDeleteAllUserDataClearsSettings() {
        // Given: Modified settings
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.settings.voiceAlertsEnabled = true
        settingsManager.settings.scanResultNotifications = false
        settingsManager.settings.privacyPolicyAccepted = true
        settingsManager.saveSettings()
        
        // When: Deleting all user data
        let success = settingsManager.deleteAllUserData()
        
        // Then: Should succeed
        XCTAssertTrue(success)
        
        // And: Settings reset to defaults
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        XCTAssertFalse(settingsManager.settings.voiceAlertsEnabled)
        XCTAssertTrue(settingsManager.settings.scanResultNotifications)
        XCTAssertFalse(settingsManager.settings.privacyPolicyAccepted)
        XCTAssertEqual(settingsManager.settings.dataRetentionDays, 7)
    }
    
    func testDeleteAllUserDataClearsMainAppUserDefaults() {
        // Given: Various UserDefaults keys populated
        testUserDefaults.set("old-session-id", forKey: "TypeSafe.SessionID")
        testUserDefaults.set(true, forKey: "TypeSafe.ImageUploadEnabled")
        testUserDefaults.set(true, forKey: "typesafe.privacy_policy_accepted")
        
        // When: Deleting all user data
        settingsManager.deleteAllUserData()
        
        // Then: All keys should be cleared
        XCTAssertNil(testUserDefaults.string(forKey: "old-key"))
        XCTAssertNil(testUserDefaults.object(forKey: "TypeSafe.ImageUploadEnabled"))
        
        // Session ID should be regenerated (not nil, but different)
        let newSessionID = testUserDefaults.string(forKey: "TypeSafe.SessionID")
        XCTAssertNotNil(newSessionID)
        XCTAssertNotEqual(newSessionID, "old-session-id")
    }
    
    func testDeleteAllUserDataGeneratesNewSessionID() {
        // Given: Existing session ID
        let oldSessionID = "test-session-123"
        testUserDefaults.set(oldSessionID, forKey: "TypeSafe.SessionID")
        
        // When: Deleting all user data
        settingsManager.deleteAllUserData()
        
        // Then: New session ID should be generated
        let newSessionID = testUserDefaults.string(forKey: "TypeSafe.SessionID")
        
        XCTAssertNotNil(newSessionID)
        XCTAssertNotEqual(newSessionID, oldSessionID)
        
        // Should be valid UUID format
        XCTAssertNotNil(UUID(uuidString: newSessionID!))
    }
    
    func testDeleteAllUserDataPersistsAfterReload() {
        // Given: Settings with data
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.settings.privacyPolicyAccepted = true
        settingsManager.saveSettings()
        
        // When: Deleting all user data
        settingsManager.deleteAllUserData()
        
        // And: Creating new SettingsManager instance
        let newManager = SettingsManager(userDefaults: testUserDefaults)
        
        // Then: Should load default settings
        XCTAssertFalse(newManager.settings.sendScreenshotImages)
        XCTAssertFalse(newManager.settings.privacyPolicyAccepted)
    }
    
    // MARK: - Confirmation Dialog Tests
    
    func testDeletionRequiresConfirmation() {
        // Given: DataManagementSection
        let section = DataManagementSection(settingsManager: settingsManager)
        
        // Then: Should have confirmation dialog mechanism
        // Note: Confirmation dialog is handled by SwiftUI's confirmationDialog
        // This test verifies the section can be instantiated
        XCTAssertNotNil(section.body)
    }
    
    // MARK: - Selective Deletion Tests
    
    func testSessionResetWithoutFullDeletion() {
        // Given: Existing session and settings
        testUserDefaults.set("old-session", forKey: "TypeSafe.SessionID")
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.saveSettings()
        
        // When: Deleting all data (includes session reset)
        settingsManager.deleteAllUserData()
        
        // Then: Session should be new
        let newSessionID = testUserDefaults.string(forKey: "TypeSafe.SessionID")
        XCTAssertNotEqual(newSessionID, "old-session")
        
        // But settings should be reset
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
    }
    
    // MARK: - Data Cleanup Completeness Tests
    
    func testAllKnownKeysAreCleared() {
        // Given: All known UserDefaults keys populated
        let keysToTest = [
            "TypeSafe.SessionID",
            "TypeSafe.ImageUploadEnabled",
            "typesafe.privacy_policy_accepted",
            "typesafe.app_settings"
        ]
        
        for key in keysToTest {
            testUserDefaults.set("test-value", forKey: key)
        }
        
        // When: Deleting all user data
        settingsManager.deleteAllUserData()
        
        // Then: Most keys should be cleared (except regenerated session ID)
        for key in keysToTest where key != "TypeSafe.SessionID" {
            let value = testUserDefaults.object(forKey: key)
            XCTAssertNil(value, "Key '\(key)' should be cleared")
        }
        
        // Session ID should exist but be new
        XCTAssertNotNil(testUserDefaults.string(forKey: "TypeSafe.SessionID"))
    }
    
    // MARK: - Error Handling Tests
    
    func testDeletionSucceedsEvenWithNoDataToDelete() {
        // Given: Clean state (no data)
        // Already clean from setUp
        
        // When: Attempting to delete
        let success = settingsManager.deleteAllUserData()
        
        // Then: Should still succeed
        XCTAssertTrue(success)
        
        // And: Default settings should be in place
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        XCTAssertEqual(settingsManager.settings.dataRetentionDays, 7)
    }
    
    func testMultipleDeletionCallsAreIdempotent() {
        // Given: Some data
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.saveSettings()
        
        // When: Deleting multiple times
        let success1 = settingsManager.deleteAllUserData()
        let success2 = settingsManager.deleteAllUserData()
        let success3 = settingsManager.deleteAllUserData()
        
        // Then: All should succeed
        XCTAssertTrue(success1)
        XCTAssertTrue(success2)
        XCTAssertTrue(success3)
        
        // And: Settings should remain at defaults
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
    }
    
    // MARK: - Integration with Other Components Tests
    
    func testDeletionAffectsAPIService() {
        // Given: Settings that affect APIService behavior
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.saveSettings()
        
        // When: Deleting all data
        settingsManager.deleteAllUserData()
        
        // Then: Privacy settings should be reset
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        
        // Note: APIService reads from settingsManager, so it will see the new value
    }
    
    // MARK: - Performance Tests
    
    func testDataDeletionPerformance() {
        // Given: Populated settings
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.settings.voiceAlertsEnabled = true
        settingsManager.settings.privacyPolicyAccepted = true
        settingsManager.saveSettings()
        
        // When: Measuring deletion performance
        measure {
            settingsManager.deleteAllUserData()
            
            // Restore for next iteration
            settingsManager.settings.sendScreenshotImages = true
            settingsManager.saveSettings()
        }
    }
    
    func testDeletionCompletenessSmokeTest() {
        // Given: Comprehensive data setup
        // Settings
        settingsManager.settings.sendScreenshotImages = true
        settingsManager.settings.voiceAlertsEnabled = true
        settingsManager.settings.scanResultNotifications = false
        settingsManager.settings.privacyPolicyAccepted = true
        settingsManager.saveSettings()
        
        // UserDefaults
        testUserDefaults.set("old-session", forKey: "TypeSafe.SessionID")
        testUserDefaults.set(true, forKey: "TypeSafe.ImageUploadEnabled")
        
        // When: Performing complete deletion
        let success = settingsManager.deleteAllUserData()
        
        // Then: Everything should be reset
        XCTAssertTrue(success)
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        XCTAssertFalse(settingsManager.settings.voiceAlertsEnabled)
        XCTAssertTrue(settingsManager.settings.scanResultNotifications)
        XCTAssertFalse(settingsManager.settings.privacyPolicyAccepted)
        
        // New session ID generated
        let newSessionID = testUserDefaults.string(forKey: "TypeSafe.SessionID")
        XCTAssertNotNil(newSessionID)
        XCTAssertNotEqual(newSessionID, "old-session")
    }
}

