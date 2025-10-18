//
//  ExplainWhyPopoverView.swift
//  TypeSafeKeyboard
//
//  Created by AI Agent on 18/01/25.
//  Story 2.6: "Explain Why" Popover Detail
//

import UIKit

/// Custom popover view that displays detailed explanation for scam risk alerts
class ExplainWhyPopoverView: UIView {
    
    // MARK: - Properties
    private let response: AnalyzeTextResponse
    private let dismissAction: () -> Void
    
    private let containerView = UIView()
    private let riskLevelLabel = UILabel()
    private let categoryLabel = UILabel()
    private let explanationLabel = UILabel()
    private let gotItButton = UIButton(type: .system)
    
    // MARK: - Initialization
    init(response: AnalyzeTextResponse, dismissAction: @escaping () -> Void) {
        self.response = response
        self.dismissAction = dismissAction
        super.init(frame: .zero)
        setupUI()
        configureContent()
        setupAccessibility()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Main view setup (semi-transparent overlay)
        self.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        self.translatesAutoresizingMaskIntoConstraints = false
        
        // Add tap gesture for dismiss on outside tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        self.addGestureRecognizer(tapGesture)
        
        // Container view setup (the actual popover card)
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.2
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Prevent tap gesture on container from dismissing
        let containerTapGesture = UITapGestureRecognizer()
        containerView.addGestureRecognizer(containerTapGesture)
        
        // Risk level label setup
        riskLevelLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        riskLevelLabel.textAlignment = .center
        riskLevelLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(riskLevelLabel)
        
        // Category label setup
        categoryLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        categoryLabel.textAlignment = .center
        categoryLabel.textColor = UIColor.label
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(categoryLabel)
        
        // Explanation label setup
        explanationLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        explanationLabel.textAlignment = .center
        explanationLabel.textColor = UIColor.secondaryLabel
        explanationLabel.numberOfLines = 0
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(explanationLabel)
        
        // Got It button setup
        gotItButton.setTitle("Got It", for: .normal)
        gotItButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        gotItButton.backgroundColor = UIColor.systemBlue
        gotItButton.setTitleColor(UIColor.white, for: .normal)
        gotItButton.layer.cornerRadius = 8
        gotItButton.translatesAutoresizingMaskIntoConstraints = false
        gotItButton.addTarget(self, action: #selector(gotItTapped), for: .touchUpInside)
        containerView.addSubview(gotItButton)
        
        // Auto Layout constraints
        NSLayoutConstraint.activate([
            // Container view constraints (centered with max width)
            containerView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -20),
            
            // Risk level label constraints
            riskLevelLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            riskLevelLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            riskLevelLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Category label constraints
            categoryLabel.topAnchor.constraint(equalTo: riskLevelLabel.bottomAnchor, constant: 8),
            categoryLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            categoryLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Explanation label constraints
            explanationLabel.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 12),
            explanationLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            explanationLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Got It button constraints
            gotItButton.topAnchor.constraint(equalTo: explanationLabel.bottomAnchor, constant: 20),
            gotItButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            gotItButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            gotItButton.heightAnchor.constraint(equalToConstant: 44),
            gotItButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Content Configuration
    private func configureContent() {
        // Configure risk level with color coding
        let riskText: String
        let riskColor: UIColor
        
        switch response.risk_level.lowercased() {
        case "medium":
            riskText = "Medium Risk"
            riskColor = UIColor.systemOrange
        case "high":
            riskText = "High Risk"
            riskColor = UIColor.systemRed
        default:
            riskText = "Risk Detected"
            riskColor = UIColor.systemYellow
        }
        
        riskLevelLabel.text = riskText
        riskLevelLabel.textColor = riskColor
        
        // Configure category with proper formatting (snake_case → Title Case)
        categoryLabel.text = formatCategory(response.category)
        
        // Configure explanation
        explanationLabel.text = response.explanation
    }
    
    /// Formats category from snake_case to Title Case
    /// - Parameter category: The category string (e.g., "otp_phishing")
    /// - Returns: Formatted string (e.g., "OTP Phishing")
    private func formatCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "otp_phishing":
            return "OTP Phishing"
        case "payment_scam":
            return "Payment Scam"
        case "impersonation":
            return "Impersonation"
        case "unknown":
            return "Suspicious Content"
        default:
            // Fallback: capitalize each word and replace underscores
            return category.replacingOccurrences(of: "_", with: " ")
                          .capitalized
        }
    }
    
    // MARK: - Accessibility Setup
    private func setupAccessibility() {
        // Make the container view accessible
        containerView.isAccessibilityElement = false
        containerView.accessibilityElements = [riskLevelLabel, categoryLabel, explanationLabel, gotItButton]
        
        // Risk level accessibility
        riskLevelLabel.isAccessibilityElement = true
        riskLevelLabel.accessibilityTraits = .header
        riskLevelLabel.accessibilityLabel = "Risk Level: \(riskLevelLabel.text ?? "")"
        
        // Category accessibility
        categoryLabel.isAccessibilityElement = true
        categoryLabel.accessibilityLabel = "Scam Category: \(categoryLabel.text ?? "")"
        
        // Explanation accessibility
        explanationLabel.isAccessibilityElement = true
        explanationLabel.accessibilityLabel = "Explanation: \(explanationLabel.text ?? "")"
        
        // Button accessibility
        gotItButton.isAccessibilityElement = true
        gotItButton.accessibilityLabel = "Got It"
        gotItButton.accessibilityHint = "Dismisses the explanation popover"
        gotItButton.accessibilityTraits = .button
        
        // Main view accessibility
        self.accessibilityViewIsModal = true
    }
    
    // MARK: - Actions
    @objc private func backgroundTapped() {
        dismissAction()
    }
    
    @objc private func gotItTapped() {
        dismissAction()
    }
    
    // MARK: - Animation Support
    func show(in parentView: UIView) {
        parentView.addSubview(self)
        
        // Fill parent view
        NSLayoutConstraint.activate([
            self.topAnchor.constraint(equalTo: parentView.topAnchor),
            self.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            self.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            self.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])
        
        // Initial state for animation
        self.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
        
        // Set focus for VoiceOver
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .screenChanged, argument: self.riskLevelLabel)
        }
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
