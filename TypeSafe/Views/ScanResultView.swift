//
//  ScanResultView.swift
//  TypeSafe
//
//  Story 3.4: Backend Integration (Scan Image API)
//  Displays scam analysis results from backend
//

import SwiftUI

/// View for displaying scam analysis results from the backend
struct ScanResultView: View {
    
    // MARK: - Properties
    
    /// The analysis result from the backend
    let result: ScanImageResponse
    
    /// The original OCR text that was analyzed
    let analyzedText: String
    
    /// Callback for when user wants to scan another image
    let onScanAnother: () -> Void
    
    /// Callback for when user wants to go back to text editing
    let onEditText: () -> Void
    
    /// Callback for when user wants to save result to history
    let onSaveToHistory: () -> Void
    
    // MARK: - Computed Properties
    
    /// Risk level color based on the result
    private var riskColor: Color {
        switch result.risk_level?.lowercased() ?? "unknown" {
        case "high":
            return .red
        case "medium":
            return Color(red: 1.0, green: 0.75, blue: 0.0) // Amber color
        case "low":
            return .green
        default:
            return .gray
        }
    }
    
    /// Risk level icon based on the result
    private var riskIcon: String {
        switch result.risk_level?.lowercased() ?? "unknown" {
        case "high":
            return "exclamationmark.triangle.fill"
        case "medium":
            return "exclamationmark.circle.fill"
        case "low":
            return "checkmark.shield.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    /// Risk level title
    private var riskTitle: String {
        switch result.risk_level?.lowercased() ?? "unknown" {
        case "high":
            return "High Risk Detected"
        case "medium":
            return "Medium Risk Detected"
        case "low":
            return "Low Risk - Looks Safe"
        default:
            return "Analysis Complete"
        }
    }
    
    /// Formatted timestamp for display
    private var formattedTimestamp: String {
        guard let timestamp = result.ts else {
            return "Just now"
        }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: timestamp) else {
            return "Just now"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        
        return displayFormatter.string(from: date)
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Risk level indicator
                VStack(spacing: 16) {
                    Image(systemName: riskIcon)
                        .font(.system(size: 60))
                        .foregroundColor(riskColor)
                        .accessibilityLabel("Risk level: \(result.risk_level ?? "unknown")")
                    
                    Text(riskTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(riskColor)
                        .multilineTextAlignment(.center)
                }
                
                // Analysis details
                VStack(alignment: .leading, spacing: 16) {
                    // Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analysis")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(result.explanation ?? "Analysis completed")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Details section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            DetailRow(
                                label: "Risk Level",
                                value: (result.risk_level ?? "unknown").capitalized,
                                color: riskColor
                            )
                            
                            DetailRow(
                                label: "Confidence",
                                value: "\(Int((result.confidence ?? 0) * 100))%",
                                color: .primary
                            )
                            
                            DetailRow(
                                label: "Category",
                                value: (result.category ?? "unknown").replacingOccurrences(of: "_", with: " ").capitalized,
                                color: .primary
                            )
                            
                            DetailRow(
                                label: "Scanned",
                                value: formattedTimestamp,
                                color: .primary
                            )
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Analyzed text section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analyzed Text")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(analyzedText)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // Primary action - Scan another
                    Button(action: onScanAnother) {
                        HStack {
                            Image(systemName: "camera.circle.fill")
                            Text("Scan Another Image")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Scan another image")
                    
                    // Save to history action
                    Button(action: onSaveToHistory) {
                        HStack {
                            Image(systemName: "bookmark.circle.fill")
                            Text("Save to History")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Save result to history")
                    
                    // Secondary action - Edit text
                    Button(action: onEditText) {
                        HStack {
                            Image(systemName: "pencil.circle")
                            Text("Edit Text & Re-analyze")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Edit text and re-analyze")
                }
            }
            .padding()
        }
        .navigationTitle("Scan Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Detail Row Component

/// Component for displaying key-value pairs in the details section
private struct DetailRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ScanResultView(
            result: ScanImageResponse(
                type: "simple",
                risk_level: "high",
                confidence: 0.93,
                category: "otp_phishing",
                explanation: "This message is requesting an OTP (One-Time Password), which is a common phishing tactic used by scammers to gain access to your accounts.",
                ts: "2025-01-18T10:30:00Z",
                task_id: nil,
                ws_url: nil,
                estimated_time: nil,
                entities_found: nil
            ),
            analyzedText: "Please send me your OTP code for verification. Reply with the 6-digit code you received.",
            onScanAnother: {
                print("Scan another tapped")
            },
            onEditText: {
                print("Edit text tapped")
            },
            onSaveToHistory: {
                print("Save to history tapped")
            }
        )
    }
}

#Preview("Low Risk") {
    NavigationView {
        ScanResultView(
            result: ScanImageResponse(
                type: "simple",
                risk_level: "low",
                confidence: 0.95,
                category: "safe",
                explanation: "This appears to be a normal, legitimate message with no signs of scam or phishing attempts.",
                ts: "2025-01-18T10:30:00Z",
                task_id: nil,
                ws_url: nil,
                estimated_time: nil,
                entities_found: nil
            ),
            analyzedText: "Your order has been confirmed. Thank you for your purchase! You will receive a tracking number via email once your item ships.",
            onScanAnother: {
                print("Scan another tapped")
            },
            onEditText: {
                print("Edit text tapped")
            },
            onSaveToHistory: {
                print("Save to history tapped")
            }
        )
    }
}

#Preview("Medium Risk") {
    NavigationView {
        ScanResultView(
            result: ScanImageResponse(
                type: "simple",
                risk_level: "medium",
                confidence: 0.78,
                category: "payment_scam",
                explanation: "This message contains suspicious payment-related content that could be a scam attempt. Exercise caution.",
                ts: "2025-01-18T10:30:00Z",
                task_id: nil,
                ws_url: nil,
                estimated_time: nil,
                entities_found: nil
            ),
            analyzedText: "Urgent: Your account will be suspended unless you update your payment information immediately. Click here to verify your details.",
            onScanAnother: {
                print("Scan another tapped")
            },
            onEditText: {
                print("Edit text tapped")
            },
            onSaveToHistory: {
                print("Save to history tapped")
            }
        )
    }
}
