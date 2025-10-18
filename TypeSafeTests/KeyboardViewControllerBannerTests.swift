//
//  KeyboardViewControllerBannerTests.swift
//  TypeSafeTests
//
//  Created by AI Agent on 18/01/25.
//  Story 2.4: Inline Risk Alert Banners - Integration Tests
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardViewControllerBannerTests: XCTestCase {
    
    // MARK: - Test Properties
    var keyboardVC: KeyboardViewController!
    
    override func setUp() {
        super.setUp()
        keyboardVC = KeyboardViewController()
        // Load view to trigger viewDidLoad
        _ = keyboardVC.view
    }
    
    override func tearDown() {
        keyboardVC = nil
        super.tearDown()
    }
    
    // MARK: - Banner Display Tests
    
    func testShowBannerForMediumRisk() {
        // Arrange
        let mediumRiskResponse = AnalyzeTextResponse(
            risk_level: "medium",
            confidence: 0.75,
            category: "suspicious_request",
            explanation: "Request for personal information detected"
        )
        
        // Act
        let expectation = XCTestExpectation(description: "Banner displayed")
        DispatchQueue.main.async {
            // Simulate API response
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: mediumRiskResponse)
            
            // Give animation time to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Assert - Check banner was added to view hierarchy
        let bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertTrue(bannerExists, "Medium risk banner should be displayed")
    }
    
    func testShowBannerForHighRisk() {
        // Arrange
        let highRiskResponse = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "otp_phishing",
            explanation: "Asking for OTP code detected"
        )
        
        // Act
        let expectation = XCTestExpectation(description: "Banner displayed")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: highRiskResponse)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Assert
        let bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertTrue(bannerExists, "High risk banner should be displayed")
    }
    
    func testNoBannerForLowRisk() {
        // Arrange
        let lowRiskResponse = AnalyzeTextResponse(
            risk_level: "low",
            confidence: 0.95,
            category: "legitimate",
            explanation: "Normal conversation detected"
        )
        
        // Act
        let expectation = XCTestExpectation(description: "No banner displayed")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: lowRiskResponse)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Assert
        let bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertFalse(bannerExists, "Low risk should not display banner")
    }
    
    func testReplaceBannerWhenNewArrives() {
        // Arrange - Show first banner
        let firstResponse = AnalyzeTextResponse(
            risk_level: "medium",
            confidence: 0.75,
            category: "suspicious",
            explanation: "First alert"
        )
        
        let expectation1 = XCTestExpectation(description: "First banner displayed")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: firstResponse)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation1.fulfill()
            }
        }
        wait(for: [expectation1], timeout: 2.0)
        
        // Act - Show second banner
        let secondResponse = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.90,
            category: "phishing",
            explanation: "Second alert"
        )
        
        let expectation2 = XCTestExpectation(description: "Second banner replaces first")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: secondResponse)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation2.fulfill()
            }
        }
        wait(for: [expectation2], timeout: 2.0)
        
        // Assert - Only one banner should exist
        let bannerCount = keyboardVC.view.subviews.filter { $0 is RiskAlertBannerView }.count
        XCTAssertEqual(bannerCount, 1, "Only one banner should be visible at a time")
    }
    
    // MARK: - Auto-Dismiss Tests
    
    func testAutoDismissAfter10Seconds() {
        // Arrange
        let response = AnalyzeTextResponse(
            risk_level: "medium",
            confidence: 0.75,
            category: "suspicious",
            explanation: "Test alert"
        )
        
        // Act - Show banner
        let showExpectation = XCTestExpectation(description: "Banner displayed")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: response)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showExpectation.fulfill()
            }
        }
        wait(for: [showExpectation], timeout: 2.0)
        
        // Verify banner is shown
        var bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertTrue(bannerExists, "Banner should be displayed initially")
        
        // Wait for auto-dismiss (10 seconds + animation buffer)
        let dismissExpectation = XCTestExpectation(description: "Banner auto-dismissed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) {
            dismissExpectation.fulfill()
        }
        wait(for: [dismissExpectation], timeout: 12.0)
        
        // Assert - Banner should be gone
        bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertFalse(bannerExists, "Banner should auto-dismiss after 10 seconds")
    }
    
    func testManualDismiss() {
        // Arrange
        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.90,
            category: "phishing",
            explanation: "Test alert"
        )
        
        // Show banner
        let showExpectation = XCTestExpectation(description: "Banner displayed")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: response)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showExpectation.fulfill()
            }
        }
        wait(for: [showExpectation], timeout: 2.0)
        
        // Verify banner exists
        var bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertTrue(bannerExists, "Banner should be displayed")
        
        // Act - Manual dismiss
        let dismissExpectation = XCTestExpectation(description: "Banner manually dismissed")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("dismissBanner:")), with: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismissExpectation.fulfill()
            }
        }
        wait(for: [dismissExpectation], timeout: 2.0)
        
        // Assert
        bannerExists = keyboardVC.view.subviews.contains { $0 is RiskAlertBannerView }
        XCTAssertFalse(bannerExists, "Banner should be dismissed")
    }
    
    // MARK: - Typing Interaction Tests
    
    func testBannerDoesNotBlockTyping() {
        // Arrange - Show banner
        let response = AnalyzeTextResponse(
            risk_level: "medium",
            confidence: 0.75,
            category: "suspicious",
            explanation: "Test alert"
        )
        
        let expectation = XCTestExpectation(description: "Banner displayed")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: response)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Act - Verify textDocumentProxy is still accessible
        let proxy = keyboardVC.textDocumentProxy
        
        // Assert - Proxy should still be functional
        XCTAssertNotNil(proxy, "Text document proxy should remain accessible with banner visible")
        // Note: We can't actually insert text in unit tests without a real text field,
        // but we can verify the proxy exists and is accessible
    }
    
    // MARK: - Haptic Feedback Tests
    
    func testHapticFeedbackMediumRisk() {
        // Note: Haptic feedback cannot be easily unit tested as it requires hardware
        // This test verifies the method exists and doesn't crash
        
        // Arrange
        let response = AnalyzeTextResponse(
            risk_level: "medium",
            confidence: 0.75,
            category: "suspicious",
            explanation: "Test alert"
        )
        
        // Act & Assert - Should not crash
        let expectation = XCTestExpectation(description: "Haptic triggered without crash")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: response)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        // If we reach here, haptic didn't crash the app
    }
    
    func testHapticFeedbackHighRisk() {
        // Note: Haptic feedback cannot be easily unit tested as it requires hardware
        // This test verifies the method exists and doesn't crash
        
        // Arrange
        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "phishing",
            explanation: "Test alert"
        )
        
        // Act & Assert - Should not crash
        let expectation = XCTestExpectation(description: "Haptic triggered without crash")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: response)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        // If we reach here, haptic didn't crash the app
    }
    
    func testNoHapticWithoutFullAccess() {
        // Note: hasFullAccess is a system property we can't easily mock
        // This test verifies the haptic feedback method handles missing Full Access gracefully
        
        // Arrange
        let response = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "phishing",
            explanation: "Test alert"
        )
        
        // Act & Assert - Should not crash even if Full Access is not granted
        let expectation = XCTestExpectation(description: "Banner shown without crashing despite no Full Access")
        DispatchQueue.main.async {
            self.keyboardVC.perform(Selector(("showAlertBanner:")), with: response)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        // If we reach here, the app handled missing Full Access gracefully
    }
}

