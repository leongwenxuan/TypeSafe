//
//  KeyboardKeyButton.swift
//  TypeSafeKeyboard
//
//  Custom key button tuned for low-latency keyboard interactions.
//

import UIKit

final class KeyboardKeyButton: UIButton {
    
    // MARK: - Properties
    var keyCornerRadius: CGFloat = 6 {
        didSet {
            if keyCornerRadius != oldValue {
                layer.cornerRadius = keyCornerRadius
                setNeedsLayout()
            }
        }
    }
    
    private var cachedShadowBounds: CGRect = .zero
    
    // MARK: - Initialization
    
    init() {
        super.init(frame: .zero)
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    private func configure() {
        layer.cornerRadius = keyCornerRadius
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 0
        adjustsImageWhenHighlighted = false
        isExclusiveTouch = true
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Cache shadow path to avoid expensive off-screen rendering when tapping quickly.
        if bounds.integral != cachedShadowBounds {
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: keyCornerRadius
            ).cgPath
            cachedShadowBounds = bounds.integral
        }
    }
    
    // MARK: - Styling Helpers
    
    func applyColors(background: UIColor, textColor: UIColor) {
        if self.backgroundColor != background {
            self.backgroundColor = background
        }
        
        if self.titleColor(for: .normal) != textColor {
            setTitleColor(textColor, for: .normal)
        }
    }
}
