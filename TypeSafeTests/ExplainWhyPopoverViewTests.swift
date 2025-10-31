//
//  ExplainWhyPopoverViewTests.swift
//  TypeSafeTests
//
//  Created by AI Agent on 18/01/25.
//  Story 2.6: "Explain Why" Popover Detail - Unit Tests
//

import XCTest
@testable import TypeSafeKeyboard

class ExplainWhyPopoverViewTests: XCTestCase {
    
    // MARK: - Test Properties
    var popoverView: ExplainWhyPopoverView!
    var mockResponse: AnalyzeTextResponse!
    var dismissCalled: Bool = false
    
    override func setUp() {
        super.setUp()
        dismissCalled = false
        
        // Create mock response for testing
        mockResponse = AnalyzeTextResponse(
            risk_level: "medium",
            confidence: 0.85,
            category: "otp_phishing",
            explanation: "This message is asking for your one-time password, which is a common phishing tactic.",
            ts: "2025-01-18T10:30:00Z"
        )
        
        // Create popover with mock dismiss action
        popoverView = ExplainWhyPopoverView(response: mockResponse) { [weak self] in
            self?.dismissCalled = true
        }
    }
    
    override func tearDown() {
        popoverView = nil
        mockResponse = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testPopoverInitialization() {
        // Test that popover initializes correctly with response data
        XCTAssertNotNil(popoverView)
        XCTAssertFalse(dismissCalled)
        
        // Test that the view is properly configured
        XCTAssertEqual(popoverView.backgroundColor, UIColor.black.withAlphaComponent(0.4))
        XCTAssertFalse(popoverView.translatesAutoresizingMaskIntoConstraints)
    }
    
    func testPopoverInitializationWithHighRisk() {
        // Test initialization with high risk response
        let highRiskResponse = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "payment_scam",
            explanation: "This appears to be a payment scam attempting to steal your financial information.",
            ts: "2025-01-18T10:30:00Z"
        )
        
        let highRiskPopover = ExplainWhyPopoverView(response: highRiskResponse) { }
        
        XCTAssertNotNil(highRiskPopover)
        XCTAssertEqual(highRiskPopover.backgroundColor, UIColor.black.withAlphaComponent(0.4))
    }
    
    // MARK: - Risk Level Color Coding Tests
    
    func testRiskLevelColorCoding() {
        // Add popover to a test view to trigger layout
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        popoverView.show(in: testView)
        
        // Force layout to ensure subviews are configured
        testView.layoutIfNeeded()
        
        // Find the risk level label (it should be configured for medium risk)
        let containerView = popoverView.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        XCTAssertNotNil(containerView)
        
        let riskLevelLabel = containerView?.subviews.compactMap { $0 as? UILabel }.first
        XCTAssertNotNil(riskLevelLabel)
        XCTAssertEqual(riskLevelLabel?.text, "Medium Risk")
        XCTAssertEqual(riskLevelLabel?.textColor, UIColor.systemOrange)
    }
    
    func testHighRiskColorCoding() {
        // Test high risk color coding
        let highRiskResponse = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.95,
            category: "payment_scam",
            explanation: "High risk payment scam detected.",
            ts: "2025-01-18T10:30:00Z"
        )
        
        let highRiskPopover = ExplainWhyPopoverView(response: highRiskResponse) { }
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        highRiskPopover.show(in: testView)
        testView.layoutIfNeeded()
        
        let containerView = highRiskPopover.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        let riskLevelLabel = containerView?.subviews.compactMap { $0 as? UILabel }.first
        
        XCTAssertEqual(riskLevelLabel?.text, "High Risk")
        XCTAssertEqual(riskLevelLabel?.textColor, UIColor.systemRed)
    }
    
    // MARK: - Category Formatting Tests
    
    func testCategoryFormatting() {
        // Test that snake_case categories are properly formatted to Title Case
        let testCases: [(input: String, expected: String)] = [
            ("otp_phishing", "OTP Phishing"),
            ("payment_scam", "Payment Scam"),
            ("impersonation", "Impersonation"),
            ("unknown", "Suspicious Content"),
            ("custom_category", "Custom Category")
        ]
        
        for testCase in testCases {
            let response = AnalyzeTextResponse(
                risk_level: "medium",
                confidence: 0.8,
                category: testCase.input,
                explanation: "Test explanation",
                ts: nil
            )
            
            let popover = ExplainWhyPopoverView(response: response) { }
            let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
            popover.show(in: testView)
            testView.layoutIfNeeded()
            
            let containerView = popover.subviews.first { $0.backgroundColor == UIColor.systemBackground }
            let categoryLabel = containerView?.subviews.compactMap { $0 as? UILabel }[1] // Second label should be category
            
            XCTAssertEqual(categoryLabel?.text, testCase.expected, "Category '\(testCase.input)' should format to '\(testCase.expected)'")
        }
    }
    
    // MARK: - Explanation Display Tests
    
    func testExplanationDisplay() {
        // Test that explanation text is displayed correctly with multi-line support
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        popoverView.show(in: testView)
        testView.layoutIfNeeded()
        
        let containerView = popoverView.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        let explanationLabel = containerView?.subviews.compactMap { $0 as? UILabel }[2] // Third label should be explanation
        
        XCTAssertNotNil(explanationLabel)
        XCTAssertEqual(explanationLabel?.text, mockResponse.explanation)
        XCTAssertEqual(explanationLabel?.numberOfLines, 0) // Should support multi-line
        XCTAssertEqual(explanationLabel?.textAlignment, .center)
    }
    
    func testLongExplanationHandling() {
        // Test handling of very long explanation text
        let longExplanation = "This is a very long explanation that should wrap across multiple lines to test the multi-line support of the explanation label in the popover view component."
        
        let longResponse = AnalyzeTextResponse(
            risk_level: "high",
            confidence: 0.9,
            category: "payment_scam",
            explanation: longExplanation,
            ts: nil
        )
        
        let longPopover = ExplainWhyPopoverView(response: longResponse) { }
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 280, height: 300))
        longPopover.show(in: testView)
        testView.layoutIfNeeded()
        
        let containerView = longPopover.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        let explanationLabel = containerView?.subviews.compactMap { $0 as? UILabel }[2]
        
        XCTAssertEqual(explanationLabel?.text, longExplanation)
        XCTAssertEqual(explanationLabel?.numberOfLines, 0)
    }
    
    // MARK: - Got It Button Tests
    
    func testGotItButtonAction() {
        // Test that "Got It" button triggers dismiss callback
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        popoverView.show(in: testView)
        testView.layoutIfNeeded()
        
        let containerView = popoverView.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        let gotItButton = containerView?.subviews.compactMap { $0 as? UIButton }.first
        
        XCTAssertNotNil(gotItButton)
        XCTAssertEqual(gotItButton?.title(for: .normal), "Got It")
        XCTAssertFalse(dismissCalled)
        
        // Simulate button tap
        gotItButton?.sendActions(for: .touchUpInside)
        
        XCTAssertTrue(dismissCalled)
    }
    
    func testBackgroundTapDismiss() {
        // Test that tapping the background dismisses the popover
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        popoverView.show(in: testView)
        testView.layoutIfNeeded()
        
        XCTAssertFalse(dismissCalled)
        
        // Simulate background tap by directly calling the gesture target
        let tapGesture = popoverView.gestureRecognizers?.first as? UITapGestureRecognizer
        XCTAssertNotNil(tapGesture)
        
        // Trigger the gesture action
        if let target = tapGesture?.target, let action = tapGesture?.action {
            _ = target.perform(action, with: tapGesture)
        }
        
        XCTAssertTrue(dismissCalled)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() {
        // Test that VoiceOver labels are properly configured
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        popoverView.show(in: testView)
        testView.layoutIfNeeded()
        
        let containerView = popoverView.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        XCTAssertNotNil(containerView)
        
        let labels = containerView?.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels?.count, 3)
        
        // Test risk level label accessibility
        let riskLevelLabel = labels?[0]
        XCTAssertTrue(riskLevelLabel?.isAccessibilityElement ?? false)
        XCTAssertEqual(riskLevelLabel?.accessibilityTraits, .header)
        XCTAssertEqual(riskLevelLabel?.accessibilityLabel, "Risk Level: Medium Risk")
        
        // Test category label accessibility
        let categoryLabel = labels?[1]
        XCTAssertTrue(categoryLabel?.isAccessibilityElement ?? false)
        XCTAssertEqual(categoryLabel?.accessibilityLabel, "Scam Category: OTP Phishing")
        
        // Test explanation label accessibility
        let explanationLabel = labels?[2]
        XCTAssertTrue(explanationLabel?.isAccessibilityElement ?? false)
        XCTAssertEqual(explanationLabel?.accessibilityLabel, "Explanation: \(mockResponse.explanation)")
    }
    
    func testButtonAccessibility() {
        // Test button accessibility configuration
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        popoverView.show(in: testView)
        testView.layoutIfNeeded()
        
        let containerView = popoverView.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        let gotItButton = containerView?.subviews.compactMap { $0 as? UIButton }.first
        
        XCTAssertNotNil(gotItButton)
        XCTAssertTrue(gotItButton?.isAccessibilityElement ?? false)
        XCTAssertEqual(gotItButton?.accessibilityLabel, "Got It")
        XCTAssertEqual(gotItButton?.accessibilityHint, "Dismisses the explanation popover")
        XCTAssertEqual(gotItButton?.accessibilityTraits, .button)
    }
    
    func testModalAccessibility() {
        // Test that popover is configured as modal for VoiceOver
        XCTAssertTrue(popoverView.accessibilityViewIsModal)
    }
    
    // MARK: - Animation Tests
    
    func testShowAnimation() {
        // Test that show animation is properly configured
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        
        // Initial state should not be in view hierarchy
        XCTAssertNil(popoverView.superview)
        
        popoverView.show(in: testView)
        
        // Should be added to view hierarchy
        XCTAssertEqual(popoverView.superview, testView)
        
        // Should have proper constraints
        XCTAssertFalse(popoverView.constraints.isEmpty)
    }
    
    func testDismissAnimation() {
        // Test dismiss animation
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        popoverView.show(in: testView)
        
        XCTAssertEqual(popoverView.superview, testView)
        
        popoverView.dismiss()
        
        // Note: In unit tests, animations complete immediately
        // The view should still be in hierarchy during animation
        XCTAssertNotNil(popoverView.superview)
    }
    
    // MARK: - Edge Case Tests
    
    func testUnknownRiskLevel() {
        // Test handling of unknown risk level
        let unknownResponse = AnalyzeTextResponse(
            risk_level: "unknown",
            confidence: 0.5,
            category: "unknown",
            explanation: "Unknown risk detected",
            ts: nil
        )
        
        let unknownPopover = ExplainWhyPopoverView(response: unknownResponse) { }
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        unknownPopover.show(in: testView)
        testView.layoutIfNeeded()
        
        let containerView = unknownPopover.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        let riskLevelLabel = containerView?.subviews.compactMap { $0 as? UILabel }.first
        
        XCTAssertEqual(riskLevelLabel?.text, "Risk Detected")
        XCTAssertEqual(riskLevelLabel?.textColor, UIColor.systemYellow)
    }
    
    func testEmptyExplanation() {
        // Test handling of empty explanation
        let emptyResponse = AnalyzeTextResponse(
            risk_level: "medium",
            confidence: 0.8,
            category: "otp_phishing",
            explanation: "",
            ts: nil
        )
        
        let emptyPopover = ExplainWhyPopoverView(response: emptyResponse) { }
        let testView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        emptyPopover.show(in: testView)
        testView.layoutIfNeeded()
        
        let containerView = emptyPopover.subviews.first { $0.backgroundColor == UIColor.systemBackground }
        let explanationLabel = containerView?.subviews.compactMap { $0 as? UILabel }[2]
        
        XCTAssertEqual(explanationLabel?.text, "")
    }
}
