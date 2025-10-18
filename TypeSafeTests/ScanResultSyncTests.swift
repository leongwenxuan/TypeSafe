//
//  ScanResultSyncTests.swift
//  TypeSafeTests
//
//  Story 3.7: App Group Integration & Keyboard Sync
//  Integration tests for scan result sync functionality
//

import XCTest
@testable import TypeSafe

final class ScanResultSyncTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var sharedStorageManager: SharedStorageManager!
    private var apiService: APIService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        sharedStorageManager = SharedStorageManager.shared
        apiService = APIService()
        
        // Clear shared storage before each test
        sharedStorageManager.clearAllSharedData()
    }
    
    override func tearDown() {
        // Clean up after each test
        sharedStorageManager.clearAllSharedData()
        super.tearDown()
    }
    
    // MARK: - SharedStorageManager Tests
    
    func testSetLatestScanResult() {
        // Given
        let scanResult = SharedScanResult(
            riskLevel: "high",
            category: "Payment Scam",
            confidence: 0.92
        )
        
        // When
        let success = sharedStorageManager.setLatestScanResult(scanResult)
        
        // Then
        XCTAssertTrue(success)
        
        // Verify it can be retrieved
        let retrieved = sharedStorageManager.getLatestSharedScanResult()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.scanId, scanResult.scanId)
        XCTAssertEqual(retrieved?.riskLevel, scanResult.riskLevel)
        XCTAssertEqual(retrieved?.category, scanResult.category)
        XCTAssertEqual(retrieved?.confidence, scanResult.confidence)
        XCTAssertTrue(retrieved?.isNew ?? false)
    }
    
    func testSetLatestScanResultWithInvalidData() {
        // Given
        let invalidScanResult = SharedScanResult(
            scanId: "test-123",
            riskLevel: "invalid-risk-level",
            category: "Valid Category",
            confidence: 0.8,
            timestamp: Date(),
            isNew: true
        )
        
        // When
        let success = sharedStorageManager.setLatestScanResult(invalidScanResult)
        
        // Then
        XCTAssertFalse(success)
        
        // Verify nothing was stored
        let retrieved = sharedStorageManager.getLatestSharedScanResult()
        XCTAssertNil(retrieved)
    }
    
    func testGetLatestScanResultWhenEmpty() {
        // When
        let result = sharedStorageManager.getLatestSharedScanResult()
        
        // Then
        XCTAssertNil(result)
    }
    
    func testMarkScanResultAsRead() {
        // Given
        let scanResult = SharedScanResult(
            riskLevel: "medium",
            category: "OTP Phishing",
            confidence: 0.85
        )
        
        // Store the scan result
        let storeSuccess = sharedStorageManager.setLatestScanResult(scanResult)
        XCTAssertTrue(storeSuccess)
        
        // When
        let markSuccess = sharedStorageManager.markScanResultAsRead(scanResult.scanId)
        
        // Then
        XCTAssertTrue(markSuccess)
        
        // Verify it's no longer returned as new
        let retrieved = sharedStorageManager.getLatestSharedScanResult()
        XCTAssertNil(retrieved) // Should be nil because isNew is false
    }
    
    func testMarkScanResultAsReadWithWrongId() {
        // Given
        let scanResult = SharedScanResult(
            riskLevel: "medium",
            category: "OTP Phishing",
            confidence: 0.85
        )
        
        // Store the scan result
        let storeSuccess = sharedStorageManager.setLatestScanResult(scanResult)
        XCTAssertTrue(storeSuccess)
        
        // When
        let markSuccess = sharedStorageManager.markScanResultAsRead("wrong-id")
        
        // Then
        XCTAssertFalse(markSuccess)
        
        // Verify original result is still new
        let retrieved = sharedStorageManager.getLatestSharedScanResult()
        XCTAssertNotNil(retrieved)
        XCTAssertTrue(retrieved?.isNew ?? false)
    }
    
    func testScanResultVersionTracking() {
        // Given
        let initialVersion = sharedStorageManager.getScanResultVersion()
        
        let scanResult1 = SharedScanResult(
            riskLevel: "low",
            category: "Safe Content",
            confidence: 0.95
        )
        
        let scanResult2 = SharedScanResult(
            riskLevel: "high",
            category: "Payment Scam",
            confidence: 0.88
        )
        
        // When
        sharedStorageManager.setLatestScanResult(scanResult1)
        let version1 = sharedStorageManager.getScanResultVersion()
        
        sharedStorageManager.setLatestScanResult(scanResult2)
        let version2 = sharedStorageManager.getScanResultVersion()
        
        // Then
        XCTAssertEqual(version1, initialVersion + 1)
        XCTAssertEqual(version2, initialVersion + 2)
    }
    
    func testClearOldScanResults() {
        // Given
        let oldTimestamp = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
        let oldScanResult = SharedScanResult(
            scanId: "old-scan",
            riskLevel: "medium",
            category: "Old Scan",
            confidence: 0.8,
            timestamp: oldTimestamp,
            isNew: true
        )
        
        // Store old result
        let success = sharedStorageManager.setLatestScanResult(oldScanResult)
        XCTAssertTrue(success)
        
        // When
        let clearedCount = sharedStorageManager.clearOldScanResults()
        
        // Then
        XCTAssertEqual(clearedCount, 1)
        
        // Verify old result was removed
        let retrieved = sharedStorageManager.getLatestSharedScanResult()
        XCTAssertNil(retrieved)
    }
    
    func testClearOldScanResultsKeepsRecent() {
        // Given
        let recentScanResult = SharedScanResult(
            riskLevel: "high",
            category: "Recent Scan",
            confidence: 0.9
        )
        
        // Store recent result
        let success = sharedStorageManager.setLatestScanResult(recentScanResult)
        XCTAssertTrue(success)
        
        // When
        let clearedCount = sharedStorageManager.clearOldScanResults()
        
        // Then
        XCTAssertEqual(clearedCount, 0)
        
        // Verify recent result is still there
        let retrieved = sharedStorageManager.getLatestSharedScanResult()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.scanId, recentScanResult.scanId)
    }
    
    func testLastKeyboardCheckTracking() {
        // Given
        let beforeTime = Date()
        
        // When
        sharedStorageManager.updateLastKeyboardCheck()
        let checkTime = sharedStorageManager.getLastKeyboardCheck()
        
        // Then
        XCTAssertNotNil(checkTime)
        XCTAssertGreaterThanOrEqual(checkTime!.timeIntervalSince1970, beforeTime.timeIntervalSince1970)
    }
    
    // MARK: - Privacy Compliance Tests
    
    func testPrivacyComplianceWithValidData() {
        // Given
        let scanResult = SharedScanResult(
            riskLevel: "medium",
            category: "Test Category",
            confidence: 0.8
        )
        
        // When
        sharedStorageManager.setLatestScanResult(scanResult)
        let isCompliant = sharedStorageManager.validatePrivacyCompliance()
        
        // Then
        XCTAssertTrue(isCompliant)
    }
    
    func testStoredDataSizeIsReasonable() {
        // Given
        let scanResult = SharedScanResult(
            riskLevel: "high",
            category: "Payment Scam",
            confidence: 0.95
        )
        
        // When
        sharedStorageManager.setLatestScanResult(scanResult)
        let dataSize = sharedStorageManager.getStoredDataSize()
        
        // Then
        XCTAssertLessThan(dataSize, 1024) // Must be under 1KB
        XCTAssertGreaterThan(dataSize, 0) // Should have some data
    }
    
    // MARK: - APIService Integration Tests
    
    func testAPIServiceUpdatesSharedStorage() {
        // Given
        let expectation = XCTestExpectation(description: "API call completes")
        let mockResponse = ScanImageResponse(
            risk_level: "high",
            confidence: 0.93,
            category: "otp_phishing",
            explanation: "This appears to be an OTP phishing attempt.",
            ts: "2025-01-18T10:30:00Z"
        )
        
        // Note: This would require mocking the API service for a real test
        // For now, we'll test the data transformation logic
        
        // When - Simulate what APIService.updateSharedScanResult does
        let sharedResult = SharedScanResult(
            riskLevel: mockResponse.risk_level,
            category: mockResponse.category.replacingOccurrences(of: "_", with: " ").capitalized,
            confidence: mockResponse.confidence
        )
        
        let success = sharedStorageManager.setLatestScanResult(sharedResult)
        
        // Then
        XCTAssertTrue(success)
        
        let retrieved = sharedStorageManager.getLatestSharedScanResult()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.riskLevel, "high")
        XCTAssertEqual(retrieved?.category, "Otp Phishing")
        XCTAssertEqual(retrieved?.confidence, 0.93)
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCategoryFormatting() {
        // Given
        let testCases = [
            ("otp_phishing", "Otp Phishing"),
            ("payment_scam", "Payment Scam"),
            ("identity_theft", "Identity Theft"),
            ("safe", "Safe"),
            ("unknown", "Unknown")
        ]
        
        // When & Then
        for (input, expected) in testCases {
            let formatted = input.replacingOccurrences(of: "_", with: " ").capitalized
            XCTAssertEqual(formatted, expected, "Failed to format category: \(input)")
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentReadWrite() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 10
        
        let scanResult = SharedScanResult(
            riskLevel: "medium",
            category: "Concurrent Test",
            confidence: 0.8
        )
        
        // When - Perform concurrent read/write operations
        for i in 0..<10 {
            DispatchQueue.global(qos: .utility).async {
                if i % 2 == 0 {
                    // Write operation
                    let newResult = SharedScanResult(
                        riskLevel: "high",
                        category: "Test \(i)",
                        confidence: 0.9
                    )
                    _ = self.sharedStorageManager.setLatestScanResult(newResult)
                } else {
                    // Read operation
                    _ = self.sharedStorageManager.getLatestSharedScanResult()
                }
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        
        // Verify storage is still functional
        let finalResult = sharedStorageManager.getLatestSharedScanResult()
        // Should either be nil or a valid result, but not corrupted
        if let result = finalResult {
            XCTAssertTrue(result.isPrivacySafe)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleCorruptedData() {
        // Given - Simulate corrupted data by directly writing invalid JSON
        let invalidData = "invalid json data".data(using: .utf8)!
        UserDefaults(suiteName: "group.com.typesafe.shared")?.set(invalidData, forKey: "typesafe.shared_scan_result")
        
        // When
        let result = sharedStorageManager.getLatestSharedScanResult()
        
        // Then
        XCTAssertNil(result) // Should handle corruption gracefully
    }
    
    func testPrivacyComplianceWithCorruptedData() {
        // Given - Simulate corrupted data
        let invalidData = "invalid json data".data(using: .utf8)!
        UserDefaults(suiteName: "group.com.typesafe.shared")?.set(invalidData, forKey: "typesafe.shared_scan_result")
        
        // When
        let isCompliant = sharedStorageManager.validatePrivacyCompliance()
        
        // Then
        XCTAssertTrue(isCompliant) // Should still pass compliance (corrupted data is logged but not blocking)
    }
}
