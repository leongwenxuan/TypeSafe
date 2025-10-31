//
//  KeyboardLayoutMetrics.swift
//  TypeSafeKeyboard
//
//  Story 14.1: Trait-driven layout metrics and feature flag
//

import UIKit

/// Central source of truth for keyboard layout metrics.
/// When the KeyboardUsabilityV2 flag is off, callers should ignore these values
/// and fall back to existing behavior.
struct KeyboardLayoutMetrics {

    struct Values {
        let rowHeight: CGFloat
        let bottomRowHeightDelta: CGFloat
        let interRowSpacing: CGFloat
        let interKeySpacing: CGFloat
        let bannerHeight: CGFloat
        let keyCornerRadius: CGFloat
        let labelFont: UIFont
        let outerHorizontalPadding: CGFloat
        let keyOuterInset: CGFloat
    }

    /// Returns metrics only when the feature flag is enabled; otherwise nil.
    static func enabledValues(for traits: UITraitCollection) -> Values? {
        guard FeatureFlags.shared.isKeyboardUsabilityV2Enabled else { return nil }
        return values(for: traits)
    }

    /// Compute metrics based on trait environment.
    /// Callers should prefer `enabledValues(for:)` to respect flag gating.
    static func values(for traits: UITraitCollection) -> Values {
        let isCompact = traits.horizontalSizeClass == .compact

        // Larger keys and slightly tighter gaps for better hit targets
        let rowHeight: CGFloat = isCompact ? 60 : 64
        let bottomRowHeightDelta: CGFloat = 10
        let interRowSpacing: CGFloat = 16
        let interKeySpacing: CGFloat = 6
        // Maximize key area by removing reserved banner space under V2
        let bannerHeight: CGFloat = 0
        let keyCornerRadius: CGFloat = 8
        let labelFont = UIFont.systemFont(ofSize: 24, weight: .regular)
        let outerHorizontalPadding: CGFloat = 4
        let keyOuterInset: CGFloat = 1

        return Values(
            rowHeight: rowHeight,
            bottomRowHeightDelta: bottomRowHeightDelta,
            interRowSpacing: interRowSpacing,
            interKeySpacing: interKeySpacing,
            bannerHeight: bannerHeight,
            keyCornerRadius: keyCornerRadius,
            labelFont: labelFont,
            outerHorizontalPadding: outerHorizontalPadding,
            keyOuterInset: keyOuterInset
        )
    }
}


