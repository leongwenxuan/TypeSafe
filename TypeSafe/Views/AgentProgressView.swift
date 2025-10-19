//
//  AgentProgressView.swift
//  TypeSafe
//
//  Story 8.11: iOS App Agent Progress Display
//  Real-time agent progress display with tool execution tracking
//

import SwiftUI

/// Main view for displaying agent analysis progress
struct AgentProgressView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: AgentProgressViewModel
    
    /// Callback when user wants to return to scan view
    let onDismiss: () -> Void
    
    /// OCR text that was analyzed
    private let analyzedText: String
    
    /// Whether this was an auto-scanned screenshot
    private let isAutoScanned: Bool
    
    /// Whether the result has been saved to history
    @State private var hasSavedToHistory = false
    
    // MARK: - Initialization
    
    init(taskId: String, wsUrl: String, analyzedText: String = "", isAutoScanned: Bool = false, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AgentProgressViewModel(taskId: taskId, wsUrl: wsUrl))
        self.onDismiss = onDismiss
        self.analyzedText = analyzedText
        self.isAutoScanned = isAutoScanned
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Ensure proper background color
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                
                // Progress bar
                if !viewModel.isComplete && !viewModel.isFailed {
                    progressSection
                }
                
                // Current step indicator
                if let currentStep = viewModel.currentStep, !viewModel.isComplete && !viewModel.isFailed {
                    currentStepSection(currentStep)
                }
                
                // Tool results
                if !viewModel.toolResults.isEmpty {
                    toolResultsSection
                }
                
                // Final result (when complete)
                if let finalResult = viewModel.finalResult {
                    FinalVerdictCard(result: finalResult)
                }
                
                // Error state
                if viewModel.isFailed {
                    errorSection
                }
                
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Agent Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("AgentProgressView: View appeared, connecting to WebSocket...")
            viewModel.connect()
        }
        .onDisappear {
            print("AgentProgressView: View disappeared, disconnecting...")
            viewModel.disconnect()
        }
        .toolbar {
            if viewModel.isComplete || viewModel.isFailed {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        print("AgentProgressView: Done button tapped, dismissing...")
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: viewModel.isComplete) { oldValue, newValue in
            print("AgentProgressView: isComplete changed from \(oldValue) to \(newValue)")
            print("  - hasSavedToHistory: \(hasSavedToHistory)")
            print("  - finalResult present: \(viewModel.finalResult != nil)")
            
            // Auto-save to history when analysis completes successfully
            if newValue && !hasSavedToHistory, let finalResult = viewModel.finalResult {
                print("AgentProgressView: Triggering auto-save to history...")
                saveToHistory(result: finalResult)
                hasSavedToHistory = true
            } else {
                print("AgentProgressView: Skipping auto-save (already saved or no result)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Save agent analysis result to history
    private func saveToHistory(result: AgentAnalysisResult) {
        print("🟢 AgentProgressView: Saving agent result to history")
        print("  - Risk Level: \(result.riskLevel)")
        print("  - Confidence: \(result.confidence)")
        print("  - Reasoning: \(result.reasoning)")
        print("  - OCR Text length: \(analyzedText.count) chars")
        print("  - Is Auto-Scanned: \(isAutoScanned)")
        
        let sessionId = UserDefaults.standard.string(forKey: "session_id") ?? UUID().uuidString
        print("  - Session ID: \(sessionId)")
        
        // Derive category from evidence or use generic "agent_analysis"
        let category = deriveCategory(from: result)
        print("  - Derived Category: \(category)")
        
        HistoryManager.shared.saveToHistory(
            sessionId: sessionId,
            riskLevel: result.riskLevel,
            confidence: Double(result.confidence) / 100.0,  // Convert percentage to 0-1
            category: category,
            explanation: result.reasoning,
            ocrText: analyzedText,
            thumbnailData: nil,
            isAutoScanned: isAutoScanned
        )
        
        // Verify save
        let count = HistoryManager.shared.getHistoryCount()
        print("🟢 AgentProgressView: ✅ Saved to history successfully!")
        print("  - Total history items: \(count)")
        print("  - Category: \(category)")
        print("  - Risk Level: \(result.riskLevel)")
    }
    
    /// Derive category from analysis result
    private func deriveCategory(from result: AgentAnalysisResult) -> String {
        // Check if we have phone evidence
        let hasPhoneEvidence = result.evidence.contains { $0.entityType.lowercased() == "phone" }
        if hasPhoneEvidence {
            return "phone_scam"
        }
        
        // Check if we have URL evidence
        let hasUrlEvidence = result.evidence.contains { $0.entityType.lowercased() == "url" }
        if hasUrlEvidence {
            return "phishing"
        }
        
        // Check if we have email evidence
        let hasEmailEvidence = result.evidence.contains { $0.entityType.lowercased() == "email" }
        if hasEmailEvidence {
            return "email_scam"
        }
        
        // Default to agent analysis
        return "agent_analysis"
    }
    
    // MARK: - View Components
    
    /// Header section
    private var headerSection: some View {
        VStack(spacing: 12) {
            if viewModel.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Analysis Complete")
                    .font(.title2)
                    .fontWeight(.bold)
                
            } else if viewModel.isFailed {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Analysis Failed")
                    .font(.title2)
                    .fontWeight(.bold)
                
            } else {
                Image(systemName: "brain")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Analyzing Screenshot")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Agent is investigating your screenshot...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical)
    }
    
    /// Progress bar section
    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progress, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            
            Text("\(Int(viewModel.progress))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    /// Current step section
    private func currentStepSection(_ step: ProgressStep) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForStep(step.step))
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.message)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(timeAgo(from: step.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    /// Tool results section
    private var toolResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.blue)
                Text("Evidence Collected")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            VStack(spacing: 8) {
                ForEach(viewModel.toolResults) { result in
                    ToolResultRow(result: result)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    /// Error section
    private var errorSection: some View {
        VStack(spacing: 16) {
            Text(viewModel.errorMessage ?? "An error occurred during analysis")
                .font(.body)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            
            Button(action: {
                viewModel.retry()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry Analysis")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get icon for step
    private func iconForStep(_ step: String) -> String {
        switch step {
        case "entity_extraction":
            return "doc.text.magnifyingglass"
        case "scam_db":
            return "exclamationmark.shield"
        case "exa_search":
            return "magnifyingglass"
        case "domain_reputation":
            return "globe"
        case "phone_validator":
            return "phone.fill"
        case "reasoning":
            return "brain"
        case "completed":
            return "checkmark.circle.fill"
        case "failed":
            return "xmark.circle.fill"
        default:
            return "circle.fill"
        }
    }
    
    /// Format timestamp as "time ago"
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 1 {
            return "Just now"
        } else if seconds < 60 {
            return "\(Int(seconds))s ago"
        } else {
            return "\(Int(seconds / 60))m ago"
        }
    }
}

// MARK: - Tool Result Row

/// Row displaying a single tool execution result
struct ToolResultRow: View {
    let result: ToolResultDisplay
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: result.icon)
                .font(.system(size: 20))
                .foregroundColor(result.isSuccess ? .green : .orange)
                .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.toolName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(result.summary)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Status indicator
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(result.isSuccess ? .green : .orange)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Final Verdict Card

/// Card displaying final analysis verdict with evidence breakdown
struct FinalVerdictCard: View {
    let result: AgentAnalysisResult
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: riskIcon)
                    .font(.system(size: 40))
                    .foregroundColor(riskColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.riskTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(riskColor)
                    
                    Text("\(Int(result.confidence))% Confidence")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Reasoning
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.blue)
                    Text("Agent Reasoning")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(result.reasoning)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
            }
            
            // Entities found
            if result.totalEntitiesFound > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.blue)
                        Text("Entities Detected")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    entitiesView
                }
            }
            
            // Evidence breakdown (expandable)
            if !result.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text("Evidence Details (\(result.evidence.count))")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if isExpanded {
                        evidenceList
                    }
                }
            }
            
            // Tools used
            if !result.toolsUsed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundColor(.blue)
                        Text("Tools Used")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(result.toolsUsed, id: \.self) { tool in
                            Text(formatToolName(tool))
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Subviews
    
    /// Entities view
    private var entitiesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let entities = result.entitiesFound {
                if !entities.phones.isEmpty {
                    entityRow(icon: "phone.fill", label: "Phones", values: entities.phones)
                }
                if !entities.urls.isEmpty {
                    entityRow(icon: "link", label: "URLs", values: entities.urls)
                }
                if !entities.emails.isEmpty {
                    entityRow(icon: "envelope.fill", label: "Emails", values: entities.emails)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
    
    /// Entity row
    private func entityRow(icon: String, label: String, values: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
        }
    }
    
    /// Evidence list
    private var evidenceList: some View {
        VStack(spacing: 8) {
            ForEach(Array(result.evidence.enumerated()), id: \.offset) { index, evidence in
                EvidenceRow(evidence: evidence, index: index + 1)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var riskIcon: String {
        switch result.riskLevel.lowercased() {
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
    
    private var riskColor: Color {
        switch result.riskLevel.lowercased() {
        case "high":
            return .red
        case "medium":
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        case "low":
            return .green
        default:
            return .gray
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatToolName(_ tool: String) -> String {
        tool.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Evidence Row

/// Row displaying a single piece of evidence
struct EvidenceRow: View {
    let evidence: ToolEvidence
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(evidence.success ? Color.green : Color.orange)
                    .cornerRadius(8)
                
                Text(evidence.toolName.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let executionTime = evidence.executionTimeMs {
                    Text("\(Int(executionTime))ms")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            
            HStack(spacing: 6) {
                Text(evidence.entityType.capitalized + ":")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(evidence.entityValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(evidence.success ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Flow Layout

/// Simple flow layout for wrapping items
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }
        
        totalHeight += lineHeight
        
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for index in subviews.indices {
            let size = sizes[index]
            
            if lineX + size.width > (proposal.width ?? 0) {
                lineY += lineHeight + spacing
                lineHeight = 0
                lineX = bounds.minX
            }
            
            let position = CGPoint(x: lineX + size.width / 2, y: lineY + size.height / 2)
            lineHeight = max(lineHeight, size.height)
            lineX += size.width + spacing
            
            subviews[index].place(at: position, anchor: .center, proposal: .unspecified)
        }
    }
}

// MARK: - Previews

#Preview("In Progress") {
    NavigationView {
        AgentProgressView(
            taskId: "test-task-123",
            wsUrl: "ws://localhost:8000/ws/agent-progress/test-task-123",
            onDismiss: {}
        )
    }
}

#Preview("Completed") {
    NavigationView {
        let view = AgentProgressView(
            taskId: "test-task-123",
            wsUrl: "ws://localhost:8000/ws/agent-progress/test-task-123",
            onDismiss: {}
        )
        
        // Simulate completed state
        view.onAppear {
            // Would need to inject mock data for preview
        }
        
        return view
    }
}

