//
//  FeatureFlags.swift
//  TypeSafeKeyboard
//
//  Story 12.1: Feature Flag System
//  Controls feature availability via persistent configuration
//

import Foundation

/// Centralized feature flag system for controlling feature availability
/// Features can be toggled without code changes via SharedStorageManager
class FeatureFlags {

    // MARK: - Singleton

    /// Shared instance for accessing feature flags
    static let shared = FeatureFlags()

    /// Private initializer to enforce singleton pattern
    private init() {}

    // MARK: - Dependencies

    /// Storage manager for persisting feature flags
    private let storageManager = SharedStorageManager.shared

    // MARK: - Feature Flags

    /// Controls whether text analysis feature is active
    /// Default: false (feature disabled/shelved)
    var isAnalyseTextEnabled: Bool {
        get {
            return storageManager.getFeatureFlagEnabled("analyse_text")
        }
        set {
            storageManager.setFeatureFlagEnabled("analyse_text", newValue)
            print("FeatureFlags: Analyse Text feature \(newValue ? "enabled" : "disabled")")
        }
    }

    // MARK: - Utility Methods

    /// Returns default state for Analyse Text feature
    /// - Returns: Default state (false = disabled)
    func getDefaultAnalyseTextState() -> Bool {
        return false
    }

    /// Resets all feature flags to default values
    func resetToDefaults() {
        isAnalyseTextEnabled = getDefaultAnalyseTextState()
        print("FeatureFlags: Reset all flags to defaults")
    }

    /// Logs current state of all feature flags (for debugging)
    func logCurrentState() {
        print("FeatureFlags: Current State:")
        print("  - isAnalyseTextEnabled: \(isAnalyseTextEnabled)")
    }
}
