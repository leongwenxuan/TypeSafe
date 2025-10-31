//
//  ScreenshotAlertBannerView.swift
//  TypeSafeKeyboard
//
//  Story 4.2: Screenshot Alert Prompt in Keyboard
//  Banner view for screenshot scan prompts
//

import UIKit

/// Banner view that prompts users to scan their screenshots for scams
/// Displays above the keyboard with "Scan Now" and dismiss actions
class ScreenshotAlertBannerView: UIView {
    
    // MARK: - Properties
    
    private let notification: ScreenshotNotification
    private let scanAction: () -> Void
    private let dismissAction: () -> Void
    
    private let iconLabel = UILabel()
    private let messageLabel = UILabel()
    private let scanButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    
    // Story 5.3: Button debouncing
    private var isScanButtonDisabled = false
    
    // MARK: - Initialization
    
    /// Creates a new screenshot alert banner
    /// - Parameters:
    ///   - notification: The screenshot notification to display
    ///   - scanAction: Action to perform when "Scan Now" is tapped
    ///   - dismissAction: Action to perform when dismiss is tapped
    init(
        notification: ScreenshotNotification,
        scanAction: @escaping () -> Void,
        dismissAction: @escaping () -> Void
    ) {
        self.notification = notification
        self.scanAction = scanAction
        self.dismissAction = dismissAction
        super.init(frame: .zero)
        setupUI()
        configureAppearance()
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
        
        // Icon setup (camera emoji)
        iconLabel.text = "📸"
        iconLabel.font = UIFont.systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconLabel)
        
        // Message label setup
        messageLabel.text = "Screenshot taken - Scan for scams?"
        messageLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        messageLabel.numberOfLines = 1
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.8
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)
        
        // Scan Now button setup
        scanButton.setTitle("Scan Now", for: .normal)
        scanButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        scanButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        scanButton.layer.cornerRadius = 4
        addSubview(scanButton)
        
        // Dismiss button setup
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        addSubview(dismissButton)
        
        // Auto Layout constraints
        NSLayoutConstraint.activate([
            // Icon constraints
            iconLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 24),
            
            // Message label constraints
            messageLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            messageLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: scanButton.leadingAnchor, constant: -8),
            
            // Scan button constraints
            scanButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            scanButton.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            scanButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Dismiss button constraints
            dismissButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12),
            dismissButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 30),
            dismissButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    // MARK: - Configuration
    
    /// Configures the banner appearance with blue theme
    private func configureAppearance() {
        // Blue theme for screenshot notifications (matches TypeSafe branding)
        self.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        self.layer.borderColor = UIColor.systemBlue.cgColor
        messageLabel.textColor = UIColor.systemBlue
        
        // Scan button styling
        scanButton.backgroundColor = UIColor.systemBlue
        scanButton.setTitleColor(.white, for: .normal)
        
        // Dismiss button styling
        dismissButton.tintColor = UIColor.systemBlue
    }
    
    /// Updates appearance for dark/light mode
    func updateAppearance() {
        // Reconfigure colors based on current trait collection
        configureAppearance()
    }
    
    // MARK: - Actions
    
    @objc private func scanButtonTapped() {
        // Story 5.3: Debounce rapid taps
        guard !isScanButtonDisabled else {
            return
        }
        
        
        // Disable button temporarily
        isScanButtonDisabled = true
        scanButton.isEnabled = false
        scanButton.alpha = 0.5
        
        // Execute scan action
        scanAction()
        
        // Re-enable after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isScanButtonDisabled = false
            self?.scanButton.isEnabled = true
            self?.scanButton.alpha = 1.0
        }
    }
    
    @objc private func dismissButtonTapped() {
        dismissAction()
    }
}

// MARK: - Animation Support

extension ScreenshotAlertBannerView {
    
    /// Animates the banner sliding down from top
    /// - Parameter completion: Completion handler called when animation finishes
    func animateIn(completion: (() -> Void)? = nil) {
        // Start with banner positioned above visible area
        self.transform = CGAffineTransform(translationX: 0, y: -self.bounds.height)
        self.alpha = 0
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                self.transform = .identity
                self.alpha = 1
            },
            completion: { _ in
                completion?()
            }
        )
    }
    
    /// Animates the banner sliding up out of view
    /// - Parameter completion: Completion handler called when animation finishes
    func animateOut(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                self.transform = CGAffineTransform(translationX: 0, y: -self.bounds.height)
                self.alpha = 0
            },
            completion: { _ in
                completion?()
            }
        )
    }
}

// MARK: - Accessibility

extension ScreenshotAlertBannerView {
    
    /// Configures accessibility for VoiceOver support
    func configureAccessibility() {
        self.isAccessibilityElement = false
        
        // Make individual elements accessible
        iconLabel.isAccessibilityElement = false
        
        messageLabel.isAccessibilityElement = true
        messageLabel.accessibilityLabel = "Screenshot taken. Do you want to scan it for scams?"
        
        scanButton.isAccessibilityElement = true
        scanButton.accessibilityLabel = "Scan Now"
        scanButton.accessibilityHint = "Opens the TypeSafe app to scan your screenshot"
        
        dismissButton.isAccessibilityElement = true
        dismissButton.accessibilityLabel = "Dismiss"
        dismissButton.accessibilityHint = "Closes this notification"
        
        // Set accessibility order
        self.accessibilityElements = [messageLabel, scanButton, dismissButton]
    }
}

