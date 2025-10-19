//
//  HistoryRowView.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import SwiftUI
import CoreData

/// Individual row view for displaying scan history items
struct HistoryRowView: View {
    /// The history item to display
    let item: ScanHistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Risk level indicator
            RiskLevelIndicator(riskLevel: item.riskLevel ?? "unknown")
            
            // Content section
            VStack(alignment: .leading, spacing: 4) {
                // Category and confidence
                HStack {
                    Text(item.category ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(item.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Truncated explanation
                Text(item.explanation ?? "No explanation available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Story 5.3: Enhanced scan source indicator with timestamp
                HStack(spacing: 8) {
                    // Scan source badge
                    if item.isAutoScanned {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("Auto-scanned")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                        .accessibilityLabel("Automatically scanned")
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text("Manual")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(4)
                        .accessibilityLabel("Manually selected")
                    }
                    
                    // Timestamp
                    Text(formatTimestamp(item.timestamp ?? Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Navigation chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    /// Format timestamp for display
    /// - Parameter date: The date to format
    /// - Returns: Formatted string
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Risk level visual indicator
struct RiskLevelIndicator: View {
    let riskLevel: String
    
    var body: some View {
        Circle()
            .fill(riskColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(riskColor.opacity(0.3), lineWidth: 4)
            )
    }
    
    /// Get color for risk level
    private var riskColor: Color {
        switch riskLevel.lowercased() {
        case "low":
            return .green
        case "medium":
            return .orange
        case "high":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleItem = ScanHistoryItem(context: context)
    sampleItem.id = UUID()
    sampleItem.sessionId = "preview-session"
    sampleItem.riskLevel = "medium"
    sampleItem.confidence = 0.85
    sampleItem.category = "Phishing"
    sampleItem.explanation = "Suspicious link detected in message that could lead to credential theft"
    sampleItem.ocrText = "Click here to claim your prize!"
    sampleItem.timestamp = Date().addingTimeInterval(-3600) // 1 hour ago
    
    return List {
        HistoryRowView(item: sampleItem)
    }
    .environment(\.managedObjectContext, context)
}
