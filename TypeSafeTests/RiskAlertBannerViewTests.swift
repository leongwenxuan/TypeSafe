//
//  RiskAlertBannerViewTests.swift
//  TypeSafeTests
//
//  Created by AI Agent on 18/01/25.
//  Story 2.4: Inline Risk Alert Banners - Unit Tests
//

import XCTest
@testable import TypeSafeKeyboard

class RiskAlertBannerViewTests: XCTestCase {
    
    // MARK: - Test Properties
    var dismissActionCalled = false
    var showPopoverActionCalled = false
    var mockResponse: AnalyzeTextResponse!
    
    override func setUp() {
        super.setUp()
        dismissActionCalled = false
        showPopoverActionCalled = false
        
        // Create mock response for testing
        mockResponse = AnalyzeTextResponse(
            risk_level: "medium",
            confidence: 0.85,
            category: "otp_phishing",
            explanation: "This message is asking for your one-time password.",
            ts: "2025-01-18T10:30:00Z"
        )
    }
    
    // MARK: - Initialization Tests
    
    func testBannerInitialization() {
        // Arrange & Act
        let banner = RiskAlertBannerView(
            riskLevel: .medium,
            response: mockResponse,
            dismissAction: { },
            showPopoverAction: { _ in }
        )
        
        // Assert
        XCTAssertNotNil(banner, "Banner should be initialized")
        XCTAssertEqual(banner.layer.cornerRadius, 8, "Banner should have rounded corners")
        XCTAssertEqual(banner.layer.borderWidth, 1, "Banner should have border")
        XCTAssertFalse(banner.translatesAutoresizingMaskIntoConstraints, "Banner should use Auto Layout")
    }
    
    // MARK: - Configuration Tests
    
    func testConfigureMediumRisk() {
        // Arrange
        let banner = RiskAlertBannerView(
            riskLevel: .medium,
            response: mockResponse,
            dismissAction: { },
            showPopoverAction: { _ in }
        )
        
        // Act - Configuration happens in init
        
        // Assert - Check amber/orange colors for medium risk
        XCTAssertEqual(banner.backgroundColor, UIColor.systemYellow.withAlphaComponent(0.15), 
                      "Medium risk should have yellow background with alpha")
        XCTAssertEqual(banner.layer.borderColor, UIColor.systemOrange.cgColor, 
                      "Medium risk should have orange border")
        
        // Check message label exists and has correct content
        let messageLabel = banner.subviews.compactMap { $0 as? UILabel }.first { $0.text?.contains("Possible Scam") ?? false }
        XCTAssertNotNil(messageLabel, "Message label should exist")
        XCTAssertEqual(messageLabel?.text, "Possible Scam - Be Cautious", "Medium risk should show cautious message")
        XCTAssertEqual(messageLabel?.textColor, UIColor.systemOrange, "Medium risk text should be orange")
    }
    
    func testConfigureHighRisk() {
        // Arrange
        let highRiskResponse = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "payment_scam",
            explanation: "This appears to be a payment scam.",
            ts: "2025-01-18T10:30:00Z"
        )
        let banner = RiskAlertBannerView(
            riskLevel: .high,
            response: highRiskResponse,
            dismissAction: { },
            showPopoverAction: { _ in }
        )
        
        // Act - Configuration happens in init
        
        // Assert - Check red colors for high risk
        XCTAssertEqual(banner.backgroundColor, UIColor.systemRed.withAlphaComponent(0.15), 
                      "High risk should have red background with alpha")
        XCTAssertEqual(banner.layer.borderColor, UIColor.systemRed.cgColor, 
                      "High risk should have red border")
        
        // Check message label exists and has correct content
        let messageLabel = banner.subviews.compactMap { $0 as? UILabel }.first { $0.text?.contains("Likely Scam") ?? false }
        XCTAssertNotNil(messageLabel, "Message label should exist")
        XCTAssertEqual(messageLabel?.text, "Likely Scam Detected - Stay Alert", "High risk should show alert message")
        XCTAssertEqual(messageLabel?.textColor, UIColor.systemRed, "High risk text should be red")
    }
    
    // MARK: - Dismiss Action Tests
    
    func testDismissButtonTriggersClosure() {
        // Arrange
        let expectation = XCTestExpectation(description: "Dismiss action called")
        let banner = RiskAlertBannerView(
            riskLevel: .medium,
            response: mockResponse,
            dismissAction: {
                expectation.fulfill()
            },
            showPopoverAction: { _ in }
        )
        
        // Act - Find and trigger dismiss button
        let dismissButton = banner.subviews.compactMap { $0 as? UIButton }.first
        XCTAssertNotNil(dismissButton, "Dismiss button should exist")
        dismissButton?.sendActions(for: .touchUpInside)
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Layout Tests
    
    func testBannerLayout() {
        // Arrange
        let banner = RiskAlertBannerView(
            riskLevel: .medium,
            response: mockResponse,
            dismissAction: { },
            showPopoverAction: { _ in }
        )
        
        // Act - Force layout
        banner.layoutIfNeeded()
        
        // Assert - Check that icon, message label, and dismiss button exist
        let iconLabel = banner.subviews.compactMap { $0 as? UILabel }.first { $0.text == "⚠️" }
        XCTAssertNotNil(iconLabel, "Icon label should exist with warning symbol")
        
        let messageLabel = banner.subviews.compactMap { $0 as? UILabel }.first { $0.text?.contains("Scam") ?? false }
        XCTAssertNotNil(messageLabel, "Message label should exist")
        XCTAssertEqual(messageLabel?.font.pointSize, 15, "Message should use 15pt font")
        
        let dismissButton = banner.subviews.compactMap { $0 as? UIButton }.first
        XCTAssertNotNil(dismissButton, "Dismiss button should exist")
        XCTAssertEqual(dismissButton?.title(for: .normal), "✕", "Dismiss button should show X symbol")
    }
    
    // MARK: - Visual Element Tests
    
    func testBannerHasWarningIcon() {
        // Arrange
        let banner = RiskAlertBannerView(
            riskLevel: .high,
            response: mockResponse,
            dismissAction: { },
            showPopoverAction: { _ in }
        )
        
        // Act
        let iconLabel = banner.subviews.compactMap { $0 as? UILabel }.first { $0.text == "⚠️" }
        
        // Assert
        XCTAssertNotNil(iconLabel, "Banner should have warning icon")
        XCTAssertEqual(iconLabel?.font.pointSize, 20, "Icon should use 20pt font")
    }
    
    // MARK: - Popover Integration Tests (Story 2.6)
    
    func testBannerTapShowsPopover() {
        // Arrange
        let expectation = XCTestExpectation(description: "Show popover action called")
        var receivedResponse: AnalyzeTextResponse?
        
        let banner = RiskAlertBannerView(
            riskLevel: .medium,
            response: mockResponse,
            dismissAction: { },
            showPopoverAction: { response in
                receivedResponse = response
                expectation.fulfill()
            }
        )
        
        // Add to a test view to enable proper gesture handling
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 60))
        testView.addSubview(banner)
        banner.frame = testView.bounds
        
        // Act - Simulate tap on banner (not on dismiss button)
        let tapGesture = banner.gestureRecognizers?.first as? UITapGestureRecognizer
        XCTAssertNotNil(tapGesture, "Banner should have tap gesture")
        
        // Simulate tap at center of banner (away from dismiss button)
        if let target = tapGesture?.target, let action = tapGesture?.action {
            _ = target.perform(action, with: tapGesture)
        }
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedResponse, "Should receive response data")
        XCTAssertEqual(receivedResponse?.category, mockResponse.category, "Should pass correct response")
    }
    
    func testDismissButtonStillWorks() {
        // Arrange
        let dismissExpectation = XCTestExpectation(description: "Dismiss action called")
        let popoverExpectation = XCTestExpectation(description: "Popover action should NOT be called")
        popoverExpectation.isInverted = true // We expect this NOT to be called
        
        let banner = RiskAlertBannerView(
            riskLevel: .medium,
            response: mockResponse,
            dismissAction: {
                dismissExpectation.fulfill()
            },
            showPopoverAction: { _ in
                popoverExpectation.fulfill()
            }
        )
        
        // Act - Find and trigger dismiss button specifically
        let dismissButton = banner.subviews.compactMap { $0 as? UIButton }.first
        XCTAssertNotNil(dismissButton, "Dismiss button should exist")
        dismissButton?.sendActions(for: .touchUpInside)
        
        // Assert
        wait(for: [dismissExpectation], timeout: 1.0)
        wait(for: [popoverExpectation], timeout: 0.5) // Short timeout for inverted expectation
    }
    
    func testTapGestureExcludesDismissButton() {
        // Arrange
        let popoverExpectation = XCTestExpectation(description: "Popover should NOT be called for dismiss button tap")
        popoverExpectation.isInverted = true
        
        let banner = RiskAlertBannerView(
            riskLevel: .medium,
            response: mockResponse,
            dismissAction: { },
            showPopoverAction: { _ in
                popoverExpectation.fulfill()
            }
        )
        
        // Add to test view and layout
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 60))
        testView.addSubview(banner)
        banner.frame = testView.bounds
        banner.layoutIfNeeded()
        
        // Act - Create a mock tap gesture at dismiss button location
        let tapGesture = UITapGestureRecognizer()
        let dismissButton = banner.subviews.compactMap { $0 as? UIButton }.first!
        
        // Mock the location to be within dismiss button frame
        class MockTapGesture: UITapGestureRecognizer {
            override func location(in view: UIView?) -> CGPoint {
                return CGPoint(x: 290, y: 30) // Should be in dismiss button area
            }
        }
        
        let mockTap = MockTapGesture()
        // Since bannerTapped is private, we'll test the gesture directly
        let realTapGesture = banner.gestureRecognizers?.first as? UITapGestureRecognizer
        if let target = realTapGesture?.target, let action = realTapGesture?.action {
            _ = target.perform(action, with: mockTap)
        }
        
        // Assert - Popover should NOT be called
        wait(for: [popoverExpectation], timeout: 0.5)
    }
}

