//
//  PrivacyMessageView.swift
//  TypeSafeKeyboard
//
//  Created by Dev Agent on 18/01/25.
//

import UIKit

/// Privacy message view displayed when Full Access is disabled
/// Provides clear explanation of permissions needed and privacy practices
class PrivacyMessageView: UIView {
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let settingsButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    
    // MARK: - Properties
    private let settingsAction: (() -> Void)?
    private let dismissAction: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize privacy message view
    /// - Parameters:
    ///   - settingsAction: Callback when settings button is tapped
    ///   - dismissAction: Callback when dismiss button is tapped
    init(settingsAction: (() -> Void)? = nil, dismissAction: (() -> Void)? = nil) {
        self.settingsAction = settingsAction
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
        
        // Setup container with rounded corners and background
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        addSubview(containerView)
        
        // Setup icon (shield with checkmark for privacy/security)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(systemName: "shield.checkered")
        iconImageView.tintColor = UIColor.systemBlue
        iconImageView.contentMode = .scaleAspectFit
        containerView.addSubview(iconImageView)
        
        // Setup title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Enable Full Access"
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 1
        containerView.addSubview(titleLabel)
        
        // Setup message label
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "TypeSafe only analyzes text for scam detection, not stored"
        messageLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        messageLabel.textColor = UIColor.secondaryLabel
        messageLabel.numberOfLines = 2
        messageLabel.lineBreakMode = .byWordWrapping
        containerView.addSubview(messageLabel)
        
        // Setup settings button
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.setTitle("Settings", for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        settingsButton.setTitleColor(UIColor.systemBlue, for: .normal)
        settingsButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        settingsButton.layer.cornerRadius = 4
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        containerView.addSubview(settingsButton)
        
        // Setup dismiss button
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        dismissButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        containerView.addSubview(dismissButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container fills the view with padding
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            // Icon positioning
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Title label positioning
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            
            // Message label positioning
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // Settings button positioning
            settingsButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            settingsButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            settingsButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6),
            settingsButton.widthAnchor.constraint(equalToConstant: 60),
            settingsButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Dismiss button positioning
            dismissButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            dismissButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            dismissButton.widthAnchor.constraint(equalToConstant: 20),
            dismissButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func settingsButtonTapped() {
        print("PrivacyMessageView: Settings button tapped")
        settingsAction?()
    }
    
    @objc private func dismissButtonTapped() {
        print("PrivacyMessageView: Dismiss button tapped")
        dismissAction?()
    }
    
    // MARK: - Public Methods
    
    /// Updates the appearance based on keyboard theme
    /// - Parameter isDark: Whether the keyboard is in dark mode
    func updateAppearance(isDark: Bool) {
        if isDark {
            containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            containerView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.4).cgColor
            titleLabel.textColor = UIColor.white
            messageLabel.textColor = UIColor.lightGray
            settingsButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        } else {
            containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            containerView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
            titleLabel.textColor = UIColor.label
            messageLabel.textColor = UIColor.secondaryLabel
            settingsButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        }
    }
}
