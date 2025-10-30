//
//  DebouncedAnalyzer.swift
//  TypeSafeKeyboard
//
//  Story 10.1: Performance Optimization
//  Implements debouncing and request coalescing for text analysis
//

import Foundation

/// Manages debounced text analysis with request cancellation and coalescing
class DebouncedAnalyzer {
    
    // MARK: - Properties
    
    /// Debounce delay in seconds (500ms for good balance between responsiveness and efficiency)
    private let debounceDelay: TimeInterval = 0.5
    
    /// Timer for debouncing
    private var debounceTimer: Timer?
    
    /// Pending text to analyze
    private var pendingText: String?
    
    /// Current in-flight task
    private var currentTask: URLSessionDataTask?
    
    /// API service for making requests
    private let apiService: APIService
    
    /// Callback for analysis results
    private var resultCallback: ((Result<AnalyzeTextResponse, Error>) -> Void)?
    
    /// Statistics for performance monitoring
    private var requestCount: Int = 0
    private var debouncedCount: Int = 0
    
    // MARK: - Initialization
    
    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }
    
    // MARK: - Public Methods
    
    /// Triggers analysis with debouncing
    /// - Parameters:
    ///   - text: Text to analyze
    ///   - completion: Callback with analysis result
    func analyzeText(
        _ text: String,
        completion: @escaping (Result<AnalyzeTextResponse, Error>) -> Void
    ) {
        // Store the latest text and callback
        pendingText = text
        resultCallback = completion
        
        // Invalidate existing timer
        debounceTimer?.invalidate()
        
        // Increment debounced counter
        debouncedCount += 1
        
        // Create new timer
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: debounceDelay,
            repeats: false
        ) { [weak self] _ in
            self?.performAnalysis()
        }
    }
    
    /// Forces immediate analysis (bypasses debounce)
    /// - Parameters:
    ///   - text: Text to analyze
    ///   - completion: Callback with analysis result
    func analyzeTextImmediate(
        _ text: String,
        completion: @escaping (Result<AnalyzeTextResponse, Error>) -> Void
    ) {
        // Cancel any pending debounce
        debounceTimer?.invalidate()
        debounceTimer = nil
        
        // Store text and callback
        pendingText = text
        resultCallback = completion
        
        // Perform analysis immediately
        performAnalysis()
    }
    
    /// Cancels any pending or in-flight analysis
    func cancelPending() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        currentTask?.cancel()
        currentTask = nil
        pendingText = nil
        resultCallback = nil
    }
    
    /// Returns statistics about debouncing effectiveness
    /// - Returns: Tuple of (total requests, debounced count, reduction percentage)
    func getStatistics() -> (requests: Int, debounced: Int, reductionPercent: Double) {
        let total = requestCount + debouncedCount
        let reduction = total > 0 ? (Double(debouncedCount) / Double(total)) * 100.0 : 0.0
        return (requestCount, debouncedCount, reduction)
    }
    
    /// Resets statistics counters
    func resetStatistics() {
        requestCount = 0
        debouncedCount = 0
    }
    
    // MARK: - Private Methods
    
    /// Performs the actual analysis after debounce period
    private func performAnalysis() {
        guard let text = pendingText,
              let callback = resultCallback else {
            return
        }
        
        // Clear pending state
        pendingText = nil
        let capturedCallback = callback
        resultCallback = nil
        
        // Increment actual request counter
        requestCount += 1
        
        // Log debounce effectiveness periodically
        if requestCount % 10 == 0 {
            let stats = getStatistics()
            print("🔵 DebouncedAnalyzer Stats: \(stats.requests) requests, \(stats.debounced) debounced (\(String(format: "%.1f", stats.reductionPercent))% reduction)")
        }
        
        // Perform analysis on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Make API call
            self.apiService.analyzeText(text: text) { result in
                // Clear current task reference
                self.currentTask = nil
                
                // Deliver result on main thread
                DispatchQueue.main.async {
                    capturedCallback(result)
                }
            }
        }
    }
}

