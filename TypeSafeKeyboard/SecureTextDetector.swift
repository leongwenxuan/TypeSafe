//
//  SecureTextDetector.swift
//  TypeSafeKeyboard
//
//  Detects secure text entry fields (password fields) to prevent capturing sensitive data.
//

import UIKit

/// Detects if the current text field is a secure entry field (password, PIN, etc.)
class SecureTextDetector {
    
    // MARK: - Properties
    private var lastSecureFieldCheck: (result: Bool, timestamp: Date)?
    private let cacheTimeout: TimeInterval = 1.0 // Cache result for 1 second
    
    /// Checks if the current text field is a secure entry field
    /// - Parameter proxy: The text document proxy from the keyboard
    /// - Returns: true if field appears to be secure (password, PIN), false otherwise
    func isSecureField(_ proxy: UITextDocumentProxy) -> Bool {
        // Use cached result if recent (performance optimization)
        if let cached = lastSecureFieldCheck,
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return cached.result
        }
        
        let isSecure = performSecureFieldDetection(proxy)
        
        // Cache the result
        lastSecureFieldCheck = (result: isSecure, timestamp: Date())
        
        // Log detection for debugging (Story 2.8 requirement)
        if isSecure {
        }
        
        return isSecure
    }
    
    /// Performs the actual secure field detection logic
    /// - Parameter proxy: The text document proxy from the keyboard
    /// - Returns: true if field appears to be secure
    private func performSecureFieldDetection(_ proxy: UITextDocumentProxy) -> Bool {
        // Check 1: Text content type hints for passwords (most reliable)
        if let contentType = proxy.textContentType,
           let actualContentType = contentType {
            if isPasswordContentType(actualContentType) {
                return true
            }
        }
        
        // Check 2: Number pad keyboard type (common for PINs and secure codes)
        if proxy.keyboardType == .numberPad {
            return true
        }
        
        // Check 3: Phone pad keyboard type (sometimes used for secure entry)
        if proxy.keyboardType == .phonePad {
            return true
        }
        
        // Check 4: Context access limitation (heuristic for secure fields)
        if hasLimitedContextAccess(proxy) {
            return true
        }
        
        return false
    }
    
    /// Checks if the text content type indicates a password or secure field
    /// - Parameter contentType: The UITextContentType to check
    /// - Returns: true if it's a password-related content type
    private func isPasswordContentType(_ contentType: UITextContentType) -> Bool {
        return contentType == .password ||
               contentType == .newPassword ||
               contentType == .oneTimeCode ||
               contentType == .creditCardNumber ||
               contentType == .creditCardSecurityCode
    }
    
    /// Checks if the text field has limited context access (heuristic for secure fields)
    /// - Parameter proxy: The text document proxy from the keyboard
    /// - Returns: true if context access appears limited
    private func hasLimitedContextAccess(_ proxy: UITextDocumentProxy) -> Bool {
        // Secure fields often restrict access to surrounding text
        // This is a heuristic and can have false positives
        
        // Check if we can read text before/after cursor
        let textBefore = proxy.documentContextBeforeInput
        let textAfter = proxy.documentContextAfterInput
        
        // If both are nil or empty, it might be a secure field
        // However, this can also happen in empty fields, so we use additional checks
        let hasNoContext = (textBefore?.isEmpty ?? true) && (textAfter?.isEmpty ?? true)
        
        // Only consider it secure if we also can't get selected text
        let hasNoSelection = proxy.selectedText?.isEmpty ?? true
        
        return hasNoContext && hasNoSelection && proxy.hasText
    }
    
    /// Invalidates the cached secure field detection result
    /// Call this when the text field context might have changed
    func invalidateCache() {
        lastSecureFieldCheck = nil
    }
}

