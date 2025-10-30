//
//  SharedStorageManagerFeatureFlagsTests.swift
//  TypeSafeTests
//
//  Story 12.1: SharedStorageManager Feature Flag Extensions Tests
//

import XCTest
@testable import TypeSafeKeyboard

class SharedStorageManagerFeatureFlagsTests: XCTestCase {

    var sut: SharedStorageManager!

    override func setUp() {
        super.setUp()
        sut = SharedStorageManager.shared
        sut.clearAllSharedData()
    }

    override func tearDown() {
        sut.clearAllSharedData()
        sut = nil
        super.tearDown()
    }

    // MARK: - Get/Set Tests

    func testGetFeatureFlagDefaultValue() {
        // When: Getting feature flag that was never set
        let enabled = sut.getFeatureFlagEnabled("analyse_text")

        // Then: Should return false (default)
        XCTAssertFalse(enabled, "Unset feature flag should default to false")
    }

    func testSetFeatureFlagEnabled() {
        // When: Setting feature flag to true
        sut.setFeatureFlagEnabled("analyse_text", true)

        // Then: Should return true when retrieved
        let enabled = sut.getFeatureFlagEnabled("analyse_text")
        XCTAssertTrue(enabled, "Feature flag should be enabled after setting to true")
    }

    func testSetFeatureFlagDisabled() {
        // Given: Feature flag enabled
        sut.setFeatureFlagEnabled("analyse_text", true)

        // When: Setting to false
        sut.setFeatureFlagEnabled("analyse_text", false)

        // Then: Should return false
        let enabled = sut.getFeatureFlagEnabled("analyse_text")
        XCTAssertFalse(enabled, "Feature flag should be disabled after setting to false")
    }

    // MARK: - Multiple Flags Tests

    func testMultipleFeatureFlags() {
        // When: Setting multiple different flags
        sut.setFeatureFlagEnabled("analyse_text", true)
        sut.setFeatureFlagEnabled("other_feature", false)

        // Then: Each should maintain independent state
        XCTAssertTrue(sut.getFeatureFlagEnabled("analyse_text"))
        XCTAssertFalse(sut.getFeatureFlagEnabled("other_feature"))
    }

    // MARK: - Clear Tests

    func testClearFeatureFlag() {
        // Given: Feature flag enabled
        sut.setFeatureFlagEnabled("analyse_text", true)
        XCTAssertTrue(sut.getFeatureFlagEnabled("analyse_text"))

        // When: Clearing flag
        sut.clearFeatureFlag("analyse_text")

        // Then: Should return default (false)
        XCTAssertFalse(sut.getFeatureFlagEnabled("analyse_text"))
    }

    // MARK: - Get All Flags Tests

    func testGetAllFeatureFlags() {
        // Given: Known flags in various states
        sut.setFeatureFlagEnabled("analyse_text", false)

        // When: Getting all flags
        let allFlags = sut.getAllFeatureFlags()

        // Then: Should return dictionary with known flags
        XCTAssertNotNil(allFlags["analyse_text"])
        XCTAssertFalse(allFlags["analyse_text"]!)
    }

    func testGetAllFeatureFlagsEmpty() {
        // Given: No flags set
        // When: Getting all flags
        let allFlags = sut.getAllFeatureFlags()

        // Then: Should return dictionary with defaults
        XCTAssertEqual(allFlags.count, 1) // One known flag (analyse_text)
        XCTAssertFalse(allFlags["analyse_text"]!) // Default is false
    }

    // MARK: - Notification Tests

    func testFeatureFlagChangeNotification() {
        // Given: Notification expectation
        let expectation = self.expectation(forNotification: Notification.Name("featureFlagChanged_analyse_text"), object: nil)

        // When: Setting feature flag
        sut.setFeatureFlagEnabled("analyse_text", true)

        // Then: Notification should be posted
        wait(for: [expectation], timeout: 1.0)
    }
}
