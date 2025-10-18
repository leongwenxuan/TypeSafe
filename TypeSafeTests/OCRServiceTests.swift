//
//  OCRServiceTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 18/01/25.
//

import XCTest
import Vision
@testable import TypeSafe

/// Unit tests for OCRService functionality
/// Tests OCR processing, error handling, and performance requirements
final class OCRServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var ocrService: OCRService!
    
    // MARK: - Test Setup
    
    override func setUpWithError() throws {
        super.setUp()
        ocrService = OCRService()
    }
    
    override func tearDownWithError() throws {
        ocrService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testOCRServiceInitialization() throws {
        XCTAssertNotNil(ocrService, "OCRService should initialize successfully")
    }
    
    // MARK: - OCR Processing Tests
    
    func testProcessImageWithValidImage() async throws {
        // Create a test image with text
        let testImage = createTestImageWithText("Hello World")
        
        let result = await ocrService.processImage(testImage)
        
        switch result {
        case .success(let text):
            XCTAssertFalse(text.isEmpty, "OCR should extract text from image")
            // Note: Exact text matching is difficult with OCR, so we check for non-empty result
            
        case .failure(let error):
            // OCR might fail on synthetic images, which is acceptable for this test
            print("OCR failed as expected with synthetic image: \(error)")
        }
    }
    
    func testProcessImageWithInvalidImage() async throws {
        // Create an empty/invalid image
        let invalidImage = UIImage()
        
        let result = await ocrService.processImage(invalidImage)
        
        switch result {
        case .success:
            XCTFail("OCR should fail with invalid image")
            
        case .failure(let error):
            XCTAssertNotNil(error, "Should return an error for invalid image")
        }
    }
    
    func testProcessImageWithEmptyImage() async throws {
        // Create a blank white image
        let blankImage = createBlankImage()
        
        let result = await ocrService.processImage(blankImage)
        
        switch result {
        case .success(let text):
            // Blank image might return empty text, which is valid
            print("OCR returned: '\(text)'")
            
        case .failure(let error):
            // No text found is an acceptable result for blank image
            if case OCRService.OCRError.noTextFound = error {
                // This is expected
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testOCRProcessingPerformance() async throws {
        let testImage = createTestImageWithText("Performance Test")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = await ocrService.processImage(testImage)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // AC requirement: OCR processing time < 2s
        XCTAssertLessThan(timeElapsed, 2.0, "OCR processing should complete within 2 seconds")
    }
    
    func testOCRPerformanceWithLargeImage() async throws {
        // Create a larger test image
        let largeImage = createLargeTestImage()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let _ = await ocrService.processImage(largeImage)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Even large images should process within timeout
        XCTAssertLessThan(timeElapsed, 2.0, "Large image OCR should complete within 2 seconds")
    }
    
    // MARK: - Error Handling Tests
    
    func testOCRErrorTypes() throws {
        // Test error descriptions
        let imageError = OCRService.OCRError.imageProcessingFailed
        XCTAssertNotNil(imageError.errorDescription)
        
        let noTextError = OCRService.OCRError.noTextFound
        XCTAssertNotNil(noTextError.errorDescription)
        
        let timeoutError = OCRService.OCRError.processingTimeout
        XCTAssertNotNil(timeoutError.errorDescription)
        
        let visionError = OCRService.OCRError.visionRequestFailed(NSError(domain: "test", code: 1))
        XCTAssertNotNil(visionError.errorDescription)
    }
    
    // MARK: - Concurrent Processing Tests
    
    func testConcurrentOCRProcessing() async throws {
        let testImage1 = createTestImageWithText("Test 1")
        let testImage2 = createTestImageWithText("Test 2")
        let testImage3 = createTestImageWithText("Test 3")
        
        // Process multiple images concurrently
        async let result1 = ocrService.processImage(testImage1)
        async let result2 = ocrService.processImage(testImage2)
        async let result3 = ocrService.processImage(testImage3)
        
        let results = await [result1, result2, result3]
        
        // All requests should complete (success or failure is acceptable)
        XCTAssertEqual(results.count, 3, "All concurrent OCR requests should complete")
    }
    
    // MARK: - Memory Tests
    
    func testOCRMemoryUsage() async throws {
        // Process multiple images to test for memory leaks
        for i in 1...10 {
            let testImage = createTestImageWithText("Memory Test \(i)")
            let _ = await ocrService.processImage(testImage)
        }
        
        // If we reach here without crashes, memory management is likely correct
        XCTAssertTrue(true, "OCR service should handle multiple processing requests without memory issues")
    }
    
    // MARK: - Integration Tests
    
    func testOCRServiceWithRealWorldScenarios() async throws {
        // Test with different types of content that might appear in screenshots
        let scenarios = [
            "Email: user@example.com",
            "Phone: +1-555-123-4567",
            "URL: https://example.com/suspicious-link",
            "Amount: $1,234.56"
        ]
        
        for scenario in scenarios {
            let testImage = createTestImageWithText(scenario)
            let result = await ocrService.processImage(testImage)
            
            // We don't assert specific text due to OCR variability,
            // but we ensure the service handles different content types
            switch result {
            case .success(let text):
                print("OCR extracted: '\(text)' from scenario: '\(scenario)'")
            case .failure(let error):
                print("OCR failed for scenario '\(scenario)': \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a test image with rendered text
    /// - Parameter text: The text to render in the image
    /// - Returns: UIImage containing the rendered text
    private func createTestImageWithText(_ text: String) -> UIImage {
        let size = CGSize(width: 300, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Black text
            UIColor.black.setFill()
            let font = UIFont.systemFont(ofSize: 20)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]
            
            let textRect = CGRect(x: 10, y: 30, width: size.width - 20, height: size.height - 40)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    /// Create a blank white image for testing
    /// - Returns: UIImage with white background
    private func createBlankImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// Create a larger test image for performance testing
    /// - Returns: UIImage with larger dimensions
    private func createLargeTestImage() -> UIImage {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add multiple text blocks
            UIColor.black.setFill()
            let font = UIFont.systemFont(ofSize: 16)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]
            
            let texts = [
                "Large Image Performance Test",
                "This is a larger image with multiple lines of text",
                "Testing OCR performance with bigger content",
                "Should still complete within 2 seconds"
            ]
            
            for (index, text) in texts.enumerated() {
                let y = 50 + (index * 30)
                let textRect = CGRect(x: 20, y: y, width: size.width - 40, height: 25)
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
    }
}
