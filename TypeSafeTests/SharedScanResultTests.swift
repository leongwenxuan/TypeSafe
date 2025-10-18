//
//  SharedScanResultTests.swift
//  TypeSafeTests
//
//  Story 3.7: App Group Integration & Keyboard Sync
//  Unit tests for SharedScanResult data model
//

import XCTest
@testable import TypeSafe

final class SharedScanResultTests: XCTestCase {
    
    // MARK: - Test Data
    
    private let validRiskLevel = "medium"
    private let validCategory = "OTP Phishing"
    private let validConfidence = 0.85
    private let testTimestamp = Date()
    
    // MARK: - Initialization Tests
    
    func testInitWithAutoUUID() {
        // Given
        let result = SharedScanResult(
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: validConfidence,
            timestamp: testTimestamp,
            isNew: true
        )
        
        // Then
        XCTAssertEqual(result.riskLevel, validRiskLevel)
        XCTAssertEqual(result.category, validCategory)
        XCTAssertEqual(result.confidence, validConfidence)
        XCTAssertEqual(result.timestamp, testTimestamp)
        XCTAssertTrue(result.isNew)
        XCTAssertFalse(result.scanId.isEmpty)
        XCTAssertTrue(result.scanId.count > 10) // UUID should be reasonably long
    }
    
    func testInitWithConvenienceInitializer() {
        // Given
        let result = SharedScanResult(
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: validConfidence
        )
        
        // Then
        XCTAssertEqual(result.riskLevel, validRiskLevel)
        XCTAssertEqual(result.category, validCategory)
        XCTAssertEqual(result.confidence, validConfidence)
        XCTAssertTrue(result.isNew) // Default should be true
        XCTAssertFalse(result.scanId.isEmpty)
        
        // Timestamp should be recent (within last 5 seconds)
        let timeDifference = abs(result.timestamp.timeIntervalSinceNow)
        XCTAssertLessThan(timeDifference, 5.0)
    }
    
    func testInitWithExplicitScanId() {
        // Given
        let testScanId = "test-scan-123"
        let result = SharedScanResult(
            scanId: testScanId,
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: validConfidence,
            timestamp: testTimestamp,
            isNew: false
        )
        
        // Then
        XCTAssertEqual(result.scanId, testScanId)
        XCTAssertEqual(result.riskLevel, validRiskLevel)
        XCTAssertEqual(result.category, validCategory)
        XCTAssertEqual(result.confidence, validConfidence)
        XCTAssertEqual(result.timestamp, testTimestamp)
        XCTAssertFalse(result.isNew)
    }
    
    // MARK: - Privacy Safety Tests
    
    func testPrivacySafetyWithValidData() {
        // Given
        let result = SharedScanResult(
            riskLevel: "high",
            category: "Payment Scam",
            confidence: 0.95
        )
        
        // Then
        XCTAssertTrue(result.isPrivacySafe)
    }
    
    func testPrivacySafetyWithInvalidRiskLevel() {
        // Given
        let result = SharedScanResult(
            scanId: "test-123",
            riskLevel: "invalid-risk",
            category: validCategory,
            confidence: validConfidence,
            timestamp: testTimestamp,
            isNew: true
        )
        
        // Then
        XCTAssertFalse(result.isPrivacySafe)
    }
    
    func testPrivacySafetyWithInvalidConfidence() {
        // Given
        let invalidResult1 = SharedScanResult(
            scanId: "test-123",
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: -0.1, // Below 0
            timestamp: testTimestamp,
            isNew: true
        )
        
        let invalidResult2 = SharedScanResult(
            scanId: "test-456",
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: 1.1, // Above 1
            timestamp: testTimestamp,
            isNew: true
        )
        
        // Then
        XCTAssertFalse(invalidResult1.isPrivacySafe)
        XCTAssertFalse(invalidResult2.isPrivacySafe)
    }
    
    func testPrivacySafetyWithTooLongCategory() {
        // Given
        let longCategory = String(repeating: "A", count: 51) // Over 50 chars
        let result = SharedScanResult(
            scanId: "test-123",
            riskLevel: validRiskLevel,
            category: longCategory,
            confidence: validConfidence,
            timestamp: testTimestamp,
            isNew: true
        )
        
        // Then
        XCTAssertFalse(result.isPrivacySafe)
    }
    
    func testPrivacySafetyWithEmptyScanId() {
        // Given
        let result = SharedScanResult(
            scanId: "",
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: validConfidence,
            timestamp: testTimestamp,
            isNew: true
        )
        
        // Then
        XCTAssertFalse(result.isPrivacySafe)
    }
    
    // MARK: - Size Estimation Tests
    
    func testEstimatedSize() {
        // Given
        let result = SharedScanResult(
            scanId: "12345678-1234-1234-1234-123456789012", // 36 chars
            riskLevel: "medium", // 6 chars
            category: "OTP Phishing", // 12 chars
            confidence: 0.85,
            timestamp: testTimestamp,
            isNew: true
        )
        
        // Then
        let expectedSize = 36 + 6 + 12 + 8 + 8 + 1 // scanId + riskLevel + category + confidence + timestamp + isNew
        XCTAssertEqual(result.estimatedSize, expectedSize)
    }
    
    func testEstimatedSizeIsReasonable() {
        // Given
        let result = SharedScanResult(
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: validConfidence
        )
        
        // Then - Should be well under 1KB privacy limit
        XCTAssertLessThan(result.estimatedSize, 200)
    }
    
    // MARK: - Utility Method Tests
    
    func testMarkAsRead() {
        // Given
        let originalResult = SharedScanResult(
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: validConfidence,
            isNew: true
        )
        
        // When
        let readResult = originalResult.markAsRead()
        
        // Then
        XCTAssertEqual(readResult.scanId, originalResult.scanId)
        XCTAssertEqual(readResult.riskLevel, originalResult.riskLevel)
        XCTAssertEqual(readResult.category, originalResult.category)
        XCTAssertEqual(readResult.confidence, originalResult.confidence)
        XCTAssertEqual(readResult.timestamp, originalResult.timestamp)
        XCTAssertFalse(readResult.isNew) // Should be marked as read
        XCTAssertTrue(originalResult.isNew) // Original should be unchanged
    }
    
    func testIsOlderThan() {
        // Given
        let oldTimestamp = Date().addingTimeInterval(-3600) // 1 hour ago
        let oldResult = SharedScanResult(
            scanId: "test-123",
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: validConfidence,
            timestamp: oldTimestamp,
            isNew: true
        )
        
        let recentResult = SharedScanResult(
            riskLevel: validRiskLevel,
            category: validCategory,
            confidence: validConfidence
        )
        
        // Then
        XCTAssertTrue(oldResult.isOlderThan(1800)) // 30 minutes
        XCTAssertFalse(oldResult.isOlderThan(7200)) // 2 hours
        XCTAssertFalse(recentResult.isOlderThan(60)) // 1 minute
    }
    
    func testBannerMessage() {
        // Given
        let highRiskResult = SharedScanResult(
            riskLevel: "high",
            category: "Payment Scam",
            confidence: 0.95
        )
        
        let lowRiskResult = SharedScanResult(
            riskLevel: "low",
            category: "Safe Content",
            confidence: 0.98
        )
        
        // Then
        XCTAssertEqual(highRiskResult.bannerMessage, "Latest scan: High Risk - Payment Scam")
        XCTAssertEqual(lowRiskResult.bannerMessage, "Latest scan: Low Risk - Safe Content")
    }
    
    // MARK: - Codable Tests
    
    func testCodableRoundTrip() throws {
        // Given
        let originalResult = SharedScanResult(
            scanId: "test-scan-123",
            riskLevel: "high",
            category: "Identity Theft",
            confidence: 0.92,
            timestamp: testTimestamp,
            isNew: false
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalResult)
        
        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(SharedScanResult.self, from: data)
        
        // Then
        XCTAssertEqual(decodedResult.scanId, originalResult.scanId)
        XCTAssertEqual(decodedResult.riskLevel, originalResult.riskLevel)
        XCTAssertEqual(decodedResult.category, originalResult.category)
        XCTAssertEqual(decodedResult.confidence, originalResult.confidence)
        XCTAssertEqual(decodedResult.timestamp.timeIntervalSince1970, 
                      originalResult.timestamp.timeIntervalSince1970, 
                      accuracy: 0.001)
        XCTAssertEqual(decodedResult.isNew, originalResult.isNew)
    }
    
    // MARK: - Equatable Tests
    
    func testEquality() {
        // Given
        let result1 = SharedScanResult(
            scanId: "same-id",
            riskLevel: "medium",
            category: "Test Category",
            confidence: 0.8,
            timestamp: testTimestamp,
            isNew: true
        )
        
        let result2 = SharedScanResult(
            scanId: "same-id",
            riskLevel: "medium",
            category: "Test Category",
            confidence: 0.8,
            timestamp: testTimestamp,
            isNew: true
        )
        
        let differentResult = SharedScanResult(
            scanId: "different-id",
            riskLevel: "medium",
            category: "Test Category",
            confidence: 0.8,
            timestamp: testTimestamp,
            isNew: true
        )
        
        // Then
        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, differentResult)
    }
    
    // MARK: - Static Methods Tests
    
    func testSampleCreation() {
        // Given
        let defaultSample = SharedScanResult.sample()
        let customSample = SharedScanResult.sample(riskLevel: "high", category: "Payment Scam")
        
        // Then
        XCTAssertEqual(defaultSample.riskLevel, "medium")
        XCTAssertEqual(defaultSample.category, "OTP Phishing")
        XCTAssertEqual(defaultSample.confidence, 0.85)
        
        XCTAssertEqual(customSample.riskLevel, "high")
        XCTAssertEqual(customSample.category, "Payment Scam")
        XCTAssertEqual(customSample.confidence, 0.85)
    }
    
    func testValidCategories() {
        // Then
        XCTAssertTrue(SharedScanResult.validCategories.contains("OTP Phishing"))
        XCTAssertTrue(SharedScanResult.validCategories.contains("Payment Scam"))
        XCTAssertTrue(SharedScanResult.validCategories.contains("Identity Theft"))
        XCTAssertTrue(SharedScanResult.validCategories.contains("Unknown Risk"))
        XCTAssertFalse(SharedScanResult.validCategories.isEmpty)
    }
    
    func testValidRiskLevels() {
        // Then
        XCTAssertTrue(SharedScanResult.validRiskLevels.contains("low"))
        XCTAssertTrue(SharedScanResult.validRiskLevels.contains("medium"))
        XCTAssertTrue(SharedScanResult.validRiskLevels.contains("high"))
        XCTAssertTrue(SharedScanResult.validRiskLevels.contains("none"))
        XCTAssertEqual(SharedScanResult.validRiskLevels.count, 4)
    }
}
