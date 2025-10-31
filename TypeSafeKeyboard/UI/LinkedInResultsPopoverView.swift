//
//  LinkedInResultsPopoverView.swift
//  TypeSafeKeyboard
//
//  Created by AI Agent on Story 9.3
//  LinkedIn search results popover display
//

import UIKit

/// Custom popover view that displays LinkedIn search results
class LinkedInResultsPopoverView: UIView {
    
    // MARK: - Properties
    private let results: [KeyboardAPIService.LinkedInProfile]
    private let onCopyURL: ((String) -> Void)?
    private let dismissAction: () -> Void
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let closeButton = UIButton(type: .system)
    
    private var isExpanded = false
    private let maxVisibleResults = 3
    
    // MARK: - Initialization
    init(results: [KeyboardAPIService.LinkedInProfile], onCopyURL: ((String) -> Void)?, dismissAction: @escaping () -> Void) {
        self.results = results
        self.onCopyURL = onCopyURL
        self.dismissAction = dismissAction
        super.init(frame: .zero)
        setupUI()
        configureContent()
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
        
        // Title label setup
        titleLabel.text = "🔍 LinkedIn Search Results"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // ScrollView setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        containerView.addSubview(scrollView)
        
        // Content stack view setup
        contentStackView.axis = .vertical
        contentStackView.spacing = 12
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)
        
        // Close button setup
        closeButton.setTitle("Close", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        closeButton.setTitleColor(UIColor.systemBlue, for: .normal)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        containerView.addSubview(closeButton)
        
        // Auto Layout constraints
        NSLayoutConstraint.activate([
            // Container view constraints (centered with max width/height)
            containerView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            containerView.heightAnchor.constraint(lessThanOrEqualToConstant: 400),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -20),
            
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // ScrollView constraints
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -12),
            
            // Content stack view constraints
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Close button constraints
            closeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Content Configuration
    private func configureContent() {
        
        // Determine how many results to show initially
        let resultsToShow = min(results.count, maxVisibleResults)
        
        // Add profile cards for visible results
        for (index, profile) in results.prefix(resultsToShow).enumerated() {
            let profileCard = createProfileCard(profile: profile, index: index)
            contentStackView.addArrangedSubview(profileCard)
            
            // Add separator (except for last visible card)
            if index < resultsToShow - 1 || results.count > maxVisibleResults {
                let separator = createSeparator()
                contentStackView.addArrangedSubview(separator)
            }
        }
        
        // Add "View More" button if there are additional results
        if results.count > maxVisibleResults {
            let viewMoreButton = createViewMoreButton(hiddenCount: results.count - maxVisibleResults)
            contentStackView.addArrangedSubview(viewMoreButton)
        }
        
    }
    
    private func createProfileCard(profile: KeyboardAPIService.LinkedInProfile, index: Int) -> UIView {
        let cardView = UIView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.systemBackground
        
        
        // Name label (bold, 16pt)
        let nameLabel = UILabel()
        nameLabel.text = profile.name
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = UIColor.label
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(nameLabel)
        
        // Title + Company label (14pt, secondary color)
        let titleCompanyLabel = UILabel()
        titleCompanyLabel.text = "\(profile.title) @ \(profile.company)"
        titleCompanyLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleCompanyLabel.textColor = UIColor.secondaryLabel
        titleCompanyLabel.numberOfLines = 1
        titleCompanyLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleCompanyLabel)
        
        // Snippet label (12pt, 2 lines max)
        let snippetLabel = UILabel()
        snippetLabel.text = profile.snippet
        snippetLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        snippetLabel.textColor = UIColor.secondaryLabel
        snippetLabel.numberOfLines = 2
        snippetLabel.lineBreakMode = .byTruncatingTail
        snippetLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(snippetLabel)
        
        // Insert URL button
        let copyButton = UIButton(type: .system)
        copyButton.setTitle("✓ Insert LinkedIn URL", for: .normal)
        copyButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        copyButton.setTitleColor(UIColor.systemBlue, for: .normal)
        copyButton.tag = index
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.addTarget(self, action: #selector(copyURLTapped(_:)), for: .touchUpInside)
        cardView.addSubview(copyButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            
            titleCompanyLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            titleCompanyLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            titleCompanyLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            
            snippetLabel.topAnchor.constraint(equalTo: titleCompanyLabel.bottomAnchor, constant: 4),
            snippetLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            snippetLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            
            copyButton.topAnchor.constraint(equalTo: snippetLabel.bottomAnchor, constant: 12),
            copyButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            copyButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            copyButton.heightAnchor.constraint(equalToConstant: 32),
            copyButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8)
        ])
        
        return cardView
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = UIColor.separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }
    
    private func createViewMoreButton(hiddenCount: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("View \(hiddenCount) more result\(hiddenCount > 1 ? "s" : "")", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(viewMoreTapped), for: .touchUpInside)
        return button
    }
    
    // MARK: - Actions
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let containerFrame = containerView.frame
        
        // Only dismiss if tap is outside container
        if !containerFrame.contains(location) {
            dismissAction()
        }
    }
    
    @objc private func closeTapped() {
        dismissAction()
    }
    
    @objc private func copyURLTapped(_ sender: UIButton) {
        let profileIndex = sender.tag
        guard profileIndex < results.count else { return }
        
        let profile = results[profileIndex]
        UIPasteboard.general.string = profile.profileUrl
        
        // Trigger callback
        onCopyURL?(profile.profileUrl)
    }
    
    @objc private func viewMoreTapped() {
        // Remove all current cards
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add all results
        for (index, profile) in results.enumerated() {
            let profileCard = createProfileCard(profile: profile, index: index)
            contentStackView.addArrangedSubview(profileCard)
            
            // Add separator (except for last card)
            if index < results.count - 1 {
                let separator = createSeparator()
                contentStackView.addArrangedSubview(separator)
            }
        }
        
        isExpanded = true
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

