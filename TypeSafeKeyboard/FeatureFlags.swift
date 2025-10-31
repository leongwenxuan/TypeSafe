//
//  FeatureFlags.swift
//  TypeSafeKeyboard
//
//  Lightweight feature flag access limited to the keyboard extension.
//

import Foundation

/// Central access point for keyboard feature flags.
struct FeatureFlags {
    static let shared = FeatureFlags()
    private let defaults = UserDefaults(suiteName: "group.com.typesafe.app")
    private let keyboardUsabilityKey = "keyboard_usability_v2_enabled"

    /// Flag gate for the Keyboard Usability V2 layout experiments.
    var isKeyboardUsabilityV2Enabled: Bool {
        defaults?.bool(forKey: keyboardUsabilityKey) ?? false
    }
}
