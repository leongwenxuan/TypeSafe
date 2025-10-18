//
//  AutoScanLogger.swift
//  TypeSafe
//
//  Story 5.3: Error Handling & Edge Cases
//  Comprehensive logging service for automatic screenshot scanning events
//

import Foundation
import Photos

/// Logging events for automatic screenshot scanning
enum AutoScanLogEvent {
    case started(deepLinkURL: String)
    case permissionCheck(status: PHAuthorizationStatus)
    case settingDisabled
    case fetchStarted
    case fetchSuccess(timestamp: Date)
    case fetchFailed(error: ScreenshotFetchService.ScreenshotFetchError)
    case conversionStarted
    case conversionSuccess(size: CGSize)
    case conversionFailed
    case ocrTriggered(isAutoScanned: Bool)
    case fallbackToManual(reason: String)
    case debounced(timeSinceLastAttempt: TimeInterval)
    case concurrentAttemptBlocked
    case complete(duration: TimeInterval, success: Bool)
}

/// Service for structured logging of automatic scan events
class AutoScanLogger {
    
    /// Shared instance for consistent logging
    static let shared = AutoScanLogger()
    
    private init() {}
    
    /// Log an automatic scan event with timestamp and formatted output
    /// - Parameter event: The AutoScanLogEvent to log
    func logEvent(_ event: AutoScanLogEvent) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        switch event {
        case .started(let url):
            print("[\(timestamp)] [AutoScan] Started - URL: \(url)")
            
        case .permissionCheck(let status):
            let statusString = self.authorizationStatusString(status)
            print("[\(timestamp)] [AutoScan] Permission check - Status: \(statusString)")
            
        case .settingDisabled:
            print("[\(timestamp)] [AutoScan] Setting disabled - falling back to manual")
            
        case .fetchStarted:
            print("[\(timestamp)] [AutoScan] Fetching screenshot from Photos library")
            
        case .fetchSuccess(let timestamp):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timestampString = dateFormatter.string(from: timestamp)
            print("[\(timestamp)] [AutoScan] Fetch success - Screenshot timestamp: \(timestampString)")
            
        case .fetchFailed(let error):
            print("[\(timestamp)] [AutoScan] Fetch failed - Error: \(error.localizedDescription)")
            
        case .conversionStarted:
            print("[\(timestamp)] [AutoScan] Converting PHAsset to UIImage")
            
        case .conversionSuccess(let size):
            print("[\(timestamp)] [AutoScan] Conversion success - Size: \(Int(size.width))x\(Int(size.height))")
            
        case .conversionFailed:
            print("[\(timestamp)] [AutoScan] Conversion failed")
            
        case .ocrTriggered(let isAuto):
            print("[\(timestamp)] [AutoScan] OCR triggered - Auto: \(isAuto)")
            
        case .fallbackToManual(let reason):
            print("[\(timestamp)] [AutoScan] Fallback to manual - Reason: \(reason)")
            
        case .debounced(let timeSinceLastAttempt):
            print("[\(timestamp)] [AutoScan] Debounced - Time since last attempt: \(String(format: "%.2f", timeSinceLastAttempt))s")
            
        case .concurrentAttemptBlocked:
            print("[\(timestamp)] [AutoScan] Concurrent attempt blocked - Scan already in progress")
            
        case .complete(let duration, let success):
            print("[\(timestamp)] [AutoScan] Complete - Duration: \(String(format: "%.2f", duration))s, Success: \(success)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Convert PHAuthorizationStatus to readable string
    private func authorizationStatusString(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .limited:
            return "Limited"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown(\(status.rawValue))"
        }
    }
}

