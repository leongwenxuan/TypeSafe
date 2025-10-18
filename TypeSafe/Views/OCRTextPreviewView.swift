//
//  OCRTextPreviewView.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//  Updated for Story 3.4: Backend Integration (Scan Image API)
//

import SwiftUI

/// View for previewing and editing OCR-extracted text before analysis
/// Allows users to review and correct OCR results before submitting for scam detection
struct OCRTextPreviewView: View {
    
    // MARK: - Properties
    
    /// The original OCR-extracted text
    let originalText: String
    
    /// The original image (optional, for backend analysis)
    let originalImage: UIImage?
    
    /// Whether this was automatically scanned (Story 5.2)
    let isAutoScanned: Bool
    
    /// The current editable text (may be modified by user)
    @State private var editableText: String
    
    /// Whether the text has been modified by the user
    @State private var hasBeenEdited: Bool = false
    
    /// Whether the text editor is focused
    @FocusState private var isTextEditorFocused: Bool
    
    /// API service for backend communication
    @StateObject private var apiService = APIService()
    
    /// Loading state for API call
    @State private var isAnalyzing: Bool = false
    
    /// Error state for API failures
    @State private var analysisError: APIError?
    
    /// Analysis result from backend
    @State private var analysisResult: ScanImageResponse?
    
    /// Whether to show error alert
    @State private var showingErrorAlert: Bool = false
    
    /// Whether to show result view
    @State private var showingResult: Bool = false
    
    /// Callbacks for user actions
    let onRetryOCR: () -> Void
    let onCancel: () -> Void
    
    // MARK: - Initialization
    
    init(
        originalText: String,
        originalImage: UIImage? = nil,
        isAutoScanned: Bool = false,
        onRetryOCR: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalText = originalText
        self.originalImage = originalImage
        self.isAutoScanned = isAutoScanned
        self._editableText = State(initialValue: originalText)
        self.onRetryOCR = onRetryOCR
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .accessibilityLabel("OCR text preview icon")
                
                // Story 5.3: Enhanced header with scan source
                HStack {
                    Text(isAutoScanned ? "Auto-scanned Screenshot" : "Selected Screenshot")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if isAutoScanned {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.blue)
                            .accessibilityLabel("Automatically scanned")
                    }
                }
                
                Text("Review and edit the text extracted from your image before analysis.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Text editor section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Extracted Text")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if hasBeenEdited {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.orange)
                            Text("Edited")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .accessibilityLabel("Text has been edited by user")
                    }
                }
                
                // Text editor with border
                TextEditor(text: $editableText)
                    .focused($isTextEditorFocused)
                    .font(.body)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .frame(minHeight: 120, maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTextEditorFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .onChange(of: editableText) { oldValue, newValue in
                        hasBeenEdited = (newValue != originalText)
                    }
                    .accessibilityLabel("Editable extracted text")
                    .accessibilityHint("Double tap to edit the extracted text")
                
                // Character count
                HStack {
                    Spacer()
                    Text("\(editableText.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                // Primary action - Proceed with analysis
                Button(action: {
                    analyzeText()
                }) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                            Text("Analyzing...")
                        } else {
                            Image(systemName: "magnifyingglass.circle.fill")
                            Text("Analyze for Scams")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        (editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing) 
                        ? Color.gray 
                        : Color.blue
                    )
                    .cornerRadius(12)
                }
                .disabled(editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
                .accessibilityLabel(isAnalyzing ? "Analyzing text" : "Analyze text for scams")
                .accessibilityHint(isAnalyzing ? "Analysis in progress" : "Proceed with scam analysis using the current text")
                
                // Secondary actions
                HStack(spacing: 12) {
                    // Retry OCR button
                    Button(action: onRetryOCR) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry OCR")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Retry OCR")
                    .accessibilityHint("Re-run text extraction on the original image")
                    
                    // Cancel button
                    Button(action: onCancel) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Cancel and return to image selection")
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("OCR Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto-focus text editor for immediate editing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextEditorFocused = true
            }
        }
        .alert("Analysis Error", isPresented: $showingErrorAlert) {
            Button("Try Again") {
                analyzeText()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let error = analysisError {
                Text(error.userFriendlyMessage)
            }
        }
        .navigationDestination(isPresented: $showingResult) {
            if let result = analysisResult {
                ScanResultView(
                    result: result,
                    analyzedText: editableText,
                    onScanAnother: {
                        // Reset state and go back to main scan view
                        resetState()
                        onCancel()
                    },
                    onEditText: {
                        // Go back to text editing
                        showingResult = false
                        analysisResult = nil
                    },
                    onSaveToHistory: {
                        // Save to history using HistoryManager
                        saveResultToHistory(result: result, analyzedText: editableText)
                    }
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Analyzes the current text using the backend API
    private func analyzeText() {
        guard !editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isAnalyzing = true
        analysisError = nil
        
        print("OCRTextPreviewView: Starting analysis")
        print("  - Text length: \(editableText.count) chars")
        print("  - Has image: \(originalImage != nil)")
        
        apiService.scanImage(
            ocrText: editableText,
            image: originalImage
        ) { result in
            DispatchQueue.main.async {
                isAnalyzing = false
                
                switch result {
                case .success(let response):
                    print("OCRTextPreviewView: Analysis successful")
                    print("  - Risk level: \(response.risk_level)")
                    
                    analysisResult = response
                    showingResult = true
                    
                case .failure(let error):
                    print("OCRTextPreviewView: Analysis failed: \(error.localizedDescription)")
                    
                    if let apiError = error as? APIError {
                        analysisError = apiError
                    } else {
                        analysisError = APIError.networkError(error)
                    }
                    showingErrorAlert = true
                }
            }
        }
    }
    
    /// Resets the view state
    private func resetState() {
        isAnalyzing = false
        analysisError = nil
        analysisResult = nil
        showingErrorAlert = false
        showingResult = false
    }
    
    /// Saves the analysis result to history
    /// - Parameters:
    ///   - result: The scan analysis result
    ///   - analyzedText: The text that was analyzed
    private func saveResultToHistory(result: ScanImageResponse, analyzedText: String) {
        // Get current session ID from UserDefaults (set by APIService)
        let sessionId = UserDefaults.standard.string(forKey: "session_id") ?? UUID().uuidString
        
        // Save to history using HistoryManager (Story 5.2: Pass isAutoScanned flag)
        HistoryManager.shared.saveToHistory(
            sessionId: sessionId,
            riskLevel: result.risk_level,
            confidence: result.confidence,
            category: result.category,
            explanation: result.explanation,
            ocrText: analyzedText,
            thumbnailData: nil, // No thumbnail for now
            isAutoScanned: isAutoScanned
        )
        
        print("Saved scan result to history: \(result.category) - \(result.risk_level) (auto-scanned: \(isAutoScanned))")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        OCRTextPreviewView(
            originalText: "This is sample extracted text from an image. It might contain some OCR errors that the user can correct before proceeding with analysis.",
            originalImage: nil,
            onRetryOCR: {
                print("Retrying OCR")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}

#Preview("Empty Text") {
    NavigationStack {
        OCRTextPreviewView(
            originalText: "",
            originalImage: nil,
            onRetryOCR: {
                print("Retrying OCR")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}

#Preview("Long Text") {
    NavigationStack {
        OCRTextPreviewView(
            originalText: "This is a much longer sample text that would be extracted from an image. It contains multiple sentences and paragraphs to test how the UI handles longer content. The text editor should be scrollable and the character count should update accordingly. Users should be able to edit this text freely before submitting it for scam analysis. This helps ensure accuracy in the detection process.",
            originalImage: nil,
            onRetryOCR: {
                print("Retrying OCR")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}
