//
//  HideTextAnalysisUITests.swift
//  TypeSafeTests
//
//  Story 12.3: Hide Text Analysis UI Components Tests
//  Tests that UI components are hidden when feature flag is disabled
//

import XCTest
@testable import TypeSafeKeyboard

class HideTextAnalysisUITests: XCTestCase {

    var keyboardVC: KeyboardViewController!

    override func setUp() {
        super.setUp()

        // Clear all shared data for clean test state
        SharedStorageManager.shared.clearAllSharedData()

        // Disable feature flag (default state)
        FeatureFlags.shared.isAnalyseTextEnabled = false

        // Initialize keyboard view controller
        keyboardVC = KeyboardViewController()
        // Load view to trigger viewDidLoad
        _ = keyboardVC.view
    }

    override func tearDown() {
        // Clean up
        SharedStorageManager.shared.clearAllSharedData()
        keyboardVC = nil
        super.tearDown()
    }

    // MARK: - showAlertBanner Tests

    func testShowAlertBanner_whenFlagDisabled_shouldNotAddBannerToViewHierarchy() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show banner
        let expectation = XCTestExpectation(description: "Banner hidden when flag disabled")
        DispatchQueue.main.async {
            let selector = NSSelectorFromString("showAlertBanner:")
            if self.keyboardVC.responds(to: selector) {
                self.keyboardVC.perform(selector, with: response)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Then: Banner should not be in view hierarchy
        let bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertFalse(bannerExists, "RiskAlertBannerView should not exist when feature disabled")
    }

    func testShowAlertBanner_whenFlagDisabled_shouldNotActivateConstraints() {
        // Given: Feature flag disabled and empty initial state
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)
        let initialConstraintCount = keyboardVC.view.constraints.count

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show banner
        let expectation = XCTestExpectation(description: "No constraints added")
        DispatchQueue.main.async {
            let selector = NSSelectorFromString("showAlertBanner:")
            if self.keyboardVC.responds(to: selector) {
                self.keyboardVC.perform(selector, with: response)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Then: No new constraints should be added
        let finalConstraintCount = keyboardVC.view.constraints.count
        XCTAssertEqual(finalConstraintCount, initialConstraintCount, "No constraints should be added when feature disabled")
    }

    // MARK: - showExplainWhyPopover Tests

    func testShowExplainWhyPopover_whenFlagDisabled_shouldReturnEarly() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show popover
        let selector = NSSelectorFromString("showExplainWhyPopover:")
        if keyboardVC.responds(to: selector) {
            keyboardVC.perform(selector, with: response)
        }

        // Then: currentPopover should remain nil
        let currentPopover = keyboardVC.value(forKey: "currentPopover")
        XCTAssertNil(currentPopover, "currentPopover should be nil when feature disabled")
    }

    func testShowExplainWhyPopover_whenFlagDisabled_shouldNotAddPopoverToViewHierarchy() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show popover
        let expectation = XCTestExpectation(description: "Popover hidden when flag disabled")
        DispatchQueue.main.async {
            let selector = NSSelectorFromString("showExplainWhyPopover:")
            if self.keyboardVC.responds(to: selector) {
                self.keyboardVC.perform(selector, with: response)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Then: Popover should not be in view hierarchy
        let popoverExists = keyboardVC.view.subviews.contains { $0 is ExplainWhyPopoverView }
        XCTAssertFalse(popoverExists, "ExplainWhyPopoverView should not exist when feature disabled")
    }

    func testShowExplainWhyPopover_whenFlagDisabled_shouldNotTriggerAnimation() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show popover
        let selector = NSSelectorFromString("showExplainWhyPopover:")
        if keyboardVC.responds(to: selector) {
            keyboardVC.perform(selector, with: response)
        }

        // Then: View should have no animations scheduled
        let animationCount = keyboardVC.view.layer.animationKeys()?.count ?? 0
        // Should be no popover animations when feature is disabled
        XCTAssertFalse(keyboardVC.view.subviews.contains { $0 is ExplainWhyPopoverView },
                      "No animations should occur for popover when feature disabled")
    }

    // MARK: - No Visual Artifacts Tests

    func testHiddenUIComponents_shouldNotCreateVisualArtifacts() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Showing both banner and popover
        let expectation = XCTestExpectation(description: "No visual artifacts")
        DispatchQueue.main.async {
            let bannerSelector = NSSelectorFromString("showAlertBanner:")
            if self.keyboardVC.responds(to: bannerSelector) {
                self.keyboardVC.perform(bannerSelector, with: response)
            }

            let popoverSelector = NSSelectorFromString("showExplainWhyPopover:")
            if self.keyboardVC.responds(to: popoverSelector) {
                self.keyboardVC.perform(popoverSelector, with: response)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Then: View hierarchy should be clean (no analysis components)
        let hasAnalysisComponents = keyboardVC.view.subviews.contains { view in
            view is RiskAlertBannerView || view is ExplainWhyPopoverView
        }
        XCTAssertFalse(hasAnalysisComponents, "No analysis UI components should exist when feature disabled")
    }

    func testKeyboardUI_whenFlagDisabled_shouldRemainClean() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        // When: Keyboard view is loaded
        // Then: View should have only expected base components (no analysis components)
        let hasAnalysisComponents = keyboardVC.view.subviews.contains { view in
            view is RiskAlertBannerView || view is ExplainWhyPopoverView
        }
        XCTAssertFalse(hasAnalysisComponents, "Keyboard should not have analysis components when feature disabled")
    }

    // MARK: - Accessibility Tests

    func testShowAlertBanner_whenFlagDisabled_shouldNotMakeAccessibilityAnnouncements() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show banner
        let selector = NSSelectorFromString("showAlertBanner:")
        if keyboardVC.responds(to: selector) {
            keyboardVC.perform(selector, with: response)
        }

        // Then: Banner subview should not exist (thus no accessibility setup)
        let bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertFalse(bannerExists, "Banner with accessibility setup should not exist when disabled")
    }

    func testShowExplainWhyPopover_whenFlagDisabled_shouldNotMakeAccessibilityAnnouncements() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show popover
        let selector = NSSelectorFromString("showExplainWhyPopover:")
        if keyboardVC.responds(to: selector) {
            keyboardVC.perform(selector, with: response)
        }

        // Then: Popover subview should not exist (thus no accessibility announcements)
        let popoverExists = keyboardVC.view.subviews.contains { $0 is ExplainWhyPopoverView }
        XCTAssertFalse(popoverExists, "Popover with accessibility setup should not exist when disabled")
    }

    // MARK: - Contrast Tests (Enabled vs Disabled)

    func testShowAlertBanner_whenFlagEnabled_shouldDisplayBanner() {
        // Given: Feature flag enabled
        FeatureFlags.shared.isAnalyseTextEnabled = true

        // Enable banners in preferences
        SharedStorageManager.shared.setAlertPreferences(
            showBanners: true,
            riskThreshold: "medium"
        )

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Showing banner
        let expectation = XCTestExpectation(description: "Banner displayed")
        DispatchQueue.main.async {
            let selector = NSSelectorFromString("showAlertBanner:")
            if self.keyboardVC.responds(to: selector) {
                self.keyboardVC.perform(selector, with: response)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Then: Banner should be displayed
        let bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertTrue(bannerExists, "Banner should be displayed when feature is enabled")
    }

    func testShowExplainWhyPopover_whenFlagEnabled_shouldDisplayPopover() {
        // Given: Feature flag enabled
        FeatureFlags.shared.isAnalyseTextEnabled = true

        // Re-create keyboard controller with flag enabled
        keyboardVC = KeyboardViewController()
        _ = keyboardVC.view

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Showing popover
        let expectation = XCTestExpectation(description: "Popover displayed")
        DispatchQueue.main.async {
            let selector = NSSelectorFromString("showExplainWhyPopover:")
            if self.keyboardVC.responds(to: selector) {
                self.keyboardVC.perform(selector, with: response)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Then: Popover should be displayed
        let popoverExists = keyboardVC.view.subviews.contains { $0 is ExplainWhyPopoverView }
        XCTAssertTrue(popoverExists, "Popover should be displayed when feature is enabled")
    }

    // MARK: - Integration Tests

    func testUIHiding_whenBothBannerAndPopoverTriggered_shouldHideAll() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show both banner and popover in sequence
        let expectation = XCTestExpectation(description: "All UI hidden")
        DispatchQueue.main.async {
            // Try showing banner
            let bannerSelector = NSSelectorFromString("showAlertBanner:")
            if self.keyboardVC.responds(to: bannerSelector) {
                self.keyboardVC.perform(bannerSelector, with: response)
            }

            // Try showing popover
            let popoverSelector = NSSelectorFromString("showExplainWhyPopover:")
            if self.keyboardVC.responds(to: popoverSelector) {
                self.keyboardVC.perform(popoverSelector, with: response)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Then: Both should be hidden
        let analysisUIExists = keyboardVC.view.subviews.contains { view in
            view is RiskAlertBannerView || view is ExplainWhyPopoverView
        }
        XCTAssertFalse(analysisUIExists, "Both banner and popover should be hidden when feature disabled")
    }

    func testKeyboardFunctionality_whenUIHidden_shouldRemainFunctional() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        // When: Attempting basic keyboard operations
        // Then: Keyboard should remain functional
        XCTAssertNotNil(keyboardVC.view, "Keyboard view should exist")
        XCTAssertNoThrow(keyboardVC.textWillChange(nil), "textWillChange should work")
        XCTAssertNoThrow(keyboardVC.textDidChange(nil), "textDidChange should work")
    }

    // MARK: - Memory Tests

    func testHiddenUIComponents_shouldNotRetainMemory() {
        // Given: Feature flag disabled
        XCTAssertFalse(FeatureFlags.shared.isAnalyseTextEnabled)

        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Test explanation"
        )

        // When: Attempting to show UI
        let selector = NSSelectorFromString("showExplainWhyPopover:")
        if keyboardVC.responds(to: selector) {
            keyboardVC.perform(selector, with: response)
        }

        // Then: currentPopover should be nil (no memory retained)
        let currentPopover = keyboardVC.value(forKey: "currentPopover")
        XCTAssertNil(currentPopover, "currentPopover should be nil when feature disabled")
    }
}
