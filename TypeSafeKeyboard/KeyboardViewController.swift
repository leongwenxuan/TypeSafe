//
//  KeyboardViewController.swift
//  TypeSafeKeyboard
//
//  Created by Daniel on 18/10/25.
//

import UIKit

class KeyboardViewController: UIInputViewController {
    
    // MARK: - Properties
    private var keyboardView: UIView!
    private var isShifted = false
    private var isNumberMode = false
    private var heightConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("KeyboardViewController: viewDidLoad called")
        setupKeyboard()
        print("KeyboardViewController: setup completed")
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        print("KeyboardViewController: viewWillLayoutSubviews called")
        
        // Only create height constraint once to avoid conflicts
        if heightConstraint == nil {
            print("KeyboardViewController: Creating height constraint")
            // Adjusted height to match actual content: 38+38+38+32 + 3*3 spacing + 3+3 padding = 155pt
            heightConstraint = view.heightAnchor.constraint(equalToConstant: 164)
            heightConstraint?.isActive = true
        }
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Update UI based on keyboard appearance (light/dark mode)
        updateAppearance()
    }
    
    // MARK: - Setup
    private func setupKeyboard() {
        print("KeyboardViewController: setupKeyboard started")
        
        // Create main container
        keyboardView = UIView()
        keyboardView.backgroundColor = UIColor.systemBackground
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        
        // Setup constraints for keyboard view
        NSLayoutConstraint.activate([
            keyboardView.leftAnchor.constraint(equalTo: view.leftAnchor),
            keyboardView.rightAnchor.constraint(equalTo: view.rightAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("KeyboardViewController: keyboardView setup completed")
        createKeyboardLayout()
        print("KeyboardViewController: layout creation completed")
        updateAppearance()
        print("KeyboardViewController: appearance update completed")
    }
    
    private func createKeyboardLayout() {
        print("KeyboardViewController: createKeyboardLayout started")
        
        // Main stack view to hold all rows
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill // Changed from .fillEqually to .fill for better control
        mainStackView.spacing = 3 // Further reduced spacing between rows
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.leftAnchor.constraint(equalTo: keyboardView.leftAnchor, constant: 3),
            mainStackView.rightAnchor.constraint(equalTo: keyboardView.rightAnchor, constant: -3),
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: 3), // Further reduced top padding
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -3) // Further reduced bottom padding
        ])
        
        // Row 1: Q W E R T Y U I O P
        let row1 = createKeyRow(keys: ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"])
        row1.heightAnchor.constraint(equalToConstant: 38).isActive = true // Reduced height
        mainStackView.addArrangedSubview(row1)
        
        // Row 2: A S D F G H J K L (with side padding)
        let row2Container = UIView()
        row2Container.heightAnchor.constraint(equalToConstant: 38).isActive = true // Reduced height
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
        row3.heightAnchor.constraint(equalToConstant: 38).isActive = true // Reduced height
        mainStackView.addArrangedSubview(row3)
        
        // Row 4: 123 + Next Keyboard + Space + Return
        let row4 = createRow4()
        row4.heightAnchor.constraint(equalToConstant: 32).isActive = true // Reduced height for bottom row
        mainStackView.addArrangedSubview(row4)
        
        print("KeyboardViewController: Full keyboard layout created")
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
        guard let key = sender.title(for: .normal) else { return }
        
        let character = isShifted ? key.uppercased() : key.lowercased()
        textDocumentProxy.insertText(character)
        
        // Auto-disable shift after typing one character (unless caps lock is implemented)
        if isShifted {
            isShifted = false
            updateShiftState()
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
    
    private func updateShiftButton(in stackView: UIStackView) {
        for view in stackView.arrangedSubviews {
            if let button = view as? UIButton, button.title(for: .normal) == "⇧" {
                let isDark = textDocumentProxy.keyboardAppearance == .dark
                button.backgroundColor = isShifted ? 
                    (isDark ? UIColor(white: 0.5, alpha: 1.0) : UIColor(white: 0.8, alpha: 1.0)) : 
                    (isDark ? UIColor(white: 0.3, alpha: 1.0) : UIColor(white: 0.98, alpha: 1.0))
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
    
    @objc private func backspaceTapped() {
        textDocumentProxy.deleteBackward()
    }
    
    @objc private func spaceTapped() {
        textDocumentProxy.insertText(" ")
    }
    
    @objc private func returnTapped() {
        textDocumentProxy.insertText("\n")
    }
    
    @objc private func numberModeTapped() {
        // Number mode toggle - not implemented in this basic version
        // Will be implemented in future stories if needed
    }
}
