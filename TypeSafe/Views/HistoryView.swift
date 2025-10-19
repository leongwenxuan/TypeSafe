//
//  HistoryView.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import SwiftUI
import CoreData

/// Main history view displaying recent scan results
struct HistoryView: View {
    /// Core Data environment
    @Environment(\.managedObjectContext) private var viewContext
    
    /// History manager for data operations
    @StateObject private var historyManager = HistoryManager.shared
    
    /// Fetch request for history items (last 5, newest first, within 7 days)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ScanHistoryItem.timestamp, ascending: false)],
        animation: .default
    ) private var historyItems: FetchedResults<ScanHistoryItem>
    
    /// Loading state for pull-to-refresh
    @State private var isRefreshing = false
    
    /// Refresh trigger for manual updates
    @State private var refreshTrigger = false
    
    /// Filtered history items (last 7 days only)
    private var filteredHistoryItems: [ScanHistoryItem] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return historyItems.filter { item in
            guard let timestamp = item.timestamp else { return false }
            return timestamp >= sevenDaysAgo
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if filteredHistoryItems.isEmpty {
                    EmptyHistoryView()
                } else {
                    HistoryListView(historyItems: Array(filteredHistoryItems.prefix(5)))
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshHistory()
            }
            .onAppear {
                let total = historyItems.count
                let filtered = filteredHistoryItems.count
                print("📊 HistoryView appeared:")
                print("  - Total history items: \(total)")
                print("  - Filtered items (last 7 days): \(filtered)")
                print("  - Displayed items (max 5): \(min(filtered, 5))")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HistoryDidChange"))) { _ in
                print("📊 HistoryView: Received HistoryDidChange notification")
                // Trigger a UI refresh
                refreshTrigger.toggle()
                
                // Log current state after notification
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let total = historyItems.count
                    let filtered = filteredHistoryItems.count
                    print("📊 HistoryView: After notification refresh:")
                    print("  - Total history items: \(total)")
                    print("  - Filtered items (last 7 days): \(filtered)")
                }
            }
            .id(refreshTrigger) // Force view refresh when trigger changes
        }
    }
    
    /// Refresh history data (placeholder for future backend sync)
    private func refreshHistory() async {
        isRefreshing = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // In future implementation, this would sync with backend
        // For now, just trigger a cleanup
        historyManager.performDailyCleanup()
        
        isRefreshing = false
    }
}

/// Empty state view when no history exists
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Icon and title
            VStack(spacing: 16) {
                Image(systemName: "clock.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
                    .accessibilityLabel("History icon")
                
                Text("No scans yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Description
            Text("Your scan history will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// List view for displaying history items
struct HistoryListView: View {
    let historyItems: [ScanHistoryItem]
    
    var body: some View {
        List {
            ForEach(historyItems, id: \.id) { item in
                NavigationLink(destination: ScanResultDetailView(historyItem: item)) {
                    HistoryRowView(item: item)
                }
                .accessibilityLabel("Scan result from \(item.category ?? "Unknown")")
            }
        }
        .listStyle(PlainListStyle())
    }
}

/// Detail view for displaying a saved scan result
struct ScanResultDetailView: View {
    let historyItem: ScanHistoryItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Risk level header
                RiskLevelHeader(
                    riskLevel: historyItem.riskLevel ?? "unknown",
                    confidence: historyItem.confidence
                )
                
                // Category and explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analysis")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Category:")
                                .fontWeight(.medium)
                            Text(historyItem.category ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Explanation:")
                            .fontWeight(.medium)
                        Text(historyItem.explanation ?? "No explanation available")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
                
                // OCR text
                if !(historyItem.ocrText ?? "").isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detected Text")
                            .font(.headline)
                        
                        Text(historyItem.ocrText ?? "")
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                // Timestamp
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scanned:")
                        .font(.headline)
                    Text(formatFullTimestamp(historyItem.timestamp ?? Date()))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Format full timestamp for detail view
    private func formatFullTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Risk level header component
struct RiskLevelHeader: View {
    let riskLevel: String
    let confidence: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Risk Level")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(riskLevel.capitalized)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(riskColor)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Confidence")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(Int(confidence * 100))%")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(riskColor.opacity(0.1))
        .cornerRadius(10)
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

#Preview("Empty History") {
    HistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("With History") {
    let context = PersistenceController.preview.container.viewContext
    
    // Create sample data
    let item1 = ScanHistoryItem(context: context)
    item1.id = UUID()
    item1.sessionId = "preview-session"
    item1.riskLevel = "high"
    item1.confidence = 0.92
    item1.category = "Phishing"
    item1.explanation = "Suspicious link detected that attempts to steal credentials"
    item1.ocrText = "Click here to verify your account: suspicious-link.com"
    item1.timestamp = Date().addingTimeInterval(-3600)
    
    let item2 = ScanHistoryItem(context: context)
    item2.id = UUID()
    item2.sessionId = "preview-session"
    item2.riskLevel = "low"
    item2.confidence = 0.15
    item2.category = "Safe"
    item2.explanation = "No security threats detected"
    item2.ocrText = "Meeting at 3 PM in conference room B"
    item2.timestamp = Date().addingTimeInterval(-7200)
    
    try? context.save()
    
    return HistoryView()
        .environment(\.managedObjectContext, context)
}
