//
//  RiskAlertBannerView.swift
//  TypeSafeKeyboard
//
//  Created by AI Agent on 18/01/25.
//  Story 2.4: Inline Risk Alert Banners
//

import UIKit

/// Risk level enum for banner configuration
enum RiskLevel: String {
    case medium
    case high
}

/// Custom banner view that displays scam risk alerts above the keyboard
class RiskAlertBannerView: UIView {
    
    // MARK: - Properties
    private let riskLevel: RiskLevel
    private let response: AnalyzeTextResponse
    private let dismissAction: () -> Void
    private let showPopoverAction: (AnalyzeTextResponse) -> Void
    
    private let iconLabel = UILabel()
    private let messageLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    
    // MARK: - Initialization
    init(riskLevel: RiskLevel, response: AnalyzeTextResponse, dismissAction: @escaping () -> Void, showPopoverAction: @escaping (AnalyzeTextResponse) -> Void) {
        self.riskLevel = riskLevel
        self.response = response
        self.dismissAction = dismissAction
        self.showPopoverAction = showPopoverAction
        super.init(frame: .zero)
        setupUI()
        configure(for: riskLevel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Banner container setup
        self.layer.cornerRadius = 8
        self.layer.borderWidth = 1
        self.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon setup (warning symbol)
        iconLabel.text = "⚠️"
        iconLabel.font = UIFont.systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconLabel)
        
        // Message label setup
        messageLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        messageLabel.numberOfLines = 1
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.8
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)
        
        // Dismiss button setup
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        addSubview(dismissButton)
        
        // Add tap gesture for showing popover (excluding dismiss button area)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bannerTapped))
        self.addGestureRecognizer(tapGesture)
        
        // Auto Layout constraints
        NSLayoutConstraint.activate([
            // Icon constraints
            iconLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 24),
            
            // Message label constraints
            messageLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            messageLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            
            // Dismiss button constraints
            dismissButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12),
            dismissButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 30),
            dismissButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    // MARK: - Configuration
    /// Configures the banner appearance based on risk level
    /// - Parameter riskLevel: The risk level (medium or high)
    private func configure(for riskLevel: RiskLevel) {
        switch riskLevel {
        case .medium:
            // Amber theme for medium risk
            self.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.15)
            self.layer.borderColor = UIColor.systemOrange.cgColor
            messageLabel.textColor = UIColor.systemOrange
            dismissButton.tintColor = UIColor.systemOrange
            messageLabel.text = "Possible Scam - Be Cautious"
            
        case .high:
            // Red theme for high risk
            self.backgroundColor = UIColor.systemRed.withAlphaComponent(0.15)
            self.layer.borderColor = UIColor.systemRed.cgColor
            messageLabel.textColor = UIColor.systemRed
            dismissButton.tintColor = UIColor.systemRed
            messageLabel.text = "Likely Scam Detected - Stay Alert"
        }
    }
    
    // MARK: - Actions
    @objc private func dismissTapped() {
        dismissAction()
    }
    
    @objc private func bannerTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let dismissButtonFrame = dismissButton.frame
        
        // Check if tap is outside the dismiss button area
        if !dismissButtonFrame.contains(location) {
            showPopoverAction(response)
        }
    }
}

