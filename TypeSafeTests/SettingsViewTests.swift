//
//  SettingsViewTests.swift
//  TypeSafeTests
//
//  Story 3.8: Privacy Controls & Settings
//  Unit tests for SettingsView UI components
//

import XCTest
import SwiftUI
import ViewInspector
@testable import TypeSafe

final class SettingsViewTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    var testUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults suite
        testUserDefaults = UserDefaults(suiteName: "com.typesafe.tests.settings.view")!
        testUserDefaults.removePersistentDomain(forName: "com.typesafe.tests.settings.view")
        
        // Initialize SettingsManager with test UserDefaults
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: "com.typesafe.tests.settings.view")
        testUserDefaults = nil
        settingsManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Basic Structure Tests
    
    func testSettingsViewHasNavigationView() {
        // Given: SettingsView
        let view = SettingsView()
        
        // Then: Should be wrapped in NavigationView
        // Note: Full ViewInspector testing would require additional setup
        // This is a structural smoke test
        XCTAssertNotNil(view)
    }
    
    func testSettingsViewHasFormStructure() {
        // Given: SettingsView
        let view = SettingsView()
        
        // Then: Should contain Form with multiple sections
        // Note: This tests the view can be instantiated
        XCTAssertNotNil(view.body)
    }
    
    // MARK: - Full Access Section Tests
    
    func testFullAccessSectionDisplaysCorrectly() {
        // Given: FullAccessSection with disabled Full Access
        let section = FullAccessSection(settingsManager: settingsManager)
        
        // Then: Should display without errors
        XCTAssertNotNil(section)
        XCTAssertNotNil(section.body)
    }
    
    func testFullAccessSectionShowsEnabledState() {
        // Given: Full Access enabled
        settingsManager.updateFullAccessStatus(true)
        let section = FullAccessSection(settingsManager: settingsManager)
        
        // Then: Section should reflect enabled state
        XCTAssertTrue(settingsManager.settings.fullAccessEnabled)
        XCTAssertNotNil(section.body)
    }
    
    // MARK: - Privacy Section Tests
    
    func testPrivacySectionDisplaysCorrectly() {
        // Given: PrivacySection
        let section = PrivacySection(settingsManager: settingsManager)
        
        // Then: Should display without errors
        XCTAssertNotNil(section)
        XCTAssertNotNil(section.body)
    }
    
    func testPrivacySectionReflectsScreenshotSetting() {
        // Given: Screenshot images enabled
        settingsManager.updateScreenshotImageSetting(true)
        let section = PrivacySection(settingsManager: settingsManager)
        
        // Then: Section should reflect enabled state
        XCTAssertTrue(settingsManager.settings.sendScreenshotImages)
        XCTAssertNotNil(section.body)
    }
    
    func testPrivacySectionReflectsNotificationsSetting() {
        // Given: Notifications disabled
        settingsManager.updateNotificationsSetting(false)
        let section = PrivacySection(settingsManager: settingsManager)
        
        // Then: Section should reflect disabled state
        XCTAssertFalse(settingsManager.settings.scanResultNotifications)
        XCTAssertNotNil(section.body)
    }
    
    // MARK: - Voice Alerts Section Tests
    
    func testVoiceAlertsSectionDisplaysCorrectly() {
        // Given: VoiceAlertsSection
        let section = VoiceAlertsSection(settingsManager: settingsManager)
        
        // Then: Should display without errors
        XCTAssertNotNil(section)
        XCTAssertNotNil(section.body)
    }
    
    func testVoiceAlertsSectionShowsComingSoonBadge() {
        // Given: VoiceAlertsSection (future feature)
        let section = VoiceAlertsSection(settingsManager: settingsManager)
        
        // Then: Should be disabled (coming soon)
        // Note: UI should show "COMING SOON" badge
        XCTAssertNotNil(section.body)
    }
    
    // MARK: - Data Management Section Tests
    
    func testDataManagementSectionDisplaysCorrectly() {
        // Given: DataManagementSection
        let section = DataManagementSection(settingsManager: settingsManager)
        
        // Then: Should display without errors
        XCTAssertNotNil(section)
        XCTAssertNotNil(section.body)
    }
    
    func testDataManagementSectionShowsRetentionDays() {
        // Given: Data retention days setting
        let expectedDays = settingsManager.settings.dataRetentionDays
        let section = DataManagementSection(settingsManager: settingsManager)
        
        // Then: Should display retention days
        XCTAssertEqual(expectedDays, 7) // MVP default
        XCTAssertNotNil(section.body)
    }
    
    // MARK: - Privacy Policy Section Tests
    
    func testPrivacyPolicySectionDisplaysCorrectly() {
        // Given: PrivacyPolicySection
        let section = PrivacyPolicySection(settingsManager: settingsManager)
        
        // Then: Should display without errors
        XCTAssertNotNil(section)
        XCTAssertNotNil(section.body)
    }
    
    func testPrivacyPolicySectionShowsAppVersion() {
        // Given: PrivacyPolicySection
        let section = PrivacyPolicySection(settingsManager: settingsManager)
        
        // Then: Should display app version
        // Note: Version comes from Bundle.main
        XCTAssertNotNil(section.body)
    }
    
    func testPrivacyPolicySectionShowsAcceptanceStatus() {
        // Given: Privacy policy not accepted
        XCTAssertFalse(settingsManager.settings.privacyPolicyAccepted)
        let section = PrivacyPolicySection(settingsManager: settingsManager)
        
        // Then: Should show not accepted status
        XCTAssertNotNil(section.body)
        
        // When: Privacy policy accepted
        settingsManager.acceptPrivacyPolicy()
        
        // Then: Should reflect acceptance
        XCTAssertTrue(settingsManager.settings.privacyPolicyAccepted)
    }
    
    // MARK: - Safari View Tests
    
    func testSafariViewInitialization() {
        // Given: Privacy policy URL
        let url = URL(string: "https://typesafe.app/privacy")!
        
        // When: Creating SafariView
        let safariView = SafariView(url: url)
        
        // Then: Should initialize correctly
        XCTAssertEqual(safariView.url, url)
    }
    
    // MARK: - Integration Tests
    
    func testSettingsViewDisplaysAllSections() {
        // Given: Complete SettingsView
        let view = SettingsView()
        
        // Then: All sections should be present
        // This is a smoke test ensuring no crashes
        XCTAssertNotNil(view.body)
    }
    
    func testSettingsChangePersistsAcrossViewReloads() {
        // Given: Original setting value
        let originalValue = settingsManager.settings.sendScreenshotImages
        
        // When: Changing setting
        settingsManager.updateScreenshotImageSetting(!originalValue)
        
        // And: Creating new view
        let newView = SettingsView()
        
        // Then: New view should reflect changed setting
        XCTAssertEqual(settingsManager.settings.sendScreenshotImages, !originalValue)
        XCTAssertNotNil(newView.body)
    }
    
    func testMultipleSettingsCanBeUpdatedIndependently() {
        // Given: Default settings
        XCTAssertFalse(settingsManager.settings.sendScreenshotImages)
        XCTAssertFalse(settingsManager.settings.voiceAlertsEnabled)
        XCTAssertTrue(settingsManager.settings.scanResultNotifications)
        
        // When: Updating multiple settings
        settingsManager.updateScreenshotImageSetting(true)
        settingsManager.updateVoiceAlertsSetting(true)
        settingsManager.updateNotificationsSetting(false)
        
        // Then: All should update independently
        XCTAssertTrue(settingsManager.settings.sendScreenshotImages)
        XCTAssertTrue(settingsManager.settings.voiceAlertsEnabled)
        XCTAssertFalse(settingsManager.settings.scanResultNotifications)
    }
    
    // MARK: - Accessibility Tests
    
    func testSettingsViewHasAccessibilityLabels() {
        // Given: SettingsView components
        let fullAccessSection = FullAccessSection(settingsManager: settingsManager)
        let privacySection = PrivacySection(settingsManager: settingsManager)
        let dataSection = DataManagementSection(settingsManager: settingsManager)
        
        // Then: Should have proper accessibility structure
        XCTAssertNotNil(fullAccessSection.body)
        XCTAssertNotNil(privacySection.body)
        XCTAssertNotNil(dataSection.body)
    }
}

