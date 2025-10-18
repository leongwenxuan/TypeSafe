//
//  ScreenshotDetectionService.swift
//  TypeSafeKeyboard
//
//  Detects new screenshots by polling the Photos library
//  Works around iOS limitation where main app can't detect screenshots in background
//

import Foundation
import Photos

/// Service that polls Photos library to detect new screenshots
/// This runs in the keyboard extension and can detect screenshots
/// even when the main app is suspended
class ScreenshotDetectionService {
    
    // MARK: - Properties
    
    /// Polling interval in seconds
    private let pollingInterval: TimeInterval = 3.0
    
    /// Timer for periodic checks
    private var pollingTimer: Timer?
    
    /// Timestamp of last screenshot we detected
    private var lastDetectedScreenshotDate: Date?
    
    /// How recent a screenshot must be to trigger (seconds)
    private let screenshotRecencyThreshold: TimeInterval = 10.0
    
    /// Callback when new screenshot detected
    private var onScreenshotDetected: (() -> Void)?
    
    // MARK: - Public Methods
    
    /// Starts polling for new screenshots
    /// - Parameter onDetected: Callback when new screenshot is found
    func startPolling(onScreenshotDetected: @escaping () -> Void) {
        print("ScreenshotDetectionService: Starting screenshot polling")
        
        self.onScreenshotDetected = onScreenshotDetected
        
        // Initialize with current most recent screenshot
        self.lastDetectedScreenshotDate = getMostRecentScreenshotDate()
        
        // Start timer
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForNewScreenshot()
        }
        
        // Also check immediately
        checkForNewScreenshot()
    }
    
    /// Stops polling for screenshots
    func stopPolling() {
        print("ScreenshotDetectionService: Stopping screenshot polling")
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Private Methods
    
    /// Checks if a new screenshot has been taken since last check
    private func checkForNewScreenshot() {
        // Check Photos permission
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return // Silently fail if no permission
        }
        
        // Get most recent screenshot date
        guard let recentScreenshotDate = getMostRecentScreenshotDate() else {
            return // No screenshots found
        }
        
        // Check if this is a NEW screenshot (after our last detection)
        let isNewScreenshot: Bool
        if let lastDate = lastDetectedScreenshotDate {
            isNewScreenshot = recentScreenshotDate > lastDate
        } else {
            // First time - check if screenshot is recent enough
            let age = Date().timeIntervalSince(recentScreenshotDate)
            isNewScreenshot = age <= screenshotRecencyThreshold
        }
        
        guard isNewScreenshot else {
            return // No new screenshot
        }
        
        // Verify screenshot is recent (not an old one we missed)
        let age = Date().timeIntervalSince(recentScreenshotDate)
        guard age <= screenshotRecencyThreshold else {
            // Screenshot is too old, probably from before keyboard opened
            lastDetectedScreenshotDate = recentScreenshotDate
            return
        }
        
        // New screenshot detected!
        print("🟢 ScreenshotDetectionService: NEW SCREENSHOT DETECTED!")
        print("   Screenshot date: \(recentScreenshotDate)")
        print("   Age: \(String(format: "%.1f", age))s")
        print("   → Triggering automatic background scan...")
        
        // Update last detected
        lastDetectedScreenshotDate = recentScreenshotDate
        
        // Trigger callback (will launch app silently in background)
        onScreenshotDetected?()
    }
    
    /// Gets the creation date of the most recent screenshot
    /// - Returns: Date of most recent screenshot, or nil if none found
    private func getMostRecentScreenshotDate() -> Date? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaSubtype == %d",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        fetchOptions.fetchLimit = 1
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        return fetchResult.firstObject?.creationDate
    }
}

