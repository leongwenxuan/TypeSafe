//
//  OCRService.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import Foundation
import Vision
import UIKit
import Combine

/// Service for handling on-device OCR using Apple Vision framework
/// Provides text extraction from images with privacy-first approach
class OCRService: ObservableObject {
    
    // MARK: - Types
    
    /// Result type for OCR operations
    enum OCRResult {
        case success(String)
        case failure(OCRError)
    }
    
    /// Errors that can occur during OCR processing
    enum OCRError: LocalizedError {
        case imageProcessingFailed
        case noTextFound
        case visionRequestFailed(Error)
        case processingTimeout
        
        var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Failed to process the image for text recognition"
            case .noTextFound:
                return "No text was found in the image"
            case .visionRequestFailed(let error):
                return "Vision framework error: \(error.localizedDescription)"
            case .processingTimeout:
                return "OCR processing took too long and was cancelled"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Timeout for OCR processing (2 seconds as per AC requirement)
    private let processingTimeout: TimeInterval = 2.0
    
    // MARK: - Public Methods
    
    /// Process an image to extract text using Vision framework
    /// - Parameter image: The UIImage to process
    /// - Returns: OCRResult containing extracted text or error
    func processImage(_ image: UIImage) async -> OCRResult {
        // Resize image if too large to prevent memory issues
        let resizedImage = resizeImageIfNeeded(image)
        
        guard let cgImage = resizedImage.cgImage else {
            return .failure(.imageProcessingFailed)
        }
        
        // Use a flag to track if we've already resumed
        actor ContinuationState {
            var hasResumed = false
            
            func markResumed() -> Bool {
                if hasResumed {
                    return false // Already resumed
                }
                hasResumed = true
                return true // First resume
            }
        }
        
        let state = ContinuationState()
        
        return await withCheckedContinuation { continuation in
            // Create Vision text recognition request
            let request = VNRecognizeTextRequest { request, error in
                Task {
                    guard await state.markResumed() else {
                        return // Already resumed by timeout
                    }
                    
                    if let error = error {
                        continuation.resume(returning: .failure(.visionRequestFailed(error)))
                        return
                    }
                    
                    // Extract text from observations
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let extractedText = self.extractTextFromObservations(observations)
                    
                    if extractedText.isEmpty {
                        continuation.resume(returning: .failure(.noTextFound))
                    } else {
                        continuation.resume(returning: .success(extractedText))
                    }
                }
            }
            
            // Configure request for accurate recognition and English language
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            // Create image request handler
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Perform request with timeout
            Task {
                do {
                    try await withTimeout(seconds: processingTimeout) {
                        try handler.perform([request])
                    }
                } catch {
                    guard await state.markResumed() else {
                        return // Already resumed by Vision completion
                    }
                    
                    if error is TimeoutError {
                        continuation.resume(returning: .failure(.processingTimeout))
                    } else {
                        continuation.resume(returning: .failure(.visionRequestFailed(error)))
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Extract text from Vision observations
    /// - Parameter observations: Array of VNRecognizedTextObservation
    /// - Returns: Combined text string
    private func extractTextFromObservations(_ observations: [VNRecognizedTextObservation]) -> String {
        var extractedText = ""
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            extractedText += topCandidate.string + "\n"
        }
        
        return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Resize image if it's too large to prevent memory issues
    /// - Parameter image: Original UIImage
    /// - Returns: Resized UIImage if needed, original if already small enough
    private func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2048.0
        let originalSize = image.size
        
        // Check if resize is needed
        guard originalSize.width > maxDimension || originalSize.height > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Create resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

// MARK: - Timeout Helper

/// Custom timeout error
private struct TimeoutError: Error {}

/// Helper function to add timeout to async operations
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }
        
        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        // Return the first result (either success or timeout)
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
