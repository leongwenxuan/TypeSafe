//
//  ScanView.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//  Updated: Story 5.1 - Photos Framework Integration & Permission Management
//

import SwiftUI
import PhotosUI
import Photos

/// Main view for screenshot scanning functionality
/// Allows users to select or capture screenshots to scan for scams
struct ScanView: View {
    @State private var selectedImage: UIImage?
    @State private var showingPhotoPicker = false
    @State private var showingImagePreview = false
    @State private var showingOCRPreview = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingScreenshotGuide = false
    @State private var isProcessingOCR = false
    @State private var extractedText = ""
    @State private var isAutoScanning = false  // Story 5.2: Auto-scan loading state
    @State private var isAutoScannedImage = false  // Story 5.2: Track if current image was auto-scanned
    @State private var lastAutoScanAttempt: Date = .distantPast  // Story 5.3: Debouncing
    @State private var showingErrorBanner = false  // Story 5.3: Error banner display
    @State private var currentError: ScreenshotFetchService.ScreenshotFetchError?  // Story 5.3: Current error
    @State private var isAnalyzingBackend = false  // Story 5.3: Backend analysis in progress
    @State private var analysisResult: ScanImageResponse?  // Story 5.3: Backend analysis result
    @State private var showingResult = false  // Story 5.3: Show result view
    @State private var showingAgentProgress = false  // Story 8.11: Show agent progress view
    @State private var agentTaskId: String?  // Story 8.11: Agent task ID
    @State private var agentWsUrl: String?  // Story 8.11: Agent WebSocket URL
    
    @StateObject private var ocrService = OCRService()
    @StateObject private var photosPermission = PhotosPermissionManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var apiService = APIService()  // Story 5.3: Backend API service
    
    @EnvironmentObject private var deepLinkCoordinator: DeepLinkCoordinator  // Story 5.2
    
    // Story 5.2 & 5.3: Screenshot fetch service (not a state object)
    private let screenshotFetchService = ScreenshotFetchService()
    
    // Story 5.3: Configuration constants
    private let autoScanDebounceInterval: TimeInterval = 2.0  // 2 seconds between scans
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Ensure proper background color
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                if showingOCRPreview {
                    // OCR text preview state
                    OCRTextPreviewView(
                        originalText: extractedText,
                        originalImage: selectedImage,
                        isAutoScanned: isAutoScannedImage,  // Story 5.2: Pass auto-scan flag
                        onRetryOCR: {
                            showingOCRPreview = false
                            if let image = selectedImage {
                                processImageWithOCR(image, isAutoScanned: isAutoScannedImage)
                            }
                        },
                        onCancel: {
                            resetToInitialState()
                        }
                    )
                } else if isAutoScanning {
                    // Story 5.2: Auto-scan loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .accessibilityLabel("Fetching screenshot")
                        
                        Text("Loading Your Screenshot...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Automatically fetching your most recent screenshot for scanning.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if isAnalyzingBackend {
                    // Story 5.3: Backend analysis in progress
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .accessibilityLabel("Analyzing for scams")
                        
                        Text("Analyzing for Scams...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Sending your screenshot to our AI for scam detection. This usually takes just a few seconds.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if isProcessingOCR {
                    // OCR processing state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .accessibilityLabel("Processing OCR")
                        
                        Text("Extracting Text...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Analyzing your image to extract text. This may take a moment.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Cancel") {
                            isProcessingOCR = false
                            showingImagePreview = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                } else if showingImagePreview, let image = selectedImage {
                    // Image preview state
                    ImagePreviewView(
                        image: image,
                        onUseImage: {
                            processImageWithOCR(image)
                        },
                        onChooseDifferent: {
                            selectedImage = nil
                            showingImagePreview = false
                        }
                    )
                } else {
                    // Main scan interface
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .accessibilityLabel("Scan icon")
                        
                        Text("Scan My Screen")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 40)
                    
                    // Description
                    Text("Select a screenshot from your photos or take a new one to analyze text for potential scams and security threats.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Main scan button
                        Button(action: {
                            checkPhotoPermissionAndPresentPicker()
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Select from Photos")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .accessibilityLabel("Select image from photos")
                        .accessibilityHint("Open photo picker to select an image to scan")
                        
                        // Screenshot guide button
                        Button(action: {
                            showingScreenshotGuide = true
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text("How to Take Screenshot")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .accessibilityLabel("Screenshot help")
                        .accessibilityHint("Learn how to take screenshots on iOS")
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.large)
            
            // Story 5.3: Error banner overlay
            if showingErrorBanner, let error = currentError {
                VStack {
                    AutoScanErrorBanner(
                        error: error,
                        onOpenSettings: {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        },
                        onDismiss: {
                            showingErrorBanner = false
                        }
                    )
                    .padding(.top, 60)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showingErrorBanner)
            }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView(
                    selectedImage: $selectedImage,
                    isPresented: $showingPhotoPicker,
                    onImageSelected: { image in
                        selectedImage = image
                        showingImagePreview = true
                    },
                    onError: { error in
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                )
            }
            .sheet(isPresented: $showingScreenshotGuide) {
                ScreenshotGuideView()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
                if errorMessage.contains("Settings") {
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: deepLinkCoordinator.shouldAutoScan) { shouldAuto in
                // Story 5.2: Handle automatic screenshot scanning from deep link
                if shouldAuto {
                    Task {
                        await handleAutoScan()
                    }
                }
            }
            .navigationDestination(isPresented: $showingResult) {
                // Story 5.3: Navigate to results after auto-submit
                if let result = analysisResult {
                    ScanResultView(
                        result: result,
                        analyzedText: extractedText,
                        onScanAnother: {
                            // Reset and go back to scan view
                            resetToInitialState()
                        },
                        onEditText: {
                            // Go back to preview to edit
                            showingResult = false
                            showingOCRPreview = true
                        },
                        onSaveToHistory: {
                            // Already saved in autoSubmitToBackend
                            print("ScanView: Result already saved to history")
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showingAgentProgress) {
                // Story 8.11: Navigate to agent progress view
                if let taskId = agentTaskId, let wsUrl = agentWsUrl {
                    AgentProgressView(
                        taskId: taskId,
                        wsUrl: wsUrl,
                        analyzedText: extractedText,
                        isAutoScanned: isAutoScannedImage,
                        onDismiss: {
                            // Reset and go back to scan view
                            resetToInitialState()
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Checks photo library permission and presents picker if authorized
    /// Updated in Story 5.1 to use PhotosPermissionManager
    private func checkPhotoPermissionAndPresentPicker() {
        // Check current permission status using new manager
        let status = photosPermission.checkAuthorizationStatus()
        
        switch status {
        case .authorized, .limited:
            // Permission granted - show picker
            showingPhotoPicker = true
            
        case .denied, .restricted:
            // Permission denied or restricted - show error with settings link
            errorMessage = photosPermission.permissionExplanation
            showingError = true
            
        case .notDetermined:
            // First time - request permission
            Task {
                let newStatus = await photosPermission.requestAuthorization()
                
                await MainActor.run {
                    switch newStatus {
                    case .authorized, .limited:
                        showingPhotoPicker = true
                    case .denied, .restricted:
                        errorMessage = photosPermission.permissionExplanation
                        showingError = true
                    case .notDetermined:
                        errorMessage = "Unable to determine photo access permission. Please try again."
                        showingError = true
                    @unknown default:
                        errorMessage = "Unknown photo permission status. Please check Settings."
                        showingError = true
                    }
                }
            }
            
        @unknown default:
            errorMessage = "Unknown photo permission status. Please check Settings."
            showingError = true
        }
    }
    
    /// Process the selected image with OCR
    /// - Parameters:
    ///   - image: The UIImage to process
    ///   - isAutoScanned: Whether this image was automatically scanned (Story 5.2)
    ///   - autoSubmit: Whether to automatically submit to backend after OCR (Story 5.3)
    private func processImageWithOCR(_ image: UIImage, isAutoScanned: Bool = false, autoSubmit: Bool = false) {
        showingImagePreview = false
        isProcessingOCR = true
        isAutoScannedImage = isAutoScanned  // Story 5.2: Track auto-scan status
        
        Task {
            let result = await ocrService.processImage(image)
            
            await MainActor.run {
                isProcessingOCR = false
                
                switch result {
                case .success(let text):
                    extractedText = text
                    
                    // Story 5.3: Auto-submit to backend if requested
                    if autoSubmit && isAutoScanned {
                        // Skip preview and go straight to backend analysis
                        autoSubmitToBackend(ocrText: text, image: image)
                    } else {
                        // Show preview as normal
                        showingOCRPreview = true
                    }
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                    showingImagePreview = true // Return to image preview on error
                }
            }
        }
    }
    
    /// Story 5.2 & 5.3: Handle automatic screenshot scanning from deep link
    /// Enhanced in 5.3 with debouncing, timeout, and comprehensive logging
    private func handleAutoScan() async {
        let startTime = Date()
        AutoScanLogger.shared.logEvent(.started(deepLinkURL: "typesafe://scan?auto=true"))
        
        // Story 5.3: Debounce check - Prevent scans within 2 seconds of each other
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAutoScanAttempt)
        guard timeSinceLastAttempt >= autoScanDebounceInterval else {
            AutoScanLogger.shared.logEvent(.debounced(timeSinceLastAttempt: timeSinceLastAttempt))
            return
        }
        
        // Story 5.3: Concurrency check - Prevent multiple simultaneous scans
        guard !isAutoScanning else {
            AutoScanLogger.shared.logEvent(.concurrentAttemptBlocked)
            return
        }
        
        // Update state
        await MainActor.run {
            lastAutoScanAttempt = Date()
            isAutoScanning = true
        }
        
        // Defer cleanup to ensure state is reset even on early returns
        defer {
            Task { @MainActor in
                isAutoScanning = false
            }
            let duration = Date().timeIntervalSince(startTime)
            AutoScanLogger.shared.logEvent(.complete(duration: duration, success: selectedImage != nil))
        }
        
        // Check if automatic scanning is enabled in settings
        guard settingsManager.settings.automaticScreenshotScanEnabled else {
            AutoScanLogger.shared.logEvent(.settingDisabled)
            await MainActor.run {
                showingPhotoPicker = true
            }
            return
        }
        
        // Check photos permission
        let status = photosPermission.checkAuthorizationStatus()
        AutoScanLogger.shared.logEvent(.permissionCheck(status: status))
        
        guard status == .authorized || status == .limited else {
            await handleAutoScanFailure(error: .permissionDenied)
            return
        }
        
        // Story 5.3: Fetch with 5-second timeout
        AutoScanLogger.shared.logEvent(.fetchStarted)
        let result = await screenshotFetchService.fetchScreenshotWithTimeout()
        
        switch result {
        case .success(let image):
            // Successfully fetched screenshot - trigger OCR
            AutoScanLogger.shared.logEvent(.fetchSuccess(timestamp: Date()))
            AutoScanLogger.shared.logEvent(.ocrTriggered(isAutoScanned: true))
            
            await MainActor.run {
                selectedImage = image
                showAutoScanSuccessFeedback()
                // Story 5.3: Auto-submit enabled - skip preview and go straight to backend
                processImageWithOCR(image, isAutoScanned: true, autoSubmit: true)
            }
            
        case .failure(let error):
            // Failed to fetch screenshot - fall back to manual picker
            await handleAutoScanFailure(error: error)
        }
    }
    
    /// Story 5.3: Handle automatic scan failure with error banner and fallback to manual picker
    private func handleAutoScanFailure(error: ScreenshotFetchService.ScreenshotFetchError) async {
        AutoScanLogger.shared.logEvent(.fetchFailed(error: error))
        AutoScanLogger.shared.logEvent(.fallbackToManual(reason: error.localizedDescription))
        
        await MainActor.run {
            isAutoScanning = false
            
            // Show error banner
            currentError = error
            showingErrorBanner = true
            
            // Auto-dismiss after 3 seconds and show manual picker
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.showingErrorBanner = false
                self.showingPhotoPicker = true
            }
        }
    }
    
    /// Story 5.3: Show success feedback when auto-scan completes
    private func showAutoScanSuccessFeedback() {
        // Haptic feedback for successful auto-scan
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Reset all states to initial condition
    private func resetToInitialState() {
        selectedImage = nil
        showingImagePreview = false
        showingOCRPreview = false
        isProcessingOCR = false
        isAutoScanning = false
        isAutoScannedImage = false
        isAnalyzingBackend = false
        analysisResult = nil
        showingResult = false
        showingAgentProgress = false
        agentTaskId = nil
        agentWsUrl = nil
        extractedText = ""
    }
    
    /// Story 5.3 & 8.11: Automatically submit OCR text to backend and navigate to results
    /// Enhanced in 8.11 to handle agent path responses with WebSocket progress
    /// - Parameters:
    ///   - ocrText: Extracted OCR text
    ///   - image: Original screenshot image
    private func autoSubmitToBackend(ocrText: String, image: UIImage) {
        print("ScanView: Auto-submitting to backend (skipping preview)")
        
        isAnalyzingBackend = true
        
        apiService.scanImage(
            ocrText: ocrText,
            image: image
        ) { [weak apiService] result in
            DispatchQueue.main.async {
                self.isAnalyzingBackend = false
                
                switch result {
                case .success(let response):
                    // Story 8.11: Check if this is an agent response
                    if response.isAgentResponse {
                        // Agent path - navigate to progress view
                        print("ScanView: Agent path detected - Task ID: \(response.task_id ?? "none")")
                        
                        guard let taskId = response.task_id, let wsUrl = response.ws_url else {
                            print("ScanView: Missing task_id or ws_url in agent response")
                            self.errorMessage = "Invalid agent response. Please try again."
                            self.showingError = true
                            self.showingOCRPreview = true
                            return
                        }
                        
                        // Navigate to agent progress view
                        self.agentTaskId = taskId
                        self.agentWsUrl = wsUrl
                        self.showingAgentProgress = true
                        
                    } else {
                        // Fast path - navigate to simple results
                        print("ScanView: Fast path - Risk: \(response.risk_level ?? "unknown")")
                        
                        // Ensure required fields are present
                        guard let riskLevel = response.risk_level else {
                            print("ScanView: Missing risk_level in fast path response")
                            self.errorMessage = "Invalid response from server. Please try again."
                            self.showingError = true
                            self.showingOCRPreview = true
                            return
                        }
                        
                        // Save to history
                        self.saveToHistory(result: response, ocrText: ocrText)
                        
                        // Navigate to results
                        self.analysisResult = response
                        self.showingResult = true
                    }
                    
                case .failure(let error):
                    print("ScanView: Backend analysis failed: \(error.localizedDescription)")
                    
                    // Show error and fall back to preview so user can retry
                    self.errorMessage = "Analysis failed: \(error.localizedDescription). You can edit the text and try again."
                    self.showingError = true
                    self.showingOCRPreview = true  // Fall back to preview on error
                }
            }
        }
    }
    
    /// Save scan result to history
    private func saveToHistory(result: ScanImageResponse, ocrText: String) {
        // Only save simple/fast path responses - agent results are saved after completion
        guard result.isSimpleResponse else {
            print("ScanView: Skipping history save for agent response (will save after completion)")
            return
        }
        
        // Ensure required fields are present
        guard let riskLevel = result.risk_level,
              let confidence = result.confidence,
              let category = result.category,
              let explanation = result.explanation else {
            print("ScanView: Missing required fields for history save")
            return
        }
        
        let sessionId = UserDefaults.standard.string(forKey: "session_id") ?? UUID().uuidString
        
        HistoryManager.shared.saveToHistory(
            sessionId: sessionId,
            riskLevel: riskLevel,
            confidence: confidence,
            category: category,
            explanation: explanation,
            ocrText: ocrText,
            thumbnailData: nil,
            isAutoScanned: isAutoScannedImage
        )
        
        print("ScanView: Saved to history - \(category) (\(riskLevel))")
    }
}

#Preview {
    ScanView()
}
