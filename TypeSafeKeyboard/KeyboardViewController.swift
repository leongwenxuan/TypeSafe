//
//  KeyboardViewController.swift
//  TypeSafeKeyboard
//
//  Created by Daniel on 18/10/25.
//

import UIKit

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
    
    // Performance optimization caches (Story 2.9)
    private var cachedShiftButton: UIButton?
    private var cachedKeyboardAppearance: UIKeyboardAppearance?
    private var layoutCache: [KeyboardLayout: UIView] = [:]
    
    // Snippet management (Story 2.2)
    private let snippetManager = TextSnippetManager()
    private let secureDetector = SecureTextDetector()
    
    // Backend API integration (Story 2.3)
    private let apiService = APIService()
    
    // Banner management (Story 2.4)
    private var currentBanner: RiskAlertBannerView?
    private var autoDismissTimer: Timer?
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    
    // Popover management (Story 2.6)
    private var currentPopover: ExplainWhyPopoverView?
    
    // Shared state management (Story 2.7)
    private let sharedStorageManager = SharedStorageManager()
    
    // Privacy message management (Story 2.8)
    private var privacyMessageView: PrivacyMessageView?
    
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
        
        print("KeyboardViewController: Full Access status detected: \(hasAccess)")
        return hasAccess
    }
    
    /// Invalidates the cached Full Access status (call when permissions might have changed)
    private func invalidateFullAccessCache() {
        _cachedFullAccessStatus = nil
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("KeyboardViewController: viewDidLoad called")
        
        // Invalidate Full Access cache on fresh load (Story 2.8)
        invalidateFullAccessCache()
        
        setupKeyboard()
        
        // Initialize haptic feedback generator if Full Access enabled (Story 2.4)
        if hasFullAccessPermission {
            feedbackGenerator = UIImpactFeedbackGenerator()
            feedbackGenerator?.prepare()
        }
        
        print("KeyboardViewController: setup completed")
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        print("KeyboardViewController: viewWillLayoutSubviews called")
        
        // Only create height constraint once to avoid conflicts
        if heightConstraint == nil {
            print("KeyboardViewController: Creating height constraint")
            // Adjusted height to match actual content: 38+38+38+32 + 3*3 spacing + 3+3 padding = 155pt
            // Add 60pt for banner above keyboard (Story 2.6): 224 + 60 = 284pt
            heightConstraint = view.heightAnchor.constraint(equalToConstant: 284)
            heightConstraint?.priority = UILayoutPriority(999) // Slightly less than required
            heightConstraint?.isActive = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Clean up banner and timer when keyboard is dismissed (Story 2.4)
        dismissBanner(animated: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Performance optimization: Clear caches on memory warning (Story 2.9)
        clearPerformanceCaches()
        print("KeyboardViewController: Memory warning - cleared performance caches")
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Update UI based on keyboard appearance (light/dark mode)
        updateAppearance()
        
        // Clear snippet buffer on field change (Story 2.2)
        snippetManager.clear()
        print("KeyboardViewController: Snippet buffer cleared due to field change")
        
        // Story 2.8: Invalidate secure field detection cache on field change
        secureDetector.invalidateCache()
        
        // Dismiss banner on field change to prevent context leakage (Story 2.4)
        dismissBanner(animated: true)
    }
    
    // MARK: - Setup
    private func setupKeyboard() {
        print("KeyboardViewController: setupKeyboard started")
        
        // Performance optimization: Clear caches when recreating keyboard (Story 2.9)
        clearPerformanceCaches()
        
        // Clean up any existing views (Full Access recreation)
        view.subviews.forEach { $0.removeFromSuperview() }
        keyboardView = nil
        heightConstraint = nil
        
        // Create main container
        keyboardView = UIView()
        keyboardView.backgroundColor = UIColor.systemBackground
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        
        // Setup constraints for keyboard view (positioned below banner area)
        NSLayoutConstraint.activate([
            keyboardView.leftAnchor.constraint(equalTo: view.leftAnchor),
            keyboardView.rightAnchor.constraint(equalTo: view.rightAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor, constant: 60), // Leave 60pt for banner
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("KeyboardViewController: keyboardView setup completed")
        
        // Story 2.8: Show privacy message if Full Access is disabled
        setupPrivacyMessage()
        
        createKeyboardLayout()
        print("KeyboardViewController: layout creation completed")
        updateAppearance()
        print("KeyboardViewController: appearance update completed")
    }
    
    private func createKeyboardLayout() {
        print("KeyboardViewController: createKeyboardLayout started (layout: \(currentLayout))")
        
        // Performance optimization: Use cached layout if available (Story 2.9)
        if let cachedLayout = layoutCache[currentLayout] {
            print("KeyboardViewController: Using cached layout for \(currentLayout)")
            
            // Clean up existing keyboard layout views
            keyboardView.subviews.forEach { $0.removeFromSuperview() }
            
            // Add cached layout
            keyboardView.addSubview(cachedLayout)
            
            // Setup constraints for cached layout
            NSLayoutConstraint.activate([
                cachedLayout.leftAnchor.constraint(equalTo: keyboardView.leftAnchor),
                cachedLayout.rightAnchor.constraint(equalTo: keyboardView.rightAnchor),
                cachedLayout.topAnchor.constraint(equalTo: keyboardView.topAnchor),
                cachedLayout.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor)
            ])
            
            // Update appearance for cached layout
            updateAppearanceForLayout(cachedLayout)
            
            print("KeyboardViewController: Cached layout applied")
            return
        }
        
        // Clean up existing keyboard layout views
        keyboardView.subviews.forEach { $0.removeFromSuperview() }
        
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
        
        print("KeyboardViewController: Layout creation completed and cached")
    }
    
    private func createLetterLayout() {
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = 3
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor, constant: 3),
            mainStackView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor, constant: -3),
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: 3),
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -3)
        ])
        
        // Row 1: Q W E R T Y U I O P
        let row1 = createKeyRow(keys: ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"])
        row1.heightAnchor.constraint(equalToConstant: 38).isActive = true
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: A S D F G H J K L (with side padding)
        let row2Container = UIView()
        row2Container.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let row2 = createKeyRow(keys: ["A", "S", "D", "F", "G", "H", "J", "K", "L"])
        row2.translatesAutoresizingMaskIntoConstraints = false
        row2Container.addSubview(row2)
        
        NSLayoutConstraint.activate([
            row2.centerXAnchor.constraint(equalTo: row2Container.centerXAnchor),
            row2.topAnchor.constraint(equalTo: row2Container.topAnchor),
            row2.bottomAnchor.constraint(equalTo: row2Container.bottomAnchor),
            row2.widthAnchor.constraint(equalTo: row2Container.widthAnchor, multiplier: 0.9)
        ])
        mainStackView.addArrangedSubview(row2Container)
        
        // Row 3: Shift + Z X C V B N M + Backspace
        let row3 = createRow3()
        row3.heightAnchor.constraint(equalToConstant: 38).isActive = true
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: 123 + Next Keyboard + Space + Return
        let row4 = createRow4()
        row4.heightAnchor.constraint(equalToConstant: 32).isActive = true
        mainStackView.addArrangedSubview(row4)
        
        print("KeyboardViewController: Letter layout created")
    }
    
    private func createNumberLayout() {
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = 3
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor, constant: 3),
            mainStackView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor, constant: -3),
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: 3),
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -3)
        ])
        
        // Row 1: 1 2 3 4 5 6 7 8 9 0
        let row1 = createKeyRow(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        row1.heightAnchor.constraint(equalToConstant: 38).isActive = true
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: - / : ; ( ) $ & @ "
        let row2 = createKeyRow(keys: ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""])
        row2.heightAnchor.constraint(equalToConstant: 38).isActive = true
        mainStackView.addArrangedSubview(row2)
        
        // Row 3: #+= button + . , ? ! ' + Backspace
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = 4
        row3.heightAnchor.constraint(equalToConstant: 38).isActive = true
        
        let symbolModeButton = createKeyButton(title: "#+=", action: #selector(symbolModeTapped))
        symbolModeButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(symbolModeButton)
        
        let punctuationKeys = createKeyRow(keys: [".", ",", "?", "!", "'"])
        row3.addArrangedSubview(punctuationKeys)
        
        let backspaceButton = createKeyButton(title: "⌫", action: #selector(backspaceTapped))
        backspaceButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(backspaceButton)
        
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: ABC + Globe + Space + Return
        let row4 = UIStackView()
        row4.axis = .horizontal
        row4.spacing = 6
        row4.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        let abcButton = createKeyButton(title: "ABC", action: #selector(letterModeTapped))
        abcButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        row4.addArrangedSubview(abcButton)
        
        let nextKeyboardButton = createKeyButton(title: "🌐", action: #selector(handleInputModeList(from:with:)))
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if !needsInputModeSwitchKey {
            nextKeyboardButton.isHidden = true
        }
        row4.addArrangedSubview(nextKeyboardButton)
        
        let spaceButton = createKeyButton(title: "space", action: #selector(spaceTapped))
        row4.addArrangedSubview(spaceButton)
        
        let returnButton = createKeyButton(title: "return", action: #selector(returnTapped))
        returnButton.widthAnchor.constraint(equalToConstant: 67).isActive = true
        row4.addArrangedSubview(returnButton)
        
        mainStackView.addArrangedSubview(row4)
        
        print("KeyboardViewController: Number layout created")
    }
    
    private func createSymbolLayout() {
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = 3
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor, constant: 3),
            mainStackView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor, constant: -3),
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: 3),
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -3)
        ])
        
        // Row 1: [ ] { } # % ^ * + =
        let row1 = createKeyRow(keys: ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
        row1.heightAnchor.constraint(equalToConstant: 38).isActive = true
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: _ \ | ~ < > $ £ ¥ •
        let row2 = createKeyRow(keys: ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"])
        row2.heightAnchor.constraint(equalToConstant: 38).isActive = true
        mainStackView.addArrangedSubview(row2)
        
        // Row 3: 123 button + . , ? ! ' + Backspace
        let row3 = UIStackView()
        row3.axis = .horizontal
        row3.spacing = 4
        row3.heightAnchor.constraint(equalToConstant: 38).isActive = true
        
        let numberModeButton = createKeyButton(title: "123", action: #selector(numberModeTapped))
        numberModeButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(numberModeButton)
        
        let punctuationKeys = createKeyRow(keys: [".", ",", "?", "!", "'"])
        row3.addArrangedSubview(punctuationKeys)
        
        let backspaceButton = createKeyButton(title: "⌫", action: #selector(backspaceTapped))
        backspaceButton.widthAnchor.constraint(equalToConstant: 45).isActive = true
        row3.addArrangedSubview(backspaceButton)
        
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: ABC + Globe + Space + Return
        let row4 = UIStackView()
        row4.axis = .horizontal
        row4.spacing = 6
        row4.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        let abcButton = createKeyButton(title: "ABC", action: #selector(letterModeTapped))
        abcButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        row4.addArrangedSubview(abcButton)
        
        let nextKeyboardButton = createKeyButton(title: "🌐", action: #selector(handleInputModeList(from:with:)))
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        if !needsInputModeSwitchKey {
            nextKeyboardButton.isHidden = true
        }
        row4.addArrangedSubview(nextKeyboardButton)
        
        let spaceButton = createKeyButton(title: "space", action: #selector(spaceTapped))
        row4.addArrangedSubview(spaceButton)
        
        let returnButton = createKeyButton(title: "return", action: #selector(returnTapped))
        returnButton.widthAnchor.constraint(equalToConstant: 67).isActive = true
        row4.addArrangedSubview(returnButton)
        
        mainStackView.addArrangedSubview(row4)
        
        print("KeyboardViewController: Symbol layout created")
    }
    
    private func createKeyRow(keys: [String]) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 4 // Reduced spacing between keys
        
        for key in keys {
            let button = createKeyButton(title: key, action: #selector(keyTapped(_:)))
            stackView.addArrangedSubview(button)
        }
        
        return stackView
    }
    
    private func createRow3() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4 // Reduced spacing
        
        // Shift button
        let shiftButton = createKeyButton(title: "⇧", action: #selector(shiftTapped))
        stackView.addArrangedSubview(shiftButton)
        
        // Letter keys
        let letterKeys = createKeyRow(keys: ["Z", "X", "C", "V", "B", "N", "M"])
        stackView.addArrangedSubview(letterKeys)
        
        // Backspace button
        let backspaceButton = createKeyButton(title: "⌫", action: #selector(backspaceTapped))
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
        stackView.spacing = 6 // Increased spacing for bottom row to match Apple's layout
        
        // 123 button (number mode toggle)
        let numberButton = createKeyButton(title: "123", action: #selector(numberModeTapped))
        stackView.addArrangedSubview(numberButton)
        
        // Next Keyboard button (globe icon)
        let nextKeyboardButton = createKeyButton(title: "🌐", action: #selector(handleInputModeList(from:with:)))
        if !needsInputModeSwitchKey {
            nextKeyboardButton.isHidden = true
        }
        stackView.addArrangedSubview(nextKeyboardButton)
        
        // Space bar
        let spaceButton = createKeyButton(title: "space", action: #selector(spaceTapped))
        stackView.addArrangedSubview(spaceButton)
        
        // Return button
        let returnButton = createKeyButton(title: "return", action: #selector(returnTapped))
        stackView.addArrangedSubview(returnButton)
        
        // Set width constraints after adding to stack view - reduced sizes for tighter layout
        numberButton.widthAnchor.constraint(equalToConstant: 42).isActive = true // Reduced from 55
        nextKeyboardButton.widthAnchor.constraint(equalTo: numberButton.widthAnchor).isActive = true
        returnButton.widthAnchor.constraint(equalToConstant: 67).isActive = true // Reduced from 75
        
        return stackView
    }
    
    private func createKeyButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .regular) // Slightly smaller font
        button.layer.cornerRadius = 6 // More rounded corners like Apple keyboard
        button.layer.borderWidth = 0 // Remove border for cleaner look
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Add shadow for depth (like Apple keyboard)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.15
        button.layer.shadowRadius = 0
        
        return button
    }
    
    // MARK: - Optimized Layout Creation (Story 2.9)
    
    /// Creates optimized letter layout that returns a view for caching
    private func createLetterLayoutOptimized() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Reuse existing letter layout logic but return the container
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.spacing = 3
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 3),
            mainStackView.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -3),
            mainStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 3),
            mainStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -3)
        ])
        
        // Row 1: Q W E R T Y U I O P
        let row1 = createKeyRow(keys: ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"])
        row1.heightAnchor.constraint(equalToConstant: 38).isActive = true
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: A S D F G H J K L (with side padding)
        let row2Container = UIView()
        row2Container.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let row2 = createKeyRow(keys: ["A", "S", "D", "F", "G", "H", "J", "K", "L"])
        row2.translatesAutoresizingMaskIntoConstraints = false
        row2Container.addSubview(row2)
        
        NSLayoutConstraint.activate([
            row2.centerXAnchor.constraint(equalTo: row2Container.centerXAnchor),
            row2.topAnchor.constraint(equalTo: row2Container.topAnchor),
            row2.bottomAnchor.constraint(equalTo: row2Container.bottomAnchor),
            row2.widthAnchor.constraint(equalTo: row2Container.widthAnchor, multiplier: 0.9)
        ])
        mainStackView.addArrangedSubview(row2Container)
        
        // Row 3: Shift + Z X C V B N M + Backspace
        let row3 = createRow3()
        row3.heightAnchor.constraint(equalToConstant: 38).isActive = true
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: 123 + Next Keyboard + Space + Return
        let row4 = createRow4()
        row4.heightAnchor.constraint(equalToConstant: 32).isActive = true
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
        
        // Create number layout using existing logic
        createNumberLayout()
        
        // Return the created layout (simplified for now - could be further optimized)
        return keyboardView.subviews.first ?? containerView
    }
    
    /// Creates optimized symbol layout that returns a view for caching
    private func createSymbolLayoutOptimized() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create symbol layout using existing logic
        createSymbolLayout()
        
        // Return the created layout (simplified for now - could be further optimized)
        return keyboardView.subviews.first ?? containerView
    }
    
    /// Updates appearance for a specific layout view (Story 2.9)
    private func updateAppearanceForLayout(_ layoutView: UIView) {
        let isDark = textDocumentProxy.keyboardAppearance == .dark
        
        // Cache appearance to avoid repeated checks
        if cachedKeyboardAppearance == textDocumentProxy.keyboardAppearance {
            return // No change needed
        }
        cachedKeyboardAppearance = textDocumentProxy.keyboardAppearance
        
        // Background color for keyboard
        keyboardView.backgroundColor = isDark ? UIColor(white: 0.1, alpha: 1.0) : UIColor(white: 0.85, alpha: 1.0)
        
        // Update buttons in the layout
        if let mainStackView = layoutView.subviews.first as? UIStackView {
            updateStackViewButtons(mainStackView, isDark: isDark)
        }
    }
    
    // MARK: - Appearance
    private func updateAppearance() {
        guard let keyboardView = keyboardView else { return }
        
        let isDark = textDocumentProxy.keyboardAppearance == .dark
        
        // Background color for keyboard
        keyboardView.backgroundColor = isDark ? UIColor(white: 0.1, alpha: 1.0) : UIColor(white: 0.85, alpha: 1.0)
        
        // Update all buttons - find the main stack view
        if let mainStackView = keyboardView.subviews.first as? UIStackView {
            updateStackViewButtons(mainStackView, isDark: isDark)
        }
        
        // Story 2.8: Update privacy message appearance
        privacyMessageView?.updateAppearance(isDark: isDark)
    }
    
    private func updateStackViewButtons(_ stackView: UIStackView, isDark: Bool) {
        for view in stackView.arrangedSubviews {
            if let button = view as? UIButton {
                // Key background - using more Apple-like colors
                button.backgroundColor = isDark ? UIColor(white: 0.3, alpha: 1.0) : UIColor(white: 0.98, alpha: 1.0)
                // Key text
                button.setTitleColor(isDark ? .white : .black, for: .normal)
                // No border styling needed anymore
            } else if let nestedStack = view as? UIStackView {
                updateStackViewButtons(nestedStack, isDark: isDark)
            } else {
                // Handle container views
                for subview in view.subviews {
                    if let button = subview as? UIButton {
                        button.backgroundColor = isDark ? UIColor(white: 0.3, alpha: 1.0) : UIColor(white: 0.98, alpha: 1.0)
                        button.setTitleColor(isDark ? .white : .black, for: .normal)
                    } else if let nestedStack = subview as? UIStackView {
                        updateStackViewButtons(nestedStack, isDark: isDark)
                    }
                }
            }
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
        if let mainStackView = keyboardView.subviews.first as? UIStackView {
            updateShiftButton(in: mainStackView)
        }
    }
    
    // Performance optimized version that uses cached shift button (Story 2.9)
    private func updateShiftStateOptimized() {
        // Use cached shift button if available
        if let cachedButton = cachedShiftButton {
            updateSingleShiftButton(cachedButton)
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
    
    // Optimized method to update a single shift button (Story 2.9)
    private func updateSingleShiftButton(_ button: UIButton) {
        let isDark = textDocumentProxy.keyboardAppearance == .dark
        button.backgroundColor = isShifted ? 
            (isDark ? UIColor(white: 0.5, alpha: 1.0) : UIColor(white: 0.8, alpha: 1.0)) : 
            (isDark ? UIColor(white: 0.3, alpha: 1.0) : UIColor(white: 0.98, alpha: 1.0))
    }
    
    @objc private func backspaceTapped() {
        textDocumentProxy.deleteBackward()
        
        // Update snippet buffer (Story 2.2)
        let wasModified = snippetManager.deleteLastCharacter()
        if wasModified {
            print("KeyboardViewController: Snippet buffer updated after backspace")
        }
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
        print("KeyboardViewController: Switched to number layout")
    }
    
    @objc private func symbolModeTapped() {
        currentLayout = .symbols
        createKeyboardLayout()
        updateAppearance()
        print("KeyboardViewController: Switched to symbol layout")
    }
    
    @objc private func letterModeTapped() {
        currentLayout = .letters
        createKeyboardLayout()
        updateAppearance()
        print("KeyboardViewController: Switched to letter layout")
    }
    
    // MARK: - Snippet Management (Story 2.2)
    
    /// Processes a typed character for snippet capture and analysis triggering
    /// - Parameter character: The character that was typed
    private func processCharacterForSnippet(_ character: String) {
        // Story 2.8: Skip text capture when Full Access is disabled (graceful degradation)
        guard hasFullAccessPermission else {
            return
        }
        
        // Check if current field is secure (password field)
        if secureDetector.isSecureField(textDocumentProxy) {
            return
        }
        
        // Append character and check for trigger
        if let snippet = snippetManager.append(character) {
            // Story 2.3: Send snippet to backend for analysis
            print("KeyboardViewController: Analysis triggered!")
            print("  - Reason: \(snippet.triggerReason)")
            print("  - Content length: \(snippet.content.count) chars")
            print("  - Preview: \(String(snippet.content.prefix(50)))...")
            
            // Call backend API (non-blocking, async)
            analyzeSnippet(snippet.content)
        }
    }
    
    /// Sends text snippet to backend for scam analysis
    /// - Parameter text: Text content to analyze
    private func analyzeSnippet(_ text: String) {
        // Story 2.8: Check Full Access permission before making API calls
        guard hasFullAccessPermission else {
            print("KeyboardViewController: API call skipped - Full Access required")
            return
        }
        
        // Story 2.7: Update analysis timestamp
        sharedStorageManager.updateLastAnalysisTimestamp()
        
        apiService.analyzeText(text: text) { result in
            switch result {
            case .success(let response):
                print("KeyboardViewController: Received analysis result")
                print("  - Risk level: \(response.risk_level)")
                print("  - Confidence: \(response.confidence)")
                print("  - Category: \(response.category)")
                print("  - Explanation: \(response.explanation)")
                
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
                print("KeyboardViewController: API call failed: \(error.localizedDescription)")
                // Keyboard continues to function normally
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
            print("KeyboardViewController: Banners disabled in preferences")
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
            print("KeyboardViewController: Risk level '\(response.risk_level)' below threshold '\(riskThreshold)' - no banner shown")
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
            
            // Setup Auto Layout constraints (banner positioned in top 60pt area)
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: self.view.topAnchor),
                banner.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                banner.heightAnchor.constraint(equalToConstant: 60)
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
            
            print("KeyboardViewController: Banner displayed for \(response.risk_level) risk")
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
        print("KeyboardViewController: Banner dismissed")
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
            print("KeyboardViewController: Haptic skipped (Full Access required)")
            return
        }
        
        // Story 2.7: Check haptic preferences from shared storage
        let alertPreferences = sharedStorageManager.getAlertPreferences()
        guard alertPreferences.enableHapticFeedback else {
            print("KeyboardViewController: Haptic feedback disabled in preferences")
            return
        }
        
        // Select impact style based on risk level
        let style: UIImpactFeedbackGenerator.FeedbackStyle = riskLevel == .high ? .heavy : .medium
        
        // Create generator with appropriate style
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        
        print("KeyboardViewController: Haptic feedback triggered (\(style))")
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
        
        print("KeyboardViewController: Explain why popover shown for \(response.category)")
    }
    
    /// Dismisses the current explain why popover
    private func dismissExplainWhyPopover() {
        guard let popover = currentPopover else { return }
        
        popover.dismiss()
        currentPopover = nil
        
        print("KeyboardViewController: Explain why popover dismissed")
    }
    
    // MARK: - Privacy Message Management (Story 2.8)
    
    /// Sets up privacy message display when Full Access is disabled
    private func setupPrivacyMessage() {
        // Remove existing privacy message
        privacyMessageView?.removeFromSuperview()
        privacyMessageView = nil
        
        // Only show privacy message if Full Access is disabled
        guard !hasFullAccessPermission else {
            print("KeyboardViewController: Full Access enabled - no privacy message needed")
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
        
        print("KeyboardViewController: Privacy message displayed - Full Access required")
    }
    
    /// Opens iOS Settings to keyboard configuration
    private func openKeyboardSettings() {
        print("KeyboardViewController: Attempting to open keyboard settings")
        
        // Try to open Settings app with deep link to keyboard settings
        if let settingsUrl = URL(string: "App-Prefs:General&path=Keyboard") {
            // Note: This may not work in all iOS versions due to security restrictions
            // The keyboard extension has limited ability to open external URLs
            print("KeyboardViewController: Settings deep link not available from keyboard extension")
        }
        
        // Since direct deep linking is restricted, we'll show an instructional message
        // This could be enhanced with a more detailed instruction popover in the future
        print("KeyboardViewController: User should manually navigate to Settings > General > Keyboard > TypeSafe")
    }
    
    /// Dismisses the privacy message
    private func dismissPrivacyMessage() {
        privacyMessageView?.removeFromSuperview()
        privacyMessageView = nil
        print("KeyboardViewController: Privacy message dismissed")
    }
    
    // MARK: - Performance Cache Management (Story 2.9)
    
    /// Clears all performance caches to free memory
    private func clearPerformanceCaches() {
        layoutCache.removeAll()
        cachedShiftButton = nil
        cachedKeyboardAppearance = nil
        print("KeyboardViewController: Performance caches cleared")
    }
}
