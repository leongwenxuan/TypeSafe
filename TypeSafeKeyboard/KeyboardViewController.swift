//
//  KeyboardViewController.swift
//  TypeSafeKeyboard
//
//  Created by Daniel on 18/10/25.
//

import UIKit
import Photos

// MARK: - Keyboard Layout Enum
enum KeyboardLayout {
    case letters
    case numbers
    case symbols
}

class KeyboardViewController: UIInputViewController {
    
    // MARK: - Properties
    private var keyboardView: UIView!
    private var isShifted = false
    private var currentLayout: KeyboardLayout = .letters
    private var heightConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    private struct LayoutConfig {
        let rowHeight: CGFloat
        let bottomRowHeight: CGFloat
        let interRowSpacing: CGFloat
        let interKeySpacing: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let keyCornerRadius: CGFloat
        let homeRowSideInset: CGFloat
        let labelFont: UIFont

        static func resolve(for traits: UITraitCollection) -> LayoutConfig {
            if let metrics = KeyboardLayoutMetrics.enabledValues(for: traits) {
                let bottomRowHeight = max(metrics.rowHeight - metrics.bottomRowHeightDelta, 32)
                let horizontalPadding = max(metrics.outerHorizontalPadding - 4, 4)
                let verticalPadding = max(metrics.interRowSpacing * 0.35, 4)
                let homeRowInset = max(horizontalPadding + (metrics.interKeySpacing * 0.5), metrics.interKeySpacing)
                return LayoutConfig(
                    rowHeight: metrics.rowHeight,
                    bottomRowHeight: bottomRowHeight,
                    interRowSpacing: metrics.interRowSpacing,
                    interKeySpacing: metrics.interKeySpacing,
                    horizontalPadding: horizontalPadding,
                    verticalPadding: verticalPadding,
                    keyCornerRadius: metrics.keyCornerRadius,
                    homeRowSideInset: homeRowInset,
                    labelFont: metrics.labelFont
                )
            }

            let isCompact = traits.horizontalSizeClass == .compact
            let interKeySpacing: CGFloat = isCompact ? 8 : 10
            let horizontalPadding: CGFloat = isCompact ? 6 : 9
            let verticalPadding: CGFloat = isCompact ? 6 : 8
            let homeRowInset: CGFloat = horizontalPadding + (interKeySpacing * 0.5)

            return LayoutConfig(
                rowHeight: 46,
                bottomRowHeight: 38,
                interRowSpacing: isCompact ? 12 : 14,
                interKeySpacing: interKeySpacing,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                keyCornerRadius: 6,
                homeRowSideInset: homeRowInset,
                labelFont: UIFont.systemFont(ofSize: isCompact ? 20 : 22, weight: .regular)
            )
        }
    }

    private var layoutConfig: LayoutConfig {
        LayoutConfig.resolve(for: traitCollection)
    }

    private func desiredKeyboardHeight() -> CGFloat {
        let config = layoutConfig
        let rowsHeight = (config.rowHeight * 3) + config.bottomRowHeight
        let spacingTotal = config.interRowSpacing * 3
        let paddingTotal = config.verticalPadding * 2
        let reservedTopArea: CGFloat = 40
        return rowsHeight + spacingTotal + paddingTotal + reservedTopArea
    }

    private func isModifierKeyTitle(_ title: String) -> Bool {
        modifierKeyTitles.contains(title)
    }

    private func applyLetterCaseToCurrentLayout() {
        guard currentLayout == .letters, let keyboardView = keyboardView else { return }
        for subview in keyboardView.subviews {
            updateLetterKeyLabels(in: subview, uppercase: isShifted)
        }
    }

    private func updateLetterKeyLabels(in view: UIView, uppercase: Bool) {
        if let button = view as? KeyboardKeyButton {
            guard let title = button.title(for: .normal), title.count == 1 else { return }
            let lowercased = title.lowercased()
            guard lowercased.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil else { return }
            let newTitle = uppercase ? lowercased.uppercased() : lowercased
            if newTitle != title {
                button.setTitle(newTitle, for: .normal)
            }
            return
        }

        if let stackView = view as? UIStackView {
            for arrangedSubview in stackView.arrangedSubviews {
                updateLetterKeyLabels(in: arrangedSubview, uppercase: uppercase)
            }
        } else {
            for subview in view.subviews {
                updateLetterKeyLabels(in: subview, uppercase: uppercase)
            }
        }
    }
    
    // MARK: - Color Constants (Story 6.1)
    // Light mode colors - Apple-like neutral scheme
    private let lightKeyBackground = UIColor(white: 0.97, alpha: 1.0)  // #F8F8F8
    private let lightKeyboardBackground = UIColor(white: 0.85, alpha: 1.0)  // #D9D9D9
    private let lightModifierKeyBackground = UIColor(white: 0.90, alpha: 1.0)
    private let lightTextColor = UIColor.black
    private let modifierKeyTitles: Set<String> = ["⇧", "⌫", "123", "#+=", "ABC", "🌐", "space", "return"]
    
    // Dark mode colors - Apple-like neutral scheme
    private let darkKeyBackground = UIColor(white: 0.29, alpha: 1.0)  // #4A4A4A
    private let darkKeyboardBackground = UIColor(white: 0.10, alpha: 1.0)  // #191919
    private let darkModifierKeyBackground = UIColor(white: 0.33, alpha: 1.0)
    private let darkTextColor = UIColor.white
    
    // Performance optimization caches (Story 2.9)
    private var cachedShiftButton: UIButton?
    private var cachedKeyboardAppearance: UIKeyboardAppearance?
    private var layoutCache: [KeyboardLayout: UIView] = [:]
    
    // Snippet management (Story 2.2)
    private let snippetManager = TextSnippetManager()
    private let secureDetector = SecureTextDetector()
    private let snippetProcessingQueue = DispatchQueue(label: "com.typesafe.keyboard.snippets", qos: .userInteractive)
    private let isAnalysisFeatureEnabled = false  // Feature temporarily disabled but retained for future use
    
    // Backspace repeat handling
    private let backspaceInitialRepeatDelay: TimeInterval = 0.35
    private let backspaceRepeatInterval: TimeInterval = 0.08
    private var backspaceInitialDelayTimer: Timer?
    private var backspaceRepeatTimer: Timer?
    
    // Backend API integration (Story 2.3)
    private let apiService = APIService()
    
    // Banner management (Story 2.4)
    private var currentBanner: UIView?
    private var autoDismissTimer: Timer?
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    
    // Popover management (Story 2.6)
    private var currentPopover: ExplainWhyPopoverView?
    private var topToolbar: UIView?
    
    // Shared state management (Story 2.7)
    private let sharedStorageManager = SharedStorageManager.shared
    
    // Privacy message management (Story 2.8)
    private var privacyMessageView: PrivacyMessageView?
    
    // Scan result polling (Story 3.7)
    private var scanResultPollingTimer: Timer?
    private var lastProcessedScanId: String?
    
    // Screenshot notification polling (Story 4.2)
    private var screenshotNotificationService: ScreenshotNotificationService?
    
    // Direct screenshot detection in keyboard (Story 5.3 - Workaround)
    private var screenshotDetectionService: ScreenshotDetectionService?
    
    // Direct API service for keyboard (Story 5.4 - Full Independence)
    private let keyboardAPIService = KeyboardAPIService()
    
    // WebSocket manager for agent progress
    private var webSocketManager: KeyboardWebSocketManager?
    
    // MARK: - Lifecycle
    
    deinit {
        webSocketManager?.disconnect()
        webSocketManager = nil
    }
    
    // MARK: - Full Access Detection (Story 2.8)
    private var _cachedFullAccessStatus: Bool?
    private var hasFullAccessPermission: Bool {
        // Cache the result to avoid repeated checks
        if let cached = _cachedFullAccessStatus {
            return cached
        }
        
        // Test network capability - Full Access required for network calls
        let hasAccess = self.hasFullAccess
        _cachedFullAccessStatus = hasAccess
        
        return hasAccess
    }
    
    /// Invalidates the cached Full Access status (call when permissions might have changed)
    private func invalidateFullAccessCache() {
        _cachedFullAccessStatus = nil
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ensure Auto Layout drives sizing of the input view
        view.translatesAutoresizingMaskIntoConstraints = false
        
        
        // Invalidate Full Access cache on fresh load (Story 2.8)
        invalidateFullAccessCache()
        
        setupKeyboard()
        
        // Initialize haptic feedback generator if Full Access enabled (Story 2.4)
        if hasFullAccessPermission {
            feedbackGenerator = UIImpactFeedbackGenerator()
            feedbackGenerator?.prepare()
        }
        
        // Start scan result polling (Story 3.7)
        if isAnalysisFeatureEnabled {
            startScanResultPolling()
        }
        
        // Initialize and start screenshot notification polling (Story 4.2)
        setupScreenshotNotificationPolling()
        
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.setNeedsUpdateConstraints()
    }

    override func updateViewConstraints() {
        // Set a desired total keyboard height; host may clamp smaller on some devices
        let targetHeight = desiredKeyboardHeight()
        if heightConstraint == nil {
            heightConstraint = view.heightAnchor.constraint(equalToConstant: targetHeight)
            heightConstraint?.priority = .required
            heightConstraint?.isActive = true
        } else {
            heightConstraint?.constant = targetHeight
            heightConstraint?.priority = .required
        }

        if leadingConstraint == nil, let container = view.superview {
            leadingConstraint = view.leadingAnchor.constraint(equalTo: container.leadingAnchor)
            leadingConstraint?.priority = .required
            leadingConstraint?.isActive = true
        }

        if trailingConstraint == nil, let container = view.superview {
            trailingConstraint = view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            trailingConstraint?.priority = .required
            trailingConstraint?.isActive = true
        }

        super.updateViewConstraints()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelBackspaceRepeat()
        // Clean up banner and timer when keyboard is dismissed (Story 2.4)
        dismissBanner(animated: false)
        
        // Stop scan result polling (Story 3.7)
        stopScanResultPolling()
        
        // Stop screenshot notification polling (Story 4.2)
        screenshotNotificationService?.stopPolling()
        
        // Stop direct screenshot detection (Story 5.3)
        screenshotDetectionService?.stopPolling()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Performance optimization: Clear caches on memory warning (Story 2.9)
        clearPerformanceCaches()
        
        
        // Immediately clean up WebSocket to free memory
        webSocketManager?.disconnect()
        webSocketManager = nil
        
        // Dismiss any banners
        dismissBanner(animated: false)
        
        
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Update UI based on keyboard appearance (light/dark mode)
        updateAppearance()
        
        // Clear snippet buffer on field change (Story 2.2)
        snippetProcessingQueue.async { [weak self] in
            self?.snippetManager.clear()
        }
        
        
        // Story 2.8: Invalidate secure field detection cache on field change
        secureDetector.invalidateCache()
        
        // Dismiss banner on field change to prevent context leakage (Story 2.4)
        dismissBanner(animated: true)
    }
    
    // MARK: - Setup
    private func setupKeyboard() {
        // Performance optimization: Clear caches when recreating keyboard (Story 2.9)
        // Story 6.1: Clear layout cache to force rebuild with correct colors and padding
        clearPerformanceCaches()

        if keyboardView == nil {
            let container = UIView()
            container.backgroundColor = .clear
            container.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(container)

            NSLayoutConstraint.activate([
                container.leftAnchor.constraint(equalTo: view.leftAnchor),
                container.rightAnchor.constraint(equalTo: view.rightAnchor),
                container.topAnchor.constraint(equalTo: view.topAnchor, constant: 40), // reserve 40pt for banner/toolbar
                container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            keyboardView = container
        } else {
            keyboardView.subviews.forEach { $0.removeFromSuperview() }
        }

        // Add top toolbar with action buttons
        setupTopToolbar()

        // Story 2.8: Show privacy message if Full Access is disabled
        setupPrivacyMessage()

        UIView.performWithoutAnimation {
            self.createKeyboardLayout()
            self.keyboardView.layoutIfNeeded()
        }
        updateAppearance()
        if currentLayout == .letters {
            updateShiftState()
        }
        view.setNeedsUpdateConstraints()
    }
    
    /// Setup top toolbar with Settings and Scan Now buttons
    private func setupTopToolbar() {
        if let toolbar = topToolbar {
            view.bringSubviewToFront(toolbar)
            return
        }

        let toolbar = UIView()
        toolbar.backgroundColor = .clear
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        // Settings button (right)
        let settingsButton = UIButton(type: .system)
        settingsButton.setTitle("⚙️", for: .normal)
        settingsButton.titleLabel?.font = .systemFont(ofSize: 18)
        settingsButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.2)
        settingsButton.layer.cornerRadius = 6
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

        toolbar.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            // Toolbar at top
            toolbar.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 32),

            // Settings button on right
            settingsButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -8),
            settingsButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 36),
            settingsButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        topToolbar = toolbar
    }
    
    // scanNowTapped and showScanInstructionBanner removed as unused
    
    @objc private func settingsTapped() {
        
        // Haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator.impactOccurred()
        
        // Open companion app (TypeSafe URL scheme)
        if let url = URL(string: "typesafe://settings") {
            var responder: UIResponder? = self
            while let r = responder {
                if let application = r as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    return
                }
                responder = r.next
            }
        }
        
        
    }
    
    // handleScreenshotScanManually removed as unused
    
    private func createKeyboardLayout() {
        
        // Clean up existing keyboard layout views first
        keyboardView.subviews.forEach { $0.removeFromSuperview() }
        
        // Performance optimization: Use cached layout if available (Story 2.9)
        if let cachedLayout = layoutCache[currentLayout] {
            
            // Remove cached layout from its superview if it has one
            cachedLayout.removeFromSuperview()
            
            // Add cached layout
            keyboardView.addSubview(cachedLayout)
            
            // Reset any existing constraints on the cached layout
            cachedLayout.translatesAutoresizingMaskIntoConstraints = false
            
            // Setup constraints for cached layout
            NSLayoutConstraint.activate([
                cachedLayout.leftAnchor.constraint(equalTo: keyboardView.leftAnchor),
                cachedLayout.rightAnchor.constraint(equalTo: keyboardView.rightAnchor),
                cachedLayout.topAnchor.constraint(equalTo: keyboardView.topAnchor),
                cachedLayout.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor)
            ])
            
            // Force immediate layout to prevent alignment issues
            cachedLayout.layoutIfNeeded()
            
            // Update appearance for cached layout
            updateAppearanceForLayout(cachedLayout)

            if currentLayout == .letters {
                cachedShiftButton = nil
                updateShiftState()
            }
            return
        }
        
        // Create new layout and cache it
        let newLayout: UIView
        switch currentLayout {
        case .letters:
            newLayout = createLetterLayoutOptimized()
        case .numbers:
            newLayout = createNumberLayoutOptimized()
        case .symbols:
            newLayout = createSymbolLayoutOptimized()
        }
        
        // Cache the new layout for future use
        layoutCache[currentLayout] = newLayout
        if currentLayout == .letters {
            cachedShiftButton = nil
            updateShiftState()
        }
        
    }
    
    private func createLetterLayout() {
        let config = layoutConfig
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = config.interRowSpacing  // Story 6.2: Increased from 3pt to 4pt
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor, constant: config.horizontalPadding),
            mainStackView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor, constant: -config.horizontalPadding),
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: config.verticalPadding),
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -config.verticalPadding)
        ])
        
        // Row 1: Q W E R T Y U I O P
        let row1 = createKeyRow(keys: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
        row1.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: A S D F G H J K L (home row with extra side inset)
        let row2 = createKeyRow(
            keys: ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            horizontalInset: config.homeRowSideInset
        )
        row2.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true
        mainStackView.addArrangedSubview(row2)
        
        // Row 3: Shift + Z X C V B N M + Backspace
        let row3 = createRow3()
        row3.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: 123 + Next Keyboard + Space + Return
        let row4 = createRow4()
        row4.heightAnchor.constraint(equalToConstant: config.bottomRowHeight).isActive = true  // Story 6.2: Increased from 32pt to 38pt
        mainStackView.addArrangedSubview(row4)
        
        
    }
    
    private func createNumberLayout() {
        let config = layoutConfig
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = config.interRowSpacing  // Story 6.2: Increased from 3pt to 4pt
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor, constant: config.horizontalPadding),
            mainStackView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor, constant: -config.horizontalPadding),
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: config.verticalPadding),
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -config.verticalPadding)
        ])
        
        // Row 1: 1 2 3 4 5 6 7 8 9 0
        let row1 = createKeyRow(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        row1.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: - / : ; ( ) $ & @ "
        let row2 = createKeyRow(keys: ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""])
        row2.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        mainStackView.addArrangedSubview(row2)
        
        // Row 3: #+= button + . , ? ! ' + Backspace
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = config.interKeySpacing
        row3.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        
        let symbolModeButton = createKeyButton(title: "#+=", action: #selector(symbolModeTapped))
        symbolModeButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(symbolModeButton)
        
        let punctuationKeys = createKeyRow(keys: [".", ",", "?", "!", "'"])
        row3.addArrangedSubview(punctuationKeys)
        
        let backspaceButton = createKeyButton(title: "⌫", action: #selector(backspaceTapped))
        configureBackspaceButton(backspaceButton)
        backspaceButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(backspaceButton)
        
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: ABC + Globe + Space + Return
        let row4 = UIStackView()
        row4.axis = .horizontal
        row4.spacing = config.interKeySpacing
        row4.heightAnchor.constraint(equalToConstant: config.bottomRowHeight).isActive = true  // Story 6.2: Increased from 32pt to 38pt
        
        let abcButton = createKeyButton(title: "ABC", action: #selector(letterModeTapped))
        abcButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if let label = abcButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(abcButton)
        
        let nextKeyboardButton = createKeyButton(title: "🌐", action: #selector(handleInputModeList(from:with:)))
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if let label = nextKeyboardButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        if !needsInputModeSwitchKey {
            nextKeyboardButton.isHidden = true
        }
        row4.addArrangedSubview(nextKeyboardButton)
        
        let spaceButton = createKeyButton(title: "space", action: #selector(spaceTapped))
        if let label = spaceButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(spaceButton)
        
        let returnButton = createKeyButton(title: "return", action: #selector(returnTapped))
        returnButton.widthAnchor.constraint(equalToConstant: 67).isActive = true
        if let label = returnButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(returnButton)
        
        mainStackView.addArrangedSubview(row4)
        
        
    }
    
    private func createSymbolLayout() {
        let config = layoutConfig
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = config.interRowSpacing  // Story 6.2: Increased from 3pt to 4pt
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor, constant: config.horizontalPadding),
            mainStackView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor, constant: -config.horizontalPadding),
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: config.verticalPadding),
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -config.verticalPadding)
        ])
        
        // Row 1: [ ] { } # % ^ * + =
        let row1 = createKeyRow(keys: ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
        row1.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: _ \ | ~ < > $ £ ¥ •
        let row2 = createKeyRow(keys: ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"])
        row2.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        mainStackView.addArrangedSubview(row2)
        
        // Row 3: 123 button + . , ? ! ' + Backspace
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = config.interKeySpacing
        row3.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        
        let numberModeButton = createKeyButton(title: "123", action: #selector(numberModeTapped))
        numberModeButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(numberModeButton)
        
        let punctuationKeys = createKeyRow(keys: [".", ",", "?", "!", "'"])
        row3.addArrangedSubview(punctuationKeys)
        
        let backspaceButton = createKeyButton(title: "⌫", action: #selector(backspaceTapped))
        configureBackspaceButton(backspaceButton)
        backspaceButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(backspaceButton)
        
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: ABC + Globe + Space + Return
        let row4 = UIStackView()
        row4.axis = .horizontal
        row4.spacing = config.interKeySpacing
        row4.heightAnchor.constraint(equalToConstant: config.bottomRowHeight).isActive = true  // Story 6.2: Increased from 32pt to 38pt
        
        let abcButton = createKeyButton(title: "ABC", action: #selector(letterModeTapped))
        abcButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if let label = abcButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(abcButton)
        
        let nextKeyboardButton = createKeyButton(title: "🌐", action: #selector(handleInputModeList(from:with:)))
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if let label = nextKeyboardButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        if !needsInputModeSwitchKey {
            nextKeyboardButton.isHidden = true
        }
        row4.addArrangedSubview(nextKeyboardButton)
        
        let spaceButton = createKeyButton(title: "space", action: #selector(spaceTapped))
        if let label = spaceButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(spaceButton)
        
        let returnButton = createKeyButton(title: "return", action: #selector(returnTapped))
        returnButton.widthAnchor.constraint(equalToConstant: 67).isActive = true
        if let label = returnButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(returnButton)
        
        mainStackView.addArrangedSubview(row4)
        
        
    }
    
    private func createKeyRow(keys: [String], horizontalInset: CGFloat = 0) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        let config = layoutConfig
        stackView.spacing = config.interKeySpacing
        if horizontalInset > 0 {
            stackView.isLayoutMarginsRelativeArrangement = true
            stackView.layoutMargins = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
        }

        for key in keys {
            let button = createKeyButton(title: key, action: #selector(keyTapped(_:)))
            stackView.addArrangedSubview(button)
        }
        
        return stackView
    }
    
    private func createRow3() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        let config = layoutConfig
        stackView.spacing = config.interKeySpacing

        // Shift button
        let shiftButton = createKeyButton(title: "⇧", action: #selector(shiftTapped))
        stackView.addArrangedSubview(shiftButton)
        
        // Letter keys
        let letterKeys = createKeyRow(keys: ["z", "x", "c", "v", "b", "n", "m"])
        stackView.addArrangedSubview(letterKeys)
        
        // Backspace button
        let backspaceButton = createKeyButton(title: "⌫", action: #selector(backspaceTapped))
        configureBackspaceButton(backspaceButton)
        stackView.addArrangedSubview(backspaceButton)
        
        // Set width constraints after adding to stack view
        shiftButton.widthAnchor.constraint(equalTo: backspaceButton.widthAnchor).isActive = true
        shiftButton.widthAnchor.constraint(equalToConstant: 45).isActive = true // Slightly smaller
        backspaceButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        
        return stackView
    }
    
    private func createRow4() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        let config = layoutConfig
        stackView.spacing = config.interKeySpacing

        // 123 button (number mode toggle)
        let numberButton = createKeyButton(title: "123", action: #selector(numberModeTapped))
        if let label = numberButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        stackView.addArrangedSubview(numberButton)
        
        // Next Keyboard button (globe icon)
        let nextKeyboardButton = createKeyButton(title: "🌐", action: #selector(handleInputModeList(from:with:)))
        if let label = nextKeyboardButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        if !needsInputModeSwitchKey {
            nextKeyboardButton.isHidden = true
        }
        stackView.addArrangedSubview(nextKeyboardButton)
        
        // Space bar
        let spaceButton = createKeyButton(title: "space", action: #selector(spaceTapped))
        if let label = spaceButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        stackView.addArrangedSubview(spaceButton)
        
        // Return button
        let returnButton = createKeyButton(title: "return", action: #selector(returnTapped))
        if let label = returnButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        stackView.addArrangedSubview(returnButton)
        
        // Set width constraints after adding to stack view - reduced sizes for tighter layout
        numberButton.widthAnchor.constraint(equalToConstant: 42).isActive = true // Reduced from 55
        nextKeyboardButton.widthAnchor.constraint(equalTo: numberButton.widthAnchor).isActive = true
        returnButton.widthAnchor.constraint(equalToConstant: 67).isActive = true // Reduced from 75
        
        return stackView
    }
    
    private func createKeyButton(title: String, action: Selector) -> UIButton {
        let button = KeyboardKeyButton()
        let config = layoutConfig
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = config.labelFont  // Story 6.2: Increased from 18pt to 20pt for better visual balance with larger keys
        button.keyCornerRadius = config.keyCornerRadius
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Story 6.1: Set initial colors (will be updated by updateAppearance)
        // Check both textDocumentProxy and traitCollection for more reliable dark mode detection
        let isDark = textDocumentProxy.keyboardAppearance == .dark || 
                     (textDocumentProxy.keyboardAppearance == .default && traitCollection.userInterfaceStyle == .dark)
        let textColor = isDark ? darkTextColor : lightTextColor
        let backgroundColor: UIColor = isModifierKeyTitle(title)
            ? (isDark ? darkModifierKeyBackground : lightModifierKeyBackground)
            : (isDark ? darkKeyBackground : lightKeyBackground)
        button.applyColors(background: backgroundColor, textColor: textColor)
        
        return button
    }
    
    // MARK: - Optimized Layout Creation (Story 2.9)
    
    /// Creates optimized letter layout that returns a view for caching
    private func createLetterLayoutOptimized() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        let config = layoutConfig
        
        // Reuse existing letter layout logic but return the container
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = config.interRowSpacing
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: config.horizontalPadding),
            mainStackView.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -config.horizontalPadding),
            mainStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: config.verticalPadding),
            mainStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -config.verticalPadding)
        ])
        
        // Row 1: Q W E R T Y U I O P
        let row1 = createKeyRow(keys: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
        row1.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: A S D F G H J K L (home row with extra side inset)
        let row2 = createKeyRow(
            keys: ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            horizontalInset: config.homeRowSideInset
        )
        row2.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true
        mainStackView.addArrangedSubview(row2)
        
        // Row 3: Shift + Z X C V B N M + Backspace
        let row3 = createRow3()
        row3.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true  // Story 6.2: Increased from 38pt to 46pt
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: 123 + Next Keyboard + Space + Return
        let row4 = createRow4()
        row4.heightAnchor.constraint(equalToConstant: config.bottomRowHeight).isActive = true  // Story 6.2: Increased from 32pt to 38pt
        mainStackView.addArrangedSubview(row4)
        
        // Add to keyboard view
        keyboardView.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor),
            containerView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor),
            containerView.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor)
        ])
        
        return containerView
    }
    
    /// Creates optimized number layout that returns a view for caching
    private func createNumberLayoutOptimized() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        let config = layoutConfig
        
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = config.interRowSpacing  // Story 6.2: Increased from 3pt to 4pt
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: config.horizontalPadding),
            mainStackView.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -config.horizontalPadding),
            mainStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: config.verticalPadding),
            mainStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -config.verticalPadding)
        ])
        
        // Row 1: 1 2 3 4 5 6 7 8 9 0
        let row1 = createKeyRow(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        row1.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: - / : ; ( ) $ & @ "
        let row2 = createKeyRow(keys: ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""])
        row2.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true
        mainStackView.addArrangedSubview(row2)
        
        // Row 3: #+= button + . , ? ! ' + Backspace
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = config.interKeySpacing
        row3.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true
        
        let symbolModeButton = createKeyButton(title: "#+=", action: #selector(symbolModeTapped))
        symbolModeButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(symbolModeButton)
        
        let punctuationKeys = createKeyRow(keys: [".", ",", "?", "!", "'"])
        row3.addArrangedSubview(punctuationKeys)
        
        let backspaceButton = createKeyButton(title: "⌫", action: #selector(backspaceTapped))
        configureBackspaceButton(backspaceButton)
        backspaceButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(backspaceButton)
        
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: ABC + Globe + Space + Return
        let row4 = UIStackView()
        row4.axis = .horizontal
        row4.spacing = config.interKeySpacing
        row4.heightAnchor.constraint(equalToConstant: config.bottomRowHeight).isActive = true
        
        let abcButton = createKeyButton(title: "ABC", action: #selector(letterModeTapped))
        abcButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if let label = abcButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(abcButton)
        
        let nextKeyboardButton = createKeyButton(title: "🌐", action: #selector(handleInputModeList(from:with:)))
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if let label = nextKeyboardButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        if !needsInputModeSwitchKey {
            nextKeyboardButton.isHidden = true
        }
        row4.addArrangedSubview(nextKeyboardButton)
        
        let spaceButton = createKeyButton(title: "space", action: #selector(spaceTapped))
        if let label = spaceButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(spaceButton)
        
        let returnButton = createKeyButton(title: "return", action: #selector(returnTapped))
        returnButton.widthAnchor.constraint(equalToConstant: 67).isActive = true
        if let label = returnButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(returnButton)
        
        mainStackView.addArrangedSubview(row4)
        
        // Add to keyboard view
        keyboardView.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor),
            containerView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor),
            containerView.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor)
        ])
        
        return containerView
    }
    
    /// Creates optimized symbol layout that returns a view for caching
    private func createSymbolLayoutOptimized() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        let config = layoutConfig
        
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = config.interRowSpacing  // Story 6.2: Increased from 3pt to 4pt
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: config.horizontalPadding),
            mainStackView.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -config.horizontalPadding),
            mainStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: config.verticalPadding),
            mainStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -config.verticalPadding)
        ])
        
        // Row 1: [ ] { } # % ^ * + =
        let row1 = createKeyRow(keys: ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
        row1.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: _ \ | ~ < > $ £ ¥ •
        let row2 = createKeyRow(keys: ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"])
        row2.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true
        mainStackView.addArrangedSubview(row2)
        
        // Row 3: 123 button + . , ? ! ' + Backspace
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = config.interKeySpacing
        row3.heightAnchor.constraint(equalToConstant: config.rowHeight).isActive = true
        
        let numberModeButton = createKeyButton(title: "123", action: #selector(numberModeTapped))
        numberModeButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(numberModeButton)
        
        let punctuationKeys = createKeyRow(keys: [".", ",", "?", "!", "'"])
        row3.addArrangedSubview(punctuationKeys)
        
        let backspaceButton = createKeyButton(title: "⌫", action: #selector(backspaceTapped))
        configureBackspaceButton(backspaceButton)
        backspaceButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(backspaceButton)
        
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: ABC + Globe + Space + Return
        let row4 = UIStackView()
        row4.axis = .horizontal
        row4.spacing = config.interKeySpacing
        row4.heightAnchor.constraint(equalToConstant: config.bottomRowHeight).isActive = true
        
        let abcButton = createKeyButton(title: "ABC", action: #selector(letterModeTapped))
        abcButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if let label = abcButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(abcButton)
        
        let nextKeyboardButton = createKeyButton(title: "🌐", action: #selector(handleInputModeList(from:with:)))
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if let label = nextKeyboardButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        if !needsInputModeSwitchKey {
            nextKeyboardButton.isHidden = true
        }
        row4.addArrangedSubview(nextKeyboardButton)
        
        let spaceButton = createKeyButton(title: "space", action: #selector(spaceTapped))
        if let label = spaceButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(spaceButton)
        
        let returnButton = createKeyButton(title: "return", action: #selector(returnTapped))
        returnButton.widthAnchor.constraint(equalToConstant: 67).isActive = true
        if let label = returnButton.titleLabel {
            label.font = config.labelFont.withSize(config.labelFont.pointSize - 2)
        }
        row4.addArrangedSubview(returnButton)
        
        mainStackView.addArrangedSubview(row4)
        
        // Add to keyboard view
        keyboardView.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor),
            containerView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor),
            containerView.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor)
        ])
        
        return containerView
    }
    
    /// Updates appearance for a specific layout view (Story 2.9)
    private func updateAppearanceForLayout(_ layoutView: UIView) {
        let isDark = textDocumentProxy.keyboardAppearance == .dark
        
        // Story 6.1: Always update cached layouts to ensure color consistency
        // (Removed cache check to fix color issues when switching layouts)
        
        // Story 6.1: Keep background transparent to show native iOS blur
        keyboardView.backgroundColor = .clear
        
        // Update buttons in the layout
        if let mainStackView = layoutView.subviews.first as? UIStackView {
            updateStackViewButtons(mainStackView, isDark: isDark)
        }
        
        // Update the cached appearance
        cachedKeyboardAppearance = textDocumentProxy.keyboardAppearance
    }
    
    // MARK: - Appearance
    private func updateAppearance() {
        guard let keyboardView = keyboardView else { return }
        
        let isDark = textDocumentProxy.keyboardAppearance == .dark
        
        // Story 6.1: Keep background transparent to show native iOS blur
        keyboardView.backgroundColor = .clear
        
        // Update all buttons - find the main stack view
        if let mainStackView = keyboardView.subviews.first as? UIStackView {
            updateStackViewButtons(mainStackView, isDark: isDark)
        }
        
        // Story 2.8: Update privacy message appearance
        privacyMessageView?.updateAppearance(isDark: isDark)
    }
    
    private func updateStackViewButtons(_ stackView: UIStackView, isDark: Bool) {
        // Story 6.1: Use color constants for all keys consistently
        let keyColor = isDark ? darkKeyBackground : lightKeyBackground
        let modifierColor = isDark ? darkModifierKeyBackground : lightModifierKeyBackground
        let textColor = isDark ? darkTextColor : lightTextColor

        for view in stackView.arrangedSubviews {
            if let keyButton = view as? KeyboardKeyButton,
               let title = keyButton.title(for: .normal) {
                let background = isModifierKeyTitle(title) ? modifierColor : keyColor
                keyButton.applyColors(background: background, textColor: textColor)
            } else if let button = view as? UIButton,
                      let title = button.title(for: .normal) {
                let background = isModifierKeyTitle(title) ? modifierColor : keyColor
                if button.backgroundColor != background {
                    button.backgroundColor = background
                }
                button.setTitleColor(textColor, for: .normal)
            } else if let nestedStack = view as? UIStackView {
                updateStackViewButtons(nestedStack, isDark: isDark)
            } else {
                // Handle container views
                for subview in view.subviews {
                    if let keyButton = subview as? KeyboardKeyButton,
                       let title = keyButton.title(for: .normal) {
                        let background = isModifierKeyTitle(title) ? modifierColor : keyColor
                        keyButton.applyColors(background: background, textColor: textColor)
                    } else if let button = subview as? UIButton,
                              let title = button.title(for: .normal) {
                        let background = isModifierKeyTitle(title) ? modifierColor : keyColor
                        if button.backgroundColor != background {
                            button.backgroundColor = background
                        }
                        button.setTitleColor(textColor, for: .normal)
                    } else if let nestedStack = subview as? UIStackView {
                        updateStackViewButtons(nestedStack, isDark: isDark)
                    }
                }
            }
        }
    }
    
    // MARK: - Backspace Handling
    private func configureBackspaceButton(_ button: UIButton) {
        button.removeTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
        button.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(backspaceTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        button.addTarget(self, action: #selector(backspaceTouchDragEnter(_:)), for: .touchDragEnter)
    }

    private func scheduleBackspaceRepeat() {
        cancelBackspaceRepeat()
        let timer = Timer.scheduledTimer(timeInterval: backspaceInitialRepeatDelay, target: self, selector: #selector(handleBackspaceInitialRepeatTimer), userInfo: nil, repeats: false)
        backspaceInitialDelayTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelBackspaceRepeat() {
        backspaceInitialDelayTimer?.invalidate()
        backspaceInitialDelayTimer = nil
        backspaceRepeatTimer?.invalidate()
        backspaceRepeatTimer = nil
    }

    @objc private func handleBackspaceInitialRepeatTimer() {
        performBackspaceDeletion()

        let repeatTimer = Timer.scheduledTimer(timeInterval: backspaceRepeatInterval, target: self, selector: #selector(handleBackspaceRepeatTimerFire), userInfo: nil, repeats: true)
        repeatTimer.tolerance = backspaceRepeatInterval * 0.25
        backspaceRepeatTimer = repeatTimer
        RunLoop.main.add(repeatTimer, forMode: .common)
    }

    @objc private func handleBackspaceRepeatTimerFire() {
        performBackspaceDeletion()
    }

    @objc private func backspaceTouchDown(_ sender: UIButton) {
        performBackspaceDeletion()
        scheduleBackspaceRepeat()
    }

    @objc private func backspaceTouchUp(_ sender: UIButton) {
        cancelBackspaceRepeat()
    }

    @objc private func backspaceTouchDragEnter(_ sender: UIButton) {
        performBackspaceDeletion()
        scheduleBackspaceRepeat()
    }

    private func performBackspaceDeletion() {
        textDocumentProxy.deleteBackward()
        
        // Update snippet buffer (Story 2.2)
        snippetProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            _ = self.snippetManager.deleteLastCharacter()
        }
    }

    // MARK: - Actions
    @objc private func keyTapped(_ sender: UIButton) {
        // Performance optimization: Fast path for key insertion (Story 2.9)
        guard let key = sender.title(for: .normal) else { return }
        
        // Optimize character processing for minimal latency
        let character: String
        if currentLayout == .letters {
            character = isShifted ? key.uppercased() : key.lowercased()
        } else {
            character = key
        }
        
        // Insert text immediately for best responsiveness
        textDocumentProxy.insertText(character)
        
        // Defer non-critical operations to avoid blocking UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Snippet management (Story 2.2) - deferred for performance
            self.processCharacterForSnippet(character)
            
            // Auto-disable shift after typing one character (only for letter layout)
            if self.currentLayout == .letters && self.isShifted {
                self.isShifted = false
                self.updateShiftStateOptimized()
            }
        }
    }
    
    @objc private func shiftTapped() {
        isShifted.toggle()
        updateShiftState()
    }
    
    private func updateShiftState() {
        guard let keyboardView = keyboardView else { return }
        
        // Update shift button appearance to indicate state
        updateShiftButtonIfNeeded(in: keyboardView)
        applyLetterCaseToCurrentLayout()
    }
    
    // Performance optimized version that uses cached shift button (Story 2.9)
    private func updateShiftStateOptimized() {
        // Use cached shift button if available
        if let cachedButton = cachedShiftButton {
            updateSingleShiftButton(cachedButton)
            applyLetterCaseToCurrentLayout()
        } else {
            // Fallback to full search and cache the result
            updateShiftState()
        }
    }
    
    private func updateShiftButton(in stackView: UIStackView) {
        for view in stackView.arrangedSubviews {
            if let button = view as? UIButton, button.title(for: .normal) == "⇧" {
                // Cache the shift button for performance optimization (Story 2.9)
                cachedShiftButton = button
                updateSingleShiftButton(button)
            } else if let nestedStack = view as? UIStackView {
                updateShiftButton(in: nestedStack)
            } else {
                for subview in view.subviews {
                    if let nestedStack = subview as? UIStackView {
                        updateShiftButton(in: nestedStack)
                    }
                }
            }
        }
    }

    private func updateShiftButtonIfNeeded(in view: UIView) {
        if let stackView = view as? UIStackView {
            updateShiftButton(in: stackView)
        } else {
            for subview in view.subviews {
                updateShiftButtonIfNeeded(in: subview)
            }
        }
    }
    
    // Optimized method to update a single shift button (Story 2.9)
    private func updateSingleShiftButton(_ button: UIButton) {
        let isDark = textDocumentProxy.keyboardAppearance == .dark
        
        // Story 6.1: Use color constants, with slight modification for shifted state
        let normalColor = isDark ? darkModifierKeyBackground : lightModifierKeyBackground
        let shiftedColor = isDark ? UIColor(white: 0.5, alpha: 1.0) : UIColor(white: 0.8, alpha: 1.0)
        let textColor = isDark ? darkTextColor : lightTextColor
        
        if button.backgroundColor != (isShifted ? shiftedColor : normalColor) {
            button.backgroundColor = isShifted ? shiftedColor : normalColor
        }
        button.setTitleColor(textColor, for: .normal)
    }
    
    @objc private func backspaceTapped() {
        performBackspaceDeletion()
    }
    
    @objc private func spaceTapped() {
        textDocumentProxy.insertText(" ")
        
        // Snippet management (Story 2.2)
        processCharacterForSnippet(" ")
    }
    
    @objc private func returnTapped() {
        textDocumentProxy.insertText("\n")
    }
    
    @objc private func numberModeTapped() {
        currentLayout = .numbers
        createKeyboardLayout()
        updateAppearance()
    }
    
    @objc private func symbolModeTapped() {
        currentLayout = .symbols
        createKeyboardLayout()
        updateAppearance()
    }
    
    @objc private func letterModeTapped() {
        currentLayout = .letters
        createKeyboardLayout()
        updateAppearance()
    }
    
    // MARK: - Snippet Management (Story 2.2)
    
    /// Processes a typed character for snippet capture and analysis triggering
    /// - Parameter character: The character that was typed
    private func processCharacterForSnippet(_ character: String) {
        guard isAnalysisFeatureEnabled else {
            return
        }

        // Story 2.8: Skip text capture when Full Access is disabled (graceful degradation)
        guard hasFullAccessPermission else {
            return
        }
        
        // Check if current field is secure (password field)
        if secureDetector.isSecureField(textDocumentProxy) {
            return
        }
        
        snippetProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Append character and check for trigger
            if let snippet = self.snippetManager.append(character) {
                self.handleSnippetTrigger(snippet)
            }
        }
    }
    
    /// Handles snippet analysis trigger work off the main thread
    /// - Parameter snippet: Snippet to analyze
    private func handleSnippetTrigger(_ snippet: TextSnippet) {
        guard isAnalysisFeatureEnabled else {
            return
        }

        // Story 2.3: Send snippet to backend for analysis
        
        // Call backend API (non-blocking, async)
        analyzeSnippet(snippet.content)
    }
    
    /// Sends text snippet to backend for scam analysis
    /// - Parameter text: Text content to analyze
    private func analyzeSnippet(_ text: String) {
        guard isAnalysisFeatureEnabled else {
            return
        }

        // Story 2.8: Check Full Access permission before making API calls
        guard hasFullAccessPermission else {
            return
        }
        
        // Story 2.7: Update analysis timestamp
        sharedStorageManager.updateLastAnalysisTimestamp()
        
        apiService.analyzeText(text: text) { result in
            switch result {
            case .success(let response):
                
                // Story 2.7: Store privacy-safe scan result in shared storage
                let scanResult = SharedStorageManager.ScanResult(
                    riskLevel: response.risk_level,
                    category: response.category,
                    timestamp: Date(),
                    hasRisks: response.risk_level != "low" && response.risk_level != "none"
                )
                self.sharedStorageManager.storeLatestScanResult(scanResult)
                
                // Story 2.4: Display banner if risk_level is medium or high
                self.showAlertBanner(for: response)
                
            case .failure(let error):
                // Silent failure - log error but don't disrupt user
                // Keyboard continues to function normally
                break
            }
        }
    }
    
    // MARK: - Banner Management (Story 2.4)
    
    /// Displays alert banner for medium or high risk detections
    /// - Parameter response: API response containing risk analysis
    private func showAlertBanner(for response: AnalyzeTextResponse) {
        // Story 2.7: Check alert preferences from shared storage
        let alertPreferences = sharedStorageManager.getAlertPreferences()
        
        // Check if banners are enabled
        guard alertPreferences.showBanners else {
            return
        }
        
        // Check risk threshold from preferences
        let riskThreshold = alertPreferences.riskThreshold
        let shouldShowBanner: Bool
        
        switch riskThreshold {
        case "low":
            shouldShowBanner = ["low", "medium", "high"].contains(response.risk_level)
        case "medium":
            shouldShowBanner = ["medium", "high"].contains(response.risk_level)
        case "high":
            shouldShowBanner = response.risk_level == "high"
        default:
            shouldShowBanner = ["medium", "high"].contains(response.risk_level)
        }
        
        guard shouldShowBanner else {
            return
        }
        
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Dismiss existing banner if present
            self.dismissBanner(animated: false)
            
            // Determine risk level
            let riskLevel: RiskLevel = response.risk_level == "high" ? .high : .medium
            
            // Trigger haptic feedback
            self.triggerHapticFeedback(for: riskLevel)
            
            // Create new banner
            let banner = RiskAlertBannerView(
                riskLevel: riskLevel,
                response: response,
                dismissAction: { [weak self] in
                    self?.dismissBanner(animated: true)
                },
                showPopoverAction: { [weak self] response in
                    self?.showExplainWhyPopover(for: response)
                }
            )
            
            // Add banner to view hierarchy at top
            self.view.addSubview(banner)
            
            // Setup Auto Layout constraints (banner positioned in top 40pt area)
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: self.view.topAnchor),
                banner.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                banner.heightAnchor.constraint(equalToConstant: 40)
            ])
            
            // Store reference
            self.currentBanner = banner
            
            // Animate appearance (fade in + slide down)
            banner.alpha = 0
            banner.transform = CGAffineTransform(translationX: 0, y: -60)
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                banner.alpha = 1
                banner.transform = .identity
            }
            
            // Start auto-dismiss timer (10 seconds)
            self.startAutoDismissTimer()
            
            
        }
    }
    
    /// Dismisses the current banner
    /// - Parameter animated: Whether to animate the dismissal
    private func dismissBanner(animated: Bool) {
        // Invalidate timer
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        
        guard let banner = currentBanner else { return }
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                banner.alpha = 0
                banner.transform = CGAffineTransform(translationX: 0, y: -60)
            }) { _ in
                banner.removeFromSuperview()
            }
        } else {
            banner.removeFromSuperview()
        }
        
        currentBanner = nil
        
    }
    
    /// Starts the 10-second auto-dismiss timer
    private func startAutoDismissTimer() {
        // Invalidate existing timer
        autoDismissTimer?.invalidate()
        
        // Create new timer
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.dismissBanner(animated: true)
        }
    }
    
    /// Triggers haptic feedback based on risk level
    /// - Parameter riskLevel: The risk level (medium or high)
    private func triggerHapticFeedback(for riskLevel: RiskLevel) {
        // Only trigger haptic if Full Access is enabled
        guard hasFullAccessPermission else {
            return
        }
        
        // Story 2.7: Check haptic preferences from shared storage
        let alertPreferences = sharedStorageManager.getAlertPreferences()
        guard alertPreferences.enableHapticFeedback else {
            return
        }
        
        // Select impact style based on risk level
        let style: UIImpactFeedbackGenerator.FeedbackStyle = riskLevel == .high ? .heavy : .medium
        
        // Create generator with appropriate style
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        
        
    }
    
    // MARK: - Popover Management (Story 2.6)
    
    /// Shows the explain why popover with response details
    /// - Parameter response: The AnalyzeTextResponse containing risk details
    private func showExplainWhyPopover(for response: AnalyzeTextResponse) {
        // Dismiss any existing popover first
        dismissExplainWhyPopover()
        
        // Create new popover
        let popover = ExplainWhyPopoverView(response: response) { [weak self] in
            self?.dismissExplainWhyPopover()
        }
        
        // Store reference
        currentPopover = popover
        
        // Show popover
        popover.show(in: self.view)
        
        
    }
    
    /// Dismisses the current explain why popover
    private func dismissExplainWhyPopover() {
        guard let popover = currentPopover else { return }
        
        popover.dismiss()
        currentPopover = nil
        
        
    }
    
    // MARK: - Privacy Message Management (Story 2.8)
    
    /// Sets up privacy message display when Full Access is disabled
    private func setupPrivacyMessage() {
        // Remove existing privacy message
        privacyMessageView?.removeFromSuperview()
        privacyMessageView = nil
        
        // Only show privacy message if Full Access is disabled
        guard !hasFullAccessPermission else {
            return
        }
        
        // Create privacy message view
        let privacyMessage = PrivacyMessageView(
            settingsAction: { [weak self] in
                self?.openKeyboardSettings()
            },
            dismissAction: { [weak self] in
                self?.dismissPrivacyMessage()
            }
        )
        
        // Add to view hierarchy in the banner area
        view.addSubview(privacyMessage)
        
        // Setup constraints (positioned in top 60pt area)
        NSLayoutConstraint.activate([
            privacyMessage.topAnchor.constraint(equalTo: view.topAnchor),
            privacyMessage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            privacyMessage.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            privacyMessage.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Store reference
        privacyMessageView = privacyMessage
        
        
    }
    
    /// Opens iOS Settings to keyboard configuration
    private func openKeyboardSettings() {
        
        // Try to open Settings app with deep link to keyboard settings
        if URL(string: "App-Prefs:General&path=Keyboard") != nil {
            // Note: This may not work in all iOS versions due to security restrictions
            // The keyboard extension has limited ability to open external URLs
        }
        
        // Since direct deep linking is restricted, we'll show an instructional message
        // This could be enhanced with a more detailed instruction popover in the future
    }
    
    /// Dismisses the privacy message
    private func dismissPrivacyMessage() {
        privacyMessageView?.removeFromSuperview()
        privacyMessageView = nil
        
    }
    
    // MARK: - Performance Cache Management (Story 2.9)
    
    /// Clears all performance caches to free memory
    private func clearPerformanceCaches() {
        layoutCache.removeAll()
        cachedShiftButton = nil
        cachedKeyboardAppearance = nil
        cancelBackspaceRepeat()
    }
    
    // MARK: - Scan Result Polling (Story 3.7)
    
    /// Starts polling for new scan results from companion app
    private func startScanResultPolling() {
        guard isAnalysisFeatureEnabled else {
            return
        }

        // Stop any existing timer
        stopScanResultPolling()
        
        
        
        // Create timer with 5-second intervals for responsiveness vs battery efficiency
        scanResultPollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForNewScanResults()
        }
        
        // Also check immediately
        checkForNewScanResults()
    }
    
    /// Stops scan result polling
    private func stopScanResultPolling() {
        scanResultPollingTimer?.invalidate()
        scanResultPollingTimer = nil
        
    }
    
    /// Checks for new scan results from shared storage
    private func checkForNewScanResults() {
        guard isAnalysisFeatureEnabled else {
            return
        }

        // Use background queue to prevent UI blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // Get latest scan result from shared storage
            if let newResult = self.sharedStorageManager.getLatestSharedScanResult() {
                // Check if we've already processed this scan
                guard newResult.scanId != self.lastProcessedScanId else {
                    return // Already processed this scan
                }
                
                // Update last processed ID
                self.lastProcessedScanId = newResult.scanId
                
                
                // Show banner on main thread
                DispatchQueue.main.async {
                    self.showScanResultBanner(newResult)
                }
                
                // Mark as read in background
                DispatchQueue.global(qos: .utility).async {
                    self.sharedStorageManager.markScanResultAsRead(newResult.scanId)
                }
            }
            
            // Cleanup old scan results periodically
            self.sharedStorageManager.clearOldScanResults()
        }
    }
    
    /// Shows a banner for a new scan result
    /// - Parameter scanResult: The SharedScanResult to display
    private func showScanResultBanner(_ scanResult: SharedScanResult) {
        // Dismiss any existing banner first
        dismissBanner(animated: false)
        
        // Create scan result banner
        let banner = ScanResultBannerView(
            scanResult: scanResult,
            dismissAction: { [weak self] in
                self?.dismissBanner(animated: true)
            }
        )
        
        // Add banner to view hierarchy at top
        view.addSubview(banner)
        
        // Setup Auto Layout constraints (banner positioned in top 30pt area)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Store reference (reusing currentBanner property)
        currentBanner = banner
        
        // Animate appearance (fade in + slide down)
        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -60)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            banner.alpha = 1
            banner.transform = .identity
        }
        
        // Start auto-dismiss timer (10 seconds for scan result banners)
        startScanResultAutoDismissTimer()
        
        
    }
    
    /// Starts the 10-second auto-dismiss timer for scan result banners
    private func startScanResultAutoDismissTimer() {
        // Invalidate existing timer
        autoDismissTimer?.invalidate()
        
        // Create new timer (10 seconds for scan result banners)
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.dismissBanner(animated: true)
        }
    }
    
    // MARK: - Screenshot Notification Polling (Story 4.2)
    
    /// Sets up and starts screenshot notification polling service
    private func setupScreenshotNotificationPolling() {
        // Initialize App Group notification service (from main app)
        screenshotNotificationService = ScreenshotNotificationService()
        
        // Set up callback for new notifications
        screenshotNotificationService?.onNewNotification = { [weak self] notification in
            self?.handleScreenshotNotification(notification)
        }
        
        // Start polling
        screenshotNotificationService?.startPolling()
        
        
        
        // Story 5.3 & 5.4: Direct screenshot detection with keyboard-based processing
        // This works completely independently - NO main app needed!
        screenshotDetectionService = ScreenshotDetectionService()
        screenshotDetectionService?.startPolling { [weak self] in
            
            self?.handleScreenshotDetectedInKeyboard()
        }
        
        
    }
    
    /// Handles a new screenshot notification by displaying the alert banner
    /// - Parameter notification: The screenshot notification to handle
    private func handleScreenshotNotification(_ notification: ScreenshotNotification) {
        
        
        // Dismiss any existing banner first (scan result or screenshot)
        dismissBanner(animated: false)
        
        // Create screenshot alert banner
        let banner = ScreenshotAlertBannerView(
            notification: notification,
            scanAction: { [weak self] in
                self?.launchCompanionAppForScreenshotScan()
            },
            dismissAction: { [weak self] in
                self?.dismissBanner(animated: true)
            }
        )
        
        // Configure accessibility
        banner.configureAccessibility()
        
        // Add banner to view hierarchy at top
        view.addSubview(banner)
        
        // Setup Auto Layout constraints (banner positioned in top 30pt area)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Store reference
        currentBanner = banner
        
        // Animate appearance
        banner.animateIn()
        
        // Start auto-dismiss timer (15 seconds for screenshot banners)
        startScreenshotBannerAutoDismissTimer()
        
        
    }
    
    /// Launches the companion app using URL scheme for screenshot scanning
    /// Story 5.2: Enhanced with auto=true parameter for automatic screenshot fetching
    private func launchCompanionAppForScreenshotScan() {
        
        
        // Story 5.2: Add auto=true parameter to trigger automatic screenshot fetching
        guard let url = URL(string: "typesafe://scan?auto=true") else {
            return
        }
        
        // iOS keyboard extensions can open URLs via the responder chain
        // Navigate up the responder chain to find UIApplication
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: { success in
                })
                break
            }
            responder = responder?.next
        }
        
        // Dismiss the banner after launching
        dismissBanner(animated: true)
    }
    
    /// Story 5.4: Process screenshot directly in keyboard (FULLY INDEPENDENT!)
    /// Fetches screenshot, performs OCR, calls API - all without main app!
    private func handleScreenshotDetectedInKeyboard() {
        
        // Run heavy Photos work off the main thread to keep typing responsive
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Check Photos permission
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else {
                return
            }
            
            // Fetch most recent screenshot
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
            fetchOptions.fetchLimit = 1
            
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            guard let asset = fetchResult.firstObject else {
                return
            }
            
            
            
            // Convert PHAsset to UIImage
            let imageOptions = PHImageRequestOptions()
            imageOptions.isSynchronous = false
            imageOptions.deliveryMode = .highQualityFormat
            let targetSize = CGSize(width: 1920, height: 1920)
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: imageOptions
            ) { [weak self] image, info in
                guard let self = self, let image = image else {
                    return
                }
                
                // Generate session ID
                let sessionId = UUID().uuidString
                
                // Call API directly from keyboard!
                self.keyboardAPIService.scanImage(image: image, sessionId: sessionId) { result in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        switch result {
                        case .success(let response):
                            
                            // Check if this is an agent response or simple response
                            if response.isAgentResponse {
                                
                                // Handle agent response with WebSocket
                                self.handleAgentResponse(response: response)
                            } else {
                                // Show result banner directly!
                                self.showScamResultBanner(response: response)
                            }
                            
                        case .failure:
                            // Show error banner
                            self.showErrorBanner(message: "Unable to analyze screenshot")
                        }
                    }
                }
            }
        }
    }
    
    /// Handles agent response by connecting to WebSocket for progress updates
    private func handleAgentResponse(response: KeyboardAPIService.ScanResponse) {
        guard let wsUrl = response.wsUrl, let taskId = response.taskId else {
            showErrorBanner(message: "Unable to connect to analysis service")
            return
        }
        
        
        
        // Show analyzing banner
        showAnalyzingBanner(estimatedTime: response.estimatedTime ?? "5-30 seconds")
        
        // Create and connect WebSocket manager
        webSocketManager = KeyboardWebSocketManager(wsUrl: wsUrl, taskId: taskId)
        webSocketManager?.connect(
            onProgress: { [weak self] progress in
                // Update analyzing banner with progress
                self?.updateAnalyzingBanner(progress: progress.progress, message: progress.message)
            },
            onCompletion: { [weak self] result in
                guard let self = self else {
                    return
                }
                
                
                // Convert to ScanResponse format and show result IMMEDIATELY (no delay)
                let scanResponse = KeyboardAPIService.ScanResponse(
                    type: "simple",
                    riskLevel: result.riskLevel,
                    confidence: result.confidence,
                    category: result.category,
                    explanation: result.explanation,
                    taskId: nil,
                    wsUrl: nil,
                    estimatedTime: nil,
                    entitiesFound: nil
                )
                
                self.showScamResultBanner(response: scanResponse)
                
                // NOW clean up WebSocket after banner is shown
                self.webSocketManager?.disconnect()
                self.webSocketManager = nil
            },
            onError: { [weak self] _ in
                
                // MUST be on main thread for UI updates
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.showErrorBanner(message: "Analysis failed - please try again")
                    
                    // Clean up WebSocket after error banner shown
                    self.webSocketManager?.disconnect()
                    self.webSocketManager = nil
                }
            }
        )
    }
    
    /// Current analysis response (stored for tap to view details)
    private var currentAnalysisResponse: KeyboardAPIService.ScanResponse?
    
    /// Shows a banner with the scam analysis result
    private func showScamResultBanner(response: KeyboardAPIService.ScanResponse) {
        
        // Store response for tap-to-view details
        currentAnalysisResponse = response
        
        // Dismiss any existing banner
        dismissBanner(animated: false)
        
        // Determine risk color and icon
        let backgroundColor: UIColor
        let textColor: UIColor
        let icon: String
        let riskLevel = response.riskLevel ?? "unknown"
        
        switch riskLevel.lowercased() {
        case "high":
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.95)
            textColor = .white
            icon = "⚠️"
        case "medium":
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.95)
            textColor = .white
            icon = "⚠️"
        case "low":
            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.95)
            textColor = .white
            icon = "✅"
        default:
            backgroundColor = UIColor.systemGray.withAlphaComponent(0.95)
            textColor = .white
            icon = "ℹ️"
        }
        
        // Create banner view
        let banner = UIView()
        banner.backgroundColor = backgroundColor
        banner.layer.cornerRadius = 8
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.isUserInteractionEnabled = true
        
        // Add tap gesture to view details
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(bannerTappedToViewDetails))
        tapGesture.cancelsTouchesInView = false  // Don't interfere with other gestures
        banner.addGestureRecognizer(tapGesture)
        
        // Add subtle indicator that banner is tappable
        banner.layer.borderWidth = 1
        banner.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        // Icon label
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = .systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Message label
        let messageLabel = UILabel()
        let confidencePercent = Int((response.confidence ?? 0.0) * 100)
        let category = (response.category ?? "unknown").uppercased()
        let risk = riskLevel.uppercased()
        messageLabel.text = "\(category): \(risk) RISK (\(confidencePercent)%)\nTap for details"
        messageLabel.textColor = textColor
        messageLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        messageLabel.numberOfLines = 2
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.8
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Dismiss button
        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.setTitleColor(textColor, for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissBannerTapped), for: .touchUpInside)
        
        // Add subviews
        banner.addSubview(iconLabel)
        banner.addSubview(messageLabel)
        banner.addSubview(dismissButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Icon
            iconLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 24),
            
            // Message
            messageLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            messageLabel.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            
            // Dismiss button
            dismissButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            dismissButton.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 30),
            dismissButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Banner height
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        
        currentBanner = banner
        
        // Add banner to view (same as analyzing banner)
        view.addSubview(banner)
        
        // Position banner at TOP with more margin
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),  // More margin
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])
        
        // Animate in
        banner.alpha = 0
        banner.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            banner.alpha = 1.0
            banner.transform = CGAffineTransform.identity
        }
        
        // Auto-dismiss after 20 seconds (longer for result reading)
        startBannerAutoDismissTimer(duration: 20.0)
        
        // Haptic feedback
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        
        switch riskLevel.lowercased() {
        case "high":
            feedbackGenerator.notificationOccurred(.warning)
        case "medium":
            feedbackGenerator.notificationOccurred(.warning)
        case "low":
            feedbackGenerator.notificationOccurred(.success)
        default:
            break
        }
    }
    
    /// Dismiss banner button tapped
    @objc private func dismissBannerTapped() {
        dismissBanner(animated: true)
    }
    
    /// Banner tapped to view analysis details
    @objc private func bannerTappedToViewDetails() {
        
        guard let response = currentAnalysisResponse else {
            return
        }
        
        
        // Haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
        
        // Show detailed explanation
        showAnalysisDetails(response: response)
    }
    
    /// Shows detailed analysis explanation in a custom modal (can't use UIAlertController in keyboard extensions)
    private func showAnalysisDetails(response: KeyboardAPIService.ScanResponse) {
        // Dismiss banner when showing modal
        dismissBanner(animated: true)
        
        let riskLevel = (response.riskLevel ?? "unknown").uppercased()
        let confidencePercent = Int((response.confidence ?? 0.0) * 100)
        let category = (response.category ?? "unknown").uppercased()
        let explanation = response.explanation ?? "No detailed explanation available."
        
        // Determine risk icon and color
        let icon: String
        let titleColor: UIColor
        switch (response.riskLevel ?? "unknown").lowercased() {
        case "high":
            icon = "⚠️"
            titleColor = .systemRed
        case "medium":
            icon = "⚠️"
            titleColor = .systemOrange
        case "low":
            icon = "✅"
            titleColor = .systemGreen
        default:
            icon = "ℹ️"
            titleColor = .systemGray
        }
        
        // Create overlay background
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.tag = 8888 // Tag for removal
        
        // Create modal card
        let modalCard = UIView()
        modalCard.backgroundColor = .white
        modalCard.layer.cornerRadius = 12
        modalCard.translatesAutoresizingMaskIntoConstraints = false
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "\(icon) \(riskLevel) RISK"
        titleLabel.textColor = titleColor
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Category label
        let categoryLabel = UILabel()
        categoryLabel.text = category
        categoryLabel.textColor = .darkGray
        categoryLabel.font = .systemFont(ofSize: 14, weight: .medium)
        categoryLabel.textAlignment = .center
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Confidence label
        let confidenceLabel = UILabel()
        confidenceLabel.text = "📊 Confidence: \(confidencePercent)%"
        confidenceLabel.textColor = .darkGray
        confidenceLabel.font = .systemFont(ofSize: 14, weight: .regular)
        confidenceLabel.textAlignment = .center
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Divider
        let divider = UIView()
        divider.backgroundColor = .lightGray.withAlphaComponent(0.3)
        divider.translatesAutoresizingMaskIntoConstraints = false
        
        // Explanation scroll view
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        
        let explanationLabel = UILabel()
        // Keep explanation short and sweet - truncate if too long
        let maxLength = 200
        let shortExplanation = explanation.count > maxLength 
            ? String(explanation.prefix(maxLength)) + "..." 
            : explanation
        explanationLabel.text = shortExplanation
        explanationLabel.textColor = .darkGray
        explanationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        explanationLabel.numberOfLines = 0
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(explanationLabel)
        
        // Close button (prominent and easy to tap)
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕ Close", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        closeButton.backgroundColor = .systemBlue
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 10
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeAnalysisDetailsTapped), for: .touchUpInside)
        
        // Add subviews
        modalCard.addSubview(titleLabel)
        modalCard.addSubview(categoryLabel)
        modalCard.addSubview(confidenceLabel)
        modalCard.addSubview(divider)
        modalCard.addSubview(scrollView)
        modalCard.addSubview(closeButton)
        
        overlay.addSubview(modalCard)
        keyboardView.addSubview(overlay)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Overlay fills keyboard
            overlay.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor),
            
            // Modal card positioned high (more negative margin)
            modalCard.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            modalCard.topAnchor.constraint(equalTo: overlay.topAnchor, constant: -40),  // Push higher
            modalCard.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 16),
            modalCard.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16),
            modalCard.heightAnchor.constraint(equalToConstant: 200),
            
            // Title (minimal top margin)
            titleLabel.topAnchor.constraint(equalTo: modalCard.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: modalCard.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: modalCard.trailingAnchor, constant: -12),
            
            // Category
            categoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            categoryLabel.leadingAnchor.constraint(equalTo: modalCard.leadingAnchor, constant: 12),
            categoryLabel.trailingAnchor.constraint(equalTo: modalCard.trailingAnchor, constant: -12),
            
            // Confidence
            confidenceLabel.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 4),
            confidenceLabel.leadingAnchor.constraint(equalTo: modalCard.leadingAnchor, constant: 12),
            confidenceLabel.trailingAnchor.constraint(equalTo: modalCard.trailingAnchor, constant: -12),
            
            // Divider
            divider.topAnchor.constraint(equalTo: confidenceLabel.bottomAnchor, constant: 8),
            divider.leadingAnchor.constraint(equalTo: modalCard.leadingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: modalCard.trailingAnchor, constant: -12),
            divider.heightAnchor.constraint(equalToConstant: 1),
            
            // Scroll view with explanation (compact)
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: modalCard.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: modalCard.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -8),
            
            // Explanation label in scroll view
            explanationLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
            explanationLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            explanationLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            explanationLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            explanationLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Close button (normal size)
            closeButton.leadingAnchor.constraint(equalTo: modalCard.leadingAnchor, constant: 12),
            closeButton.bottomAnchor.constraint(equalTo: modalCard.bottomAnchor, constant: -12),
            closeButton.trailingAnchor.constraint(equalTo: modalCard.trailingAnchor, constant: -12),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Animate in
        overlay.alpha = 0
        modalCard.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            overlay.alpha = 1.0
            modalCard.transform = .identity
        }
        
        // Add tap on overlay to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeAnalysisDetailsTapped))
        overlay.addGestureRecognizer(tapGesture)
    }
    
    @objc private func closeAnalysisDetailsTapped() {
        // Find and remove overlay
        if let overlay = keyboardView.viewWithTag(8888) {
            UIView.animate(withDuration: 0.2) {
                overlay.alpha = 0
            } completion: { _ in
                overlay.removeFromSuperview()
            }
        }
    }
    
    /// Shows an error banner
    /// Shows analyzing banner with progress
    private func showAnalyzingBanner(estimatedTime: String) {
        
        dismissBanner(animated: false)
        
        let banner = UIView()
        banner.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.95)
        banner.layer.cornerRadius = 8
        banner.tag = 9999 // Tag for updating
        
        let label = UILabel()
        label.text = "🔍 Analyzing... (\(estimatedTime))"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.tag = 1000 // Tag for updating text
        
        banner.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -8)
        ])
        
        view.addSubview(banner)
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        currentBanner = banner
    }
    
    /// Updates analyzing banner with progress
    private func updateAnalyzingBanner(progress: Int, message: String) {
        guard let banner = currentBanner, banner.tag == 9999,
              let label = banner.viewWithTag(1000) as? UILabel else {
            return
        }
        
        label.text = "🔍 \(progress)% - \(message)"
    }
    
    private func showErrorBanner(message: String) {
        
        dismissBanner(animated: false)
        
        // Create simple text banner for errors
        let banner = UIView()
        banner.backgroundColor = UIColor.systemGray.withAlphaComponent(0.95)
        banner.layer.cornerRadius = 8
        
        let label = UILabel()
        label.text = "❌ \(message)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 2
        label.textAlignment = .center
        
        banner.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -8)
        ])
        
        currentBanner = banner
        keyboardView.addSubview(banner)
        
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 8),
            banner.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -8),
            banner.bottomAnchor.constraint(equalTo: keyboardView.topAnchor, constant: -8) // Above keyboard!
        ])
        
        UIView.animate(withDuration: 0.3) {
            banner.alpha = 1.0
        }
        startBannerAutoDismissTimer(duration: 5.0)
    }
    
    /// Starts auto-dismiss timer for banners
    private func startBannerAutoDismissTimer(duration: TimeInterval) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismissBanner(animated: true)
        }
    }
    
    /// LEGACY: Launch app silently for automatic background scan (FALLBACK)
    /// This is the old method - keeping as fallback if keyboard processing fails
    private func launchCompanionAppForAutomaticScan() {
        
        guard let url = URL(string: "typesafe://scan?auto=true&silent=true") else {
            return
        }
        
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: { success in
                    if success {
                    } else {
                    }
                })
                break
            }
            responder = responder?.next
        }
    }
    
    /// Starts the 15-second auto-dismiss timer for screenshot banners
    private func startScreenshotBannerAutoDismissTimer() {
        // Invalidate existing timer
        autoDismissTimer?.invalidate()
        
        // Create new timer (15 seconds for screenshot banners)
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.dismissBanner(animated: true)
        }
    }
}
