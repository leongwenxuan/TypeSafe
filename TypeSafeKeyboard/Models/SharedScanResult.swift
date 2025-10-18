//
//  SharedScanResult.swift
//  TypeSafeKeyboard
//
//  Story 3.7: App Group Integration & Keyboard Sync
//  Shared data model for screenshot scan results between app and keyboard
//

import Foundation

/// Privacy-safe scan result data for sharing between companion app and keyboard extension
/// Contains only metadata required for banner display, no sensitive content
struct SharedScanResult: Codable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for deduplication and tracking
    let scanId: String
    
    /// Risk level assessment: "low", "medium", "high"
    let riskLevel: String
    
    /// Category of detected risk (e.g., "OTP Phishing", "Payment Scam")
    let category: String
    
    /// Confidence score from 0.0 to 1.0
    let confidence: Double
    
    /// When the scan was completed
    let timestamp: Date
    
    /// Whether keyboard has displayed this result yet
    let isNew: Bool
    
    // MARK: - Validation
    
    /// Validates that the scan result contains only privacy-safe data
    var isPrivacySafe: Bool {
        // Validate risk level
        let validRiskLevels = ["low", "medium", "high", "none"]
        guard validRiskLevels.contains(riskLevel.lowercased()) else {
            return false
        }
        
        // Validate confidence range
        guard confidence >= 0.0 && confidence <= 1.0 else {
            return false
        }
        
        // Validate category is reasonable length (no raw text)
        guard category.count <= 50 else {
            return false
        }
        
        // Validate scanId format (should be UUID-like)
        guard !scanId.isEmpty && scanId.count <= 50 else {
            return false
        }
        
        return true
    }
    
    /// Estimated size in bytes for privacy compliance checking
    var estimatedSize: Int {
        return scanId.utf8.count +
               riskLevel.utf8.count +
               category.utf8.count +
               8 + // Double (confidence)
               8 + // Date (timestamp)
               1   // Bool (isNew)
    }
    
    // MARK: - Convenience Initializers
    
    /// Creates a new SharedScanResult with automatic UUID generation
    /// - Parameters:
    ///   - riskLevel: Risk level assessment
    ///   - category: Category of detected risk
    ///   - confidence: Confidence score (0.0 to 1.0)
    ///   - timestamp: When scan was completed (defaults to now)
    ///   - isNew: Whether result is new (defaults to true)
    init(riskLevel: String, category: String, confidence: Double, timestamp: Date = Date(), isNew: Bool = true) {
        self.scanId = UUID().uuidString
        self.riskLevel = riskLevel
        self.category = category
        self.confidence = confidence
        self.timestamp = timestamp
        self.isNew = isNew
    }
    
    /// Creates a SharedScanResult with explicit scanId (for testing or specific use cases)
    /// - Parameters:
    ///   - scanId: Unique identifier
    ///   - riskLevel: Risk level assessment
    ///   - category: Category of detected risk
    ///   - confidence: Confidence score (0.0 to 1.0)
    ///   - timestamp: When scan was completed
    ///   - isNew: Whether result is new
    init(scanId: String, riskLevel: String, category: String, confidence: Double, timestamp: Date, isNew: Bool) {
        self.scanId = scanId
        self.riskLevel = riskLevel
        self.category = category
        self.confidence = confidence
        self.timestamp = timestamp
        self.isNew = isNew
    }
    
    // MARK: - Utility Methods
    
    /// Creates a copy of this result marked as read (isNew = false)
    /// - Returns: New SharedScanResult with isNew set to false
    func markAsRead() -> SharedScanResult {
        return SharedScanResult(
            scanId: scanId,
            riskLevel: riskLevel,
            category: category,
            confidence: confidence,
            timestamp: timestamp,
            isNew: false
        )
    }
    
    /// Checks if this scan result is older than the specified time interval
    /// - Parameter timeInterval: Time interval in seconds
    /// - Returns: True if result is older than the interval
    func isOlderThan(_ timeInterval: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) > timeInterval
    }
    
    /// Formatted string for banner display
    var bannerMessage: String {
        let capitalizedRiskLevel = riskLevel.capitalized
        return "Latest scan: \(capitalizedRiskLevel) Risk - \(category)"
    }
}

// MARK: - Extensions

extension SharedScanResult {
    
    /// Predefined risk categories for validation
    static let validCategories = [
        "OTP Phishing",
        "Payment Scam",
        "Identity Theft",
        "Financial Fraud",
        "Social Engineering",
        "Malware Link",
        "Suspicious Content",
        "Unknown Risk"
    ]
    
    /// Predefined risk levels for validation
    static let validRiskLevels = ["low", "medium", "high", "none"]
    
    /// Creates a sample SharedScanResult for testing
    static func sample(riskLevel: String = "medium", category: String = "OTP Phishing") -> SharedScanResult {
        return SharedScanResult(
            riskLevel: riskLevel,
            category: category,
            confidence: 0.85
        )
    }
}
