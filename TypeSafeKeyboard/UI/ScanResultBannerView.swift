//
//  ScanResultBannerView.swift
//  TypeSafeKeyboard
//
//  Story 3.7: App Group Integration & Keyboard Sync
//  Banner view for displaying scan results from companion app
//

import UIKit

/// Banner view for displaying scan results from companion app in keyboard
class ScanResultBannerView: UIView {
    
    // MARK: - Properties
    
    /// The scan result to display
    private let scanResult: SharedScanResult
    
    /// Callback for dismiss action
    private let dismissAction: () -> Void
    
    // UI Components
    private let containerView = UIView()
    private let iconLabel = UILabel()
    private let messageLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    
    // MARK: - Initialization
    
    /// Initializes the scan result banner
    /// - Parameters:
    ///   - scanResult: The SharedScanResult to display
    ///   - dismissAction: Callback for when user dismisses the banner
    init(scanResult: SharedScanResult, dismissAction: @escaping () -> Void) {
        self.scanResult = scanResult
        self.dismissAction = dismissAction
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // Setup container with blue background (TypeSafe branding)
        containerView.backgroundColor = UIColor.systemBlue
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Setup camera icon
        iconLabel.text = "📸"
        iconLabel.font = UIFont.systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconLabel)
        
        // Setup message label
        messageLabel.text = scanResult.bannerMessage
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 1
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(messageLabel)
        
        // Setup dismiss button
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(dismissButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Container fills the banner with padding
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            // Icon on the left
            iconLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Message in the center
            messageLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            messageLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: dismissButton.leadingAnchor, constant: -8),
            
            // Dismiss button on the right
            dismissButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            dismissButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 24),
            dismissButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Add subtle shadow for depth
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 4
        
    }
    
    // MARK: - Actions
    
    @objc private func dismissTapped() {
        dismissAction()
    }
    
    // MARK: - Appearance Updates
    
    /// Updates the banner appearance for light/dark mode
    /// - Parameter isDark: Whether dark mode is active
    func updateAppearance(isDark: Bool) {
        // Scan result banners always use blue background for consistency
        // Text is always white for good contrast against blue
        // No appearance changes needed for scan result banners
    }
}

// MARK: - RiskAlertBannerView Protocol Conformance

/// Make ScanResultBannerView compatible with existing banner management
extension ScanResultBannerView {
    
    /// Provides compatibility with existing banner dismissal logic
    var isRiskAlertBanner: Bool {
        return false // This is a scan result banner, not a risk alert banner
    }
}
