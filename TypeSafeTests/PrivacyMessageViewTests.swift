//
//  PrivacyMessageViewTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 18/01/25.
//

import XCTest
@testable import TypeSafe

class PrivacyMessageViewTests: XCTestCase {
    
    var privacyMessageView: PrivacyMessageView!
    var settingsActionCalled = false
    var dismissActionCalled = false
    
    override func setUp() {
        super.setUp()
        settingsActionCalled = false
        dismissActionCalled = false
        
        privacyMessageView = PrivacyMessageView(
            settingsAction: { [weak self] in
                self?.settingsActionCalled = true
            },
            dismissAction: { [weak self] in
                self?.dismissActionCalled = true
            }
        )
    }
    
    override func tearDown() {
        privacyMessageView = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(privacyMessageView)
        XCTAssertFalse(privacyMessageView.translatesAutoresizingMaskIntoConstraints)
    }
    
    func testInitializationWithoutActions() {
        let viewWithoutActions = PrivacyMessageView()
        XCTAssertNotNil(viewWithoutActions)
    }
    
    // MARK: - UI Component Tests
    
    func testUIComponentsExist() {
        // Add to a container to trigger view setup
        let containerView = UIView()
        containerView.addSubview(privacyMessageView)
        
        // Force layout
        privacyMessageView.layoutIfNeeded()
        
        // Check that subviews exist
        XCTAssertGreaterThan(privacyMessageView.subviews.count, 0, "Privacy message should have subviews")
        
        // Check for container view
        let containerViews = privacyMessageView.subviews.filter { $0 is UIView && $0.subviews.count > 0 }
        XCTAssertGreaterThan(containerViews.count, 0, "Should have container view with subviews")
    }
    
    // MARK: - Action Tests
    
    func testSettingsButtonAction() {
        // Simulate settings button tap
        // Since we can't easily access the private button, we'll test the action callback
        let settingsView = PrivacyMessageView(settingsAction: { [weak self] in
            self?.settingsActionCalled = true
        })
        
        // Add to container and layout
        let container = UIView()
        container.addSubview(settingsView)
        settingsView.layoutIfNeeded()
        
        // Find and tap the settings button
        if let button = findButton(in: settingsView, withTitle: "Settings") {
            button.sendActions(for: .touchUpInside)
            XCTAssertTrue(settingsActionCalled, "Settings action should be called")
        } else {
            XCTFail("Settings button not found")
        }
    }
    
    func testDismissButtonAction() {
        // Add to container and layout
        let container = UIView()
        container.addSubview(privacyMessageView)
        privacyMessageView.layoutIfNeeded()
        
        // Find and tap the dismiss button
        if let button = findButton(in: privacyMessageView, withTitle: "✕") {
            button.sendActions(for: .touchUpInside)
            XCTAssertTrue(dismissActionCalled, "Dismiss action should be called")
        } else {
            XCTFail("Dismiss button not found")
        }
    }
    
    // MARK: - Appearance Tests
    
    func testLightModeAppearance() {
        let container = UIView()
        container.addSubview(privacyMessageView)
        privacyMessageView.layoutIfNeeded()
        
        // Test light mode
        privacyMessageView.updateAppearance(isDark: false)
        
        // Verify appearance was updated (we can't easily test exact colors, but we can test the method doesn't crash)
        XCTAssertNotNil(privacyMessageView.subviews.first)
    }
    
    func testDarkModeAppearance() {
        let container = UIView()
        container.addSubview(privacyMessageView)
        privacyMessageView.layoutIfNeeded()
        
        // Test dark mode
        privacyMessageView.updateAppearance(isDark: true)
        
        // Verify appearance was updated
        XCTAssertNotNil(privacyMessageView.subviews.first)
    }
    
    // MARK: - Helper Methods
    
    private func findButton(in view: UIView, withTitle title: String) -> UIButton? {
        if let button = view as? UIButton, button.title(for: .normal) == title {
            return button
        }
        
        for subview in view.subviews {
            if let button = findButton(in: subview, withTitle: title) {
                return button
            }
        }
        
        return nil
    }
    
    // MARK: - Performance Tests
    
    func testPrivacyMessagePerformance() {
        measure {
            let view = PrivacyMessageView()
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 60))
            container.addSubview(view)
            
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.heightAnchor.constraint(equalToConstant: 60)
            ])
            
            view.layoutIfNeeded()
            view.updateAppearance(isDark: false)
            view.updateAppearance(isDark: true)
        }
    }
}
