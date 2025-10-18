//
//  ScreenshotFetchService.swift
//  TypeSafe
//
//  Story 5.2: Automatic Screenshot Fetch & Scan Trigger
//  Service for fetching and converting recent screenshots from Photos library
//

import Photos
import UIKit

/// Service responsible for fetching screenshots from the Photos library
/// and converting them to UIImage for OCR processing
class ScreenshotFetchService {
    
    // MARK: - Error Types
    
    enum ScreenshotFetchError: LocalizedError {
        case notFound
        case tooOld
        case conversionFailed
        case permissionDenied
        case timeout
        case limitedAccessNoScreenshot
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .notFound:
                return "Screenshot not found in photo library"
            case .tooOld:
                return "Screenshot is older than 60 seconds"
            case .conversionFailed:
                return "Failed to load screenshot image"
            case .permissionDenied:
                return "Photos access is denied"
            case .timeout:
                return "Screenshot fetch took too long (>5 seconds)"
            case .limitedAccessNoScreenshot:
                return "Screenshot not available in Limited Photos selection"
            case .unknown:
                return "Unknown error occurred during screenshot fetch"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetches the most recent screenshot from the Photos library
    /// - Returns: The most recent screenshot PHAsset, or nil if not found
    func fetchMostRecentScreenshot() async -> Result<PHAsset, ScreenshotFetchError> {
        print("ScreenshotFetchService: Fetching most recent screenshot")
        
        let fetchOptions = PHFetchOptions()
        
        // Sort by creation date (newest first)
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        
        // Filter for screenshots only
        fetchOptions.predicate = NSPredicate(
            format: "mediaSubtype == %d",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        
        // Only fetch 1 result for efficiency
        fetchOptions.fetchLimit = 1
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        guard let asset = fetchResult.firstObject else {
            print("ScreenshotFetchService: No screenshot found")
            return .failure(.notFound)
        }
        
        print("ScreenshotFetchService: Found screenshot with creation date: \(asset.creationDate?.description ?? "unknown")")
        return .success(asset)
    }
    
    /// Verifies that a screenshot was taken recently (within 60 seconds)
    /// - Parameter asset: The PHAsset to check
    /// - Returns: True if the screenshot is recent, false otherwise
    func isScreenshotRecent(_ asset: PHAsset) -> Bool {
        guard let creationDate = asset.creationDate else {
            print("ScreenshotFetchService: Asset has no creation date")
            return false
        }
        
        let age = Date().timeIntervalSince(creationDate)
        let isRecent = age <= 60.0  // 60 seconds max
        
        print("ScreenshotFetchService: Screenshot age: \(age) seconds, recent: \(isRecent)")
        return isRecent
    }
    
    /// Converts a PHAsset to UIImage for OCR processing
    /// - Parameter asset: The PHAsset to convert
    /// - Returns: The converted UIImage, or nil if conversion fails
    func convertAssetToUIImage(_ asset: PHAsset) async -> Result<UIImage, ScreenshotFetchError> {
        print("ScreenshotFetchService: Converting asset to UIImage")
        
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            // Target size for quality while managing memory
            // 1920x1920 provides excellent OCR results while staying under memory limits
            let targetSize = CGSize(width: 1920, height: 1920)
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let image = image {
                    print("ScreenshotFetchService: Successfully converted asset to UIImage")
                    continuation.resume(returning: .success(image))
                } else {
                    print("ScreenshotFetchService: Failed to convert asset to UIImage")
                    if let error = info?[PHImageErrorKey] as? Error {
                        print("ScreenshotFetchService: Conversion error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: .failure(.conversionFailed))
                }
            }
        }
    }
    
    /// Fetches and converts the most recent screenshot in one operation
    /// - Returns: Result containing the UIImage or an error
    func fetchAndConvertRecentScreenshot() async -> Result<UIImage, ScreenshotFetchError> {
        // Step 1: Fetch most recent screenshot
        let fetchResult = await fetchMostRecentScreenshot()
        
        guard case .success(let asset) = fetchResult else {
            if case .failure(let error) = fetchResult {
                return .failure(error)
            }
            return .failure(.notFound)
        }
        
        // Step 2: Verify screenshot is recent (within 60 seconds)
        guard isScreenshotRecent(asset) else {
            print("ScreenshotFetchService: Screenshot too old, failing")
            return .failure(.tooOld)
        }
        
        // Step 3: Convert to UIImage
        let conversionResult = await convertAssetToUIImage(asset)
        
        guard case .success(let image) = conversionResult else {
            if case .failure(let error) = conversionResult {
                return .failure(error)
            }
            return .failure(.conversionFailed)
        }
        
        print("ScreenshotFetchService: Successfully fetched and converted recent screenshot")
        return .success(image)
    }
    
    /// Story 5.3: Fetches screenshot with 5-second timeout protection
    /// - Parameter timeoutSeconds: Maximum time allowed for the operation (default: 5.0)
    /// - Returns: Result containing the UIImage or an error
    func fetchScreenshotWithTimeout(timeoutSeconds: TimeInterval = 5.0) async -> Result<UIImage, ScreenshotFetchError> {
        print("ScreenshotFetchService: Starting fetch with \(timeoutSeconds)s timeout")
        
        return await withTaskGroup(of: Result<UIImage, ScreenshotFetchError>.self) { group in
            // Task 1: Actual fetch and conversion
            group.addTask {
                return await self.fetchAndConvertRecentScreenshot()
            }
            
            // Task 2: Timeout task
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    print("ScreenshotFetchService: Timeout triggered after \(timeoutSeconds)s")
                    return .failure(.timeout)
                } catch {
                    // Task was cancelled (fetch completed first)
                    print("ScreenshotFetchService: Timeout task cancelled - fetch completed")
                    return .failure(.unknown)
                }
            }
            
            // Return first result (either success or timeout)
            if let result = await group.next() {
                // Cancel remaining task to free resources
                group.cancelAll()
                
                switch result {
                case .success:
                    print("ScreenshotFetchService: Fetch completed successfully before timeout")
                case .failure(let error):
                    print("ScreenshotFetchService: Fetch failed with error: \(error.localizedDescription)")
                }
                
                return result
            }
            
            // This should never happen, but handle it gracefully
            print("ScreenshotFetchService: No result received from task group")
            return .failure(.unknown)
        }
    }
}

