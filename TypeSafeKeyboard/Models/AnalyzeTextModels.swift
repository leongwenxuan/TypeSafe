//
//  AnalyzeTextModels.swift
//  TypeSafeKeyboard
//
//  Story 2.3: Backend API Integration
//  Request/Response models for /analyze-text endpoint
//

import Foundation

/// Request payload for POST /analyze-text endpoint
///
/// Example JSON:
/// ```json
/// {
///   "session_id": "550e8400-e29b-41d4-a716-446655440000",
///   "app_bundle": "com.whatsapp",
///   "text": "send me your OTP"
/// }
/// ```
struct AnalyzeTextRequest: Codable {
    /// Anonymous session identifier (UUID)
    let session_id: String
    
    /// Host app bundle ID (e.g., "com.whatsapp") or "unknown"
    let app_bundle: String
    
    /// Text snippet to analyze (max 300 characters from snippet manager)
    let text: String
}

/// Response payload from POST /analyze-text endpoint
///
/// Example JSON:
/// ```json
/// {
///   "risk_level": "high",
///   "confidence": 0.93,
///   "category": "otp_phishing",
///   "explanation": "Asking for OTP."
/// }
/// ```
struct AnalyzeTextResponse: Codable {
    /// Risk classification: "low", "medium", or "high"
    let risk_level: String
    
    /// Confidence score from 0.0 to 1.0
    let confidence: Double
    
    /// Scam category: "otp_phishing", "payment_scam", "impersonation", or "unknown"
    let category: String
    
    /// Human-friendly explanation (one-liner)
    let explanation: String
    
    /// Optional ISO-8601 timestamp from backend
    let ts: String?
}

