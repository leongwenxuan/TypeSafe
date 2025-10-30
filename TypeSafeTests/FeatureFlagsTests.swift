//
//  FeatureFlagsTests.swift
//  TypeSafeTests
//
//  Story 12.1: Feature Flag System Tests
//

import XCTest
@testable import TypeSafeKeyboard

class FeatureFlagsTests: XCTestCase {

    var sut: FeatureFlags!

    override func setUp() {
        super.setUp()
        sut = FeatureFlags.shared

        // Clear all shared data for clean test state
        SharedStorageManager.shared.clearAllSharedData()
    }

    override func tearDown() {
        SharedStorageManager.shared.clearAllSharedData()
        sut = nil
        super.tearDown()
    }

    // MARK: - Default State Tests

    func testAnalyseTextFeatureDefaultState() {
        // Given: Fresh feature flags
        // When: Reading default state
        let isEnabled = sut.isAnalyseTextEnabled

        // Then: Feature should be disabled by default
        XCTAssertFalse(isEnabled, "Analyse Text feature should be disabled by default")
    }

    func testGetDefaultAnalyseTextState() {
        // Given: Feature flags instance
        // When: Getting default state
        let defaultState = sut.getDefaultAnalyseTextState()

        // Then: Should return false
        XCTAssertFalse(defaultState, "Default Analyse Text state should be false")
    }

    // MARK: - Enable/Disable Tests

    func testEnableAnalyseTextFeature() {
        // Given: Feature flag disabled by default
        XCTAssertFalse(sut.isAnalyseTextEnabled)

        // When: Enabling feature
        sut.isAnalyseTextEnabled = true

        // Then: Feature should be enabled
        XCTAssertTrue(sut.isAnalyseTextEnabled, "Feature should be enabled after setting to true")
    }

    func testDisableAnalyseTextFeature() {
        // Given: Feature flag enabled
        sut.isAnalyseTextEnabled = true
        XCTAssertTrue(sut.isAnalyseTextEnabled)

        // When: Disabling feature
        sut.isAnalyseTextEnabled = false

        // Then: Feature should be disabled
        XCTAssertFalse(sut.isAnalyseTextEnabled, "Feature should be disabled after setting to false")
    }

    // MARK: - Persistence Tests

    func testFeatureFlagPersistence() {
        // Given: Feature enabled
        sut.isAnalyseTextEnabled = true

        // When: Reading value again (simulating app restart)
        let persistedValue = sut.isAnalyseTextEnabled

        // Then: Value should be persisted
        XCTAssertTrue(persistedValue, "Feature flag should persist across reads")
    }

    func testFeatureFlagPersistenceAcrossInstances() {
        // Given: Feature enabled via first instance
        sut.isAnalyseTextEnabled = true

        // When: Reading from SharedStorageManager directly
        let directValue = SharedStorageManager.shared.getFeatureFlagEnabled("analyse_text")

        // Then: Value should match
        XCTAssertTrue(directValue, "Feature flag should persist in SharedStorageManager")
    }

    // MARK: - Reset Tests

    func testResetToDefaults() {
        // Given: Feature enabled
        sut.isAnalyseTextEnabled = true
        XCTAssertTrue(sut.isAnalyseTextEnabled)

        // When: Resetting to defaults
        sut.resetToDefaults()

        // Then: Feature should be disabled (default state)
        XCTAssertFalse(sut.isAnalyseTextEnabled, "Feature should be disabled after reset")
    }

    // MARK: - Singleton Tests

    func testSingletonPattern() {
        // Given: Two references to FeatureFlags.shared
        let instance1 = FeatureFlags.shared
        let instance2 = FeatureFlags.shared

        // When: Modifying state via first instance
        instance1.isAnalyseTextEnabled = true

        // Then: State should be reflected in second instance
        XCTAssertTrue(instance2.isAnalyseTextEnabled, "Singleton should share state")
    }

    // MARK: - Logging Tests

    func testLogCurrentState() {
        // Given: Feature flags in known state
        sut.isAnalyseTextEnabled = false

        // When: Logging state
        // Then: Should not crash (logging test)
        XCTAssertNoThrow(sut.logCurrentState(), "Logging should not throw exceptions")
    }
}
