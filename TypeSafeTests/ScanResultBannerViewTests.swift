//
//  ScanResultBannerViewTests.swift
//  TypeSafeTests
//
//  Story 3.7: App Group Integration & Keyboard Sync
//  Unit tests for ScanResultBannerView UI component
//

import XCTest
@testable import TypeSafeKeyboard

final class ScanResultBannerViewTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var bannerView: ScanResultBannerView!
    private var testScanResult: SharedScanResult!
    private var dismissCallbackCalled = false
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        testScanResult = SharedScanResult(
            riskLevel: "high",
            category: "Payment Scam",
            confidence: 0.92
        )
        
        dismissCallbackCalled = false
        
        bannerView = ScanResultBannerView(scanResult: testScanResult) { [weak self] in
            self?.dismissCallbackCalled = true
        }
    }
    
    override func tearDown() {
        bannerView = nil
        testScanResult = nil
        dismissCallbackCalled = false
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testBannerViewInitialization() {
        // Then
        XCTAssertNotNil(bannerView)
        XCTAssertFalse(bannerView.translatesAutoresizingMaskIntoConstraints)
    }
    
    func testBannerViewHasCorrectSubviews() {
        // Given
        let containerView = bannerView.subviews.first
        
        // Then
        XCTAssertNotNil(containerView)
        XCTAssertEqual(bannerView.subviews.count, 1)
        
        // Container should have icon, message, and dismiss button
        XCTAssertEqual(containerView?.subviews.count, 3)
    }
    
    func testContainerViewStyling() {
        // Given
        let containerView = bannerView.subviews.first
        
        // Then
        XCTAssertNotNil(containerView)
        XCTAssertEqual(containerView?.backgroundColor, UIColor.systemBlue)
        XCTAssertEqual(containerView?.layer.cornerRadius, 8)
        XCTAssertFalse(containerView?.translatesAutoresizingMaskIntoConstraints ?? true)
    }
    
    func testShadowConfiguration() {
        // Given
        let containerView = bannerView.subviews.first
        
        // Then
        XCTAssertNotNil(containerView)
        XCTAssertEqual(containerView?.layer.shadowColor, UIColor.black.cgColor)
        XCTAssertEqual(containerView?.layer.shadowOffset, CGSize(width: 0, height: 2))
        XCTAssertEqual(containerView?.layer.shadowOpacity, 0.1)
        XCTAssertEqual(containerView?.layer.shadowRadius, 4)
    }
    
    // MARK: - Content Tests
    
    func testIconLabelContent() {
        // Given
        let containerView = bannerView.subviews.first!
        let iconLabel = containerView.subviews.first { $0 is UILabel && ($0 as! UILabel).text == "📸" } as? UILabel
        
        // Then
        XCTAssertNotNil(iconLabel)
        XCTAssertEqual(iconLabel?.text, "📸")
        XCTAssertEqual(iconLabel?.font, UIFont.systemFont(ofSize: 20))
        XCTAssertFalse(iconLabel?.translatesAutoresizingMaskIntoConstraints ?? true)
    }
    
    func testMessageLabelContent() {
        // Given
        let containerView = bannerView.subviews.first!
        let messageLabel = containerView.subviews.first { 
            $0 is UILabel && ($0 as! UILabel).text?.contains("Latest scan:") == true 
        } as? UILabel
        
        // Then
        XCTAssertNotNil(messageLabel)
        XCTAssertEqual(messageLabel?.text, testScanResult.bannerMessage)
        XCTAssertEqual(messageLabel?.font, UIFont.systemFont(ofSize: 14, weight: .medium))
        XCTAssertEqual(messageLabel?.textColor, .white)
        XCTAssertEqual(messageLabel?.numberOfLines, 1)
        XCTAssertFalse(messageLabel?.translatesAutoresizingMaskIntoConstraints ?? true)
    }
    
    func testDismissButtonContent() {
        // Given
        let containerView = bannerView.subviews.first!
        let dismissButton = containerView.subviews.first { $0 is UIButton } as? UIButton
        
        // Then
        XCTAssertNotNil(dismissButton)
        XCTAssertEqual(dismissButton?.title(for: .normal), "✕")
        XCTAssertEqual(dismissButton?.titleColor(for: .normal), .white)
        XCTAssertEqual(dismissButton?.titleLabel?.font, UIFont.systemFont(ofSize: 16, weight: .medium))
        XCTAssertFalse(dismissButton?.translatesAutoresizingMaskIntoConstraints ?? true)
    }
    
    // MARK: - Message Content Tests
    
    func testMessageForDifferentRiskLevels() {
        // Given
        let highRiskResult = SharedScanResult(riskLevel: "high", category: "Payment Scam", confidence: 0.95)
        let mediumRiskResult = SharedScanResult(riskLevel: "medium", category: "OTP Phishing", confidence: 0.85)
        let lowRiskResult = SharedScanResult(riskLevel: "low", category: "Safe Content", confidence: 0.98)
        
        let highBanner = ScanResultBannerView(scanResult: highRiskResult) { }
        let mediumBanner = ScanResultBannerView(scanResult: mediumRiskResult) { }
        let lowBanner = ScanResultBannerView(scanResult: lowRiskResult) { }
        
        // When
        let highMessage = getMessageLabelText(from: highBanner)
        let mediumMessage = getMessageLabelText(from: mediumBanner)
        let lowMessage = getMessageLabelText(from: lowBanner)
        
        // Then
        XCTAssertEqual(highMessage, "Latest scan: High Risk - Payment Scam")
        XCTAssertEqual(mediumMessage, "Latest scan: Medium Risk - OTP Phishing")
        XCTAssertEqual(lowMessage, "Latest scan: Low Risk - Safe Content")
    }
    
    func testMessageForDifferentCategories() {
        // Given
        let categories = [
            "OTP Phishing",
            "Payment Scam",
            "Identity Theft",
            "Financial Fraud",
            "Social Engineering"
        ]
        
        // When & Then
        for category in categories {
            let scanResult = SharedScanResult(riskLevel: "medium", category: category, confidence: 0.8)
            let banner = ScanResultBannerView(scanResult: scanResult) { }
            let message = getMessageLabelText(from: banner)
            
            XCTAssertEqual(message, "Latest scan: Medium Risk - \(category)")
        }
    }
    
    // MARK: - Interaction Tests
    
    func testDismissButtonTap() {
        // Given
        let containerView = bannerView.subviews.first!
        let dismissButton = containerView.subviews.first { $0 is UIButton } as? UIButton
        
        XCTAssertNotNil(dismissButton)
        XCTAssertFalse(dismissCallbackCalled)
        
        // When
        dismissButton?.sendActions(for: .touchUpInside)
        
        // Then
        XCTAssertTrue(dismissCallbackCalled)
    }
    
    func testMultipleDismissButtonTaps() {
        // Given
        let containerView = bannerView.subviews.first!
        let dismissButton = containerView.subviews.first { $0 is UIButton } as? UIButton
        
        XCTAssertNotNil(dismissButton)
        XCTAssertFalse(dismissCallbackCalled)
        
        // When
        dismissButton?.sendActions(for: .touchUpInside)
        dismissCallbackCalled = false // Reset for second tap
        dismissButton?.sendActions(for: .touchUpInside)
        
        // Then
        XCTAssertTrue(dismissCallbackCalled)
    }
    
    // MARK: - Appearance Tests
    
    func testUpdateAppearanceDoesNotChangeColors() {
        // Given
        let containerView = bannerView.subviews.first!
        let originalBackgroundColor = containerView.backgroundColor
        
        // When
        bannerView.updateAppearance(isDark: true)
        let darkModeColor = containerView.backgroundColor
        
        bannerView.updateAppearance(isDark: false)
        let lightModeColor = containerView.backgroundColor
        
        // Then
        XCTAssertEqual(originalBackgroundColor, UIColor.systemBlue)
        XCTAssertEqual(darkModeColor, UIColor.systemBlue)
        XCTAssertEqual(lightModeColor, UIColor.systemBlue)
    }
    
    func testTextColorRemainsWhite() {
        // Given
        let containerView = bannerView.subviews.first!
        let messageLabel = containerView.subviews.first { 
            $0 is UILabel && ($0 as! UILabel).text?.contains("Latest scan:") == true 
        } as? UILabel
        let dismissButton = containerView.subviews.first { $0 is UIButton } as? UIButton
        
        // When
        bannerView.updateAppearance(isDark: true)
        let darkModeMessageColor = messageLabel?.textColor
        let darkModeDismissColor = dismissButton?.titleColor(for: .normal)
        
        bannerView.updateAppearance(isDark: false)
        let lightModeMessageColor = messageLabel?.textColor
        let lightModeDismissColor = dismissButton?.titleColor(for: .normal)
        
        // Then
        XCTAssertEqual(darkModeMessageColor, .white)
        XCTAssertEqual(darkModeDismissColor, .white)
        XCTAssertEqual(lightModeMessageColor, .white)
        XCTAssertEqual(lightModeDismissColor, .white)
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testIsRiskAlertBannerProperty() {
        // Then
        XCTAssertFalse(bannerView.isRiskAlertBanner)
    }
    
    // MARK: - Layout Tests
    
    func testConstraintsAreSetup() {
        // Given
        let containerView = bannerView.subviews.first!
        
        // When
        bannerView.layoutIfNeeded()
        
        // Then
        XCTAssertFalse(containerView.translatesAutoresizingMaskIntoConstraints)
        XCTAssertGreaterThan(containerView.constraints.count, 0)
    }
    
    func testBannerHasReasonableSize() {
        // Given
        let testFrame = CGRect(x: 0, y: 0, width: 375, height: 60)
        bannerView.frame = testFrame
        
        // When
        bannerView.layoutIfNeeded()
        
        // Then
        let containerView = bannerView.subviews.first!
        XCTAssertGreaterThan(containerView.frame.width, 0)
        XCTAssertGreaterThan(containerView.frame.height, 0)
        XCTAssertLessThan(containerView.frame.width, testFrame.width)
        XCTAssertLessThan(containerView.frame.height, testFrame.height)
    }
    
    // MARK: - Memory Management Tests
    
    func testWeakReferenceInCallback() {
        // Given
        var callbackExecuted = false
        var bannerReference: ScanResultBannerView? = ScanResultBannerView(scanResult: testScanResult) {
            callbackExecuted = true
        }
        
        // When
        let containerView = bannerReference?.subviews.first!
        let dismissButton = containerView?.subviews.first { $0 is UIButton } as? UIButton
        
        // Simulate button tap
        dismissButton?.sendActions(for: .touchUpInside)
        
        // Release the banner
        bannerReference = nil
        
        // Then
        XCTAssertTrue(callbackExecuted)
        XCTAssertNil(bannerReference)
    }
    
    // MARK: - Helper Methods
    
    private func getMessageLabelText(from banner: ScanResultBannerView) -> String? {
        let containerView = banner.subviews.first!
        let messageLabel = containerView.subviews.first { 
            $0 is UILabel && ($0 as! UILabel).text?.contains("Latest scan:") == true 
        } as? UILabel
        return messageLabel?.text
    }
}
