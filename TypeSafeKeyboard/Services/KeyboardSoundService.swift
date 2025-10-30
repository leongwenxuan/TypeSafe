//
//  KeyboardSoundService.swift
//  TypeSafeKeyboard
//
//  Epic 11: Keyboard Sound Feedback
//  Manages keyboard sound feedback for keyboard interactions
//

import UIKit
import AudioToolbox

/// Service for managing keyboard sounds across the keyboard
class KeyboardSoundService {
    
    // MARK: - Singleton
    
    static let shared = KeyboardSoundService()
    
    // MARK: - Properties
    
    /// System sound IDs for different key types
    private let lightClickSound: SystemSoundID = 1104  // Standard key click
    private let modifierClickSound: SystemSoundID = 1105  // Modifier/delete key click
    
    /// User preference for keyboard sounds (loaded from SharedStorageManager)
    private var isEnabled: Bool = true
    
    /// Shared storage manager for preferences
    private let sharedStorage = SharedStorageManager.shared
    
    // MARK: - Initialization
    
    private init() {
        loadUserPreference()
        observePreferenceChanges()
    }
    
    // MARK: - Public Methods
    
    /// Prepares the sound service (no-op, kept for API consistency)
    func prepare() {
        guard isEnabled else { return }
        print("✅ KeyboardSoundService: Ready")
    }
    
    /// Cleans up resources (no-op for sounds, kept for API consistency)
    func cleanup() {
        print("🧹 KeyboardSoundService: Cleaned up")
    }
    
    // MARK: - Sound Trigger Methods
    
    /// Plays light click sound (for standard keys: letters, numbers, symbols)
    func playLight() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(lightClickSound)
    }
    
    /// Plays modifier click sound (for modifiers and action keys: shift, delete, space, return)
    func playModifier() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(modifierClickSound)
    }
    
    /// Plays selection sound (for UI interactions: banner tap, toggle)
    func playSelection() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1104)  // Same as light click
    }
    
    /// Plays notification sound (for scan results and alerts)
    /// - Parameter type: Type of notification (.success, .warning, .error)
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        
        // Map notification types to sounds
        switch type {
        case .success:
            AudioServicesPlaySystemSound(1057)  // SMS received sound
        case .warning:
            AudioServicesPlaySystemSound(1053)  // Alert sound
        case .error:
            AudioServicesPlaySystemSound(1053)  // Alert sound
        @unknown default:
            AudioServicesPlaySystemSound(1104)  // Fallback to standard click
        }
    }
    
    // MARK: - Configuration
    
    /// Updates keyboard sounds enabled state
    /// - Parameter enabled: Whether keyboard sounds should be enabled
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        print("⚙️ KeyboardSoundService: Sounds \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Private Methods
    
    /// Loads user preference from SharedStorageManager
    private func loadUserPreference() {
        isEnabled = sharedStorage.getKeyboardSoundsEnabled()
        print("📱 KeyboardSoundService: User preference loaded - \(isEnabled ? "enabled" : "disabled")")
    }
    
    /// Observes preference changes from SharedStorageManager
    private func observePreferenceChanges() {
        NotificationCenter.default.addObserver(
            forName: .keyboardSoundsPreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let enabled = notification.object as? Bool else { return }
            
            self.setEnabled(enabled)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when keyboard sounds preference changes
    static let keyboardSoundsPreferenceChanged = Notification.Name("KeyboardSoundsPreferenceChanged")
}

