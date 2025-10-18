//
//  SharedStorageManagerTests.swift
//  TypeSafeTests
//
//  Story 2.7: App Group Shared State - Unit Tests
//  Tests for SharedStorageManager functionality
//

import XCTest
@testable import TypeSafe

class SharedStorageManagerTests: XCTestCase {
    
    var sharedStorageManager: SharedStorageManager!
    
    override func setUp() {
        super.setUp()
        sharedStorageManager = SharedStorageManager()
        // Clear any existing data before each test
        sharedStorageManager.clearAllSharedData()
    }
    
    override func tearDown() {
        // Clean up after each test
        sharedStorageManager.clearAllSharedData()
        sharedStorageManager = nil
        super.tearDown()
    }
    
    // MARK: - Scan Result Tests
    
    func testStoreScanResult_ValidData_Success() {
        // Given
        let scanResult = SharedStorageManager.ScanResult(
            riskLevel: "high",
            category: "financial",
            timestamp: Date(),
            hasRisks: true
        )
        
        // When
        let success = sharedStorageManager.storeLatestScanResult(scanResult)
        
        // Then
        XCTAssertTrue(success, "Should successfully store valid scan result")
        
        let retrieved = sharedStorageManager.getLatestScanResult()
        XCTAssertNotNil(retrieved, "Should retrieve stored scan result")
        XCTAssertEqual(retrieved?.riskLevel, "high")
        XCTAssertEqual(retrieved?.category, "financial")
        XCTAssertEqual(retrieved?.hasRisks, true)
    }
    
    func testStoreScanResult_InvalidRiskLevel_Failure() {
        // Given - Invalid risk level
        let scanResult = SharedStorageManager.ScanResult(
            riskLevel: "invalid_level",
            category: "financial",
            timestamp: Date(),
            hasRisks: true
        )
        
        // When
        let success = sharedStorageManager.storeLatestScanResult(scanResult)
        
        // Then
        XCTAssertFalse(success, "Should reject scan result with invalid risk level")
        
        let retrieved = sharedStorageManager.getLatestScanResult()
        XCTAssertNil(retrieved, "Should not store invalid scan result")
    }
    
    func testStoreScanResult_InvalidCategory_Failure() {
        // Given - Invalid category
        let scanResult = SharedStorageManager.ScanResult(
            riskLevel: "high",
            category: "invalid_category",
            timestamp: Date(),
            hasRisks: true
        )
        
        // When
        let success = sharedStorageManager.storeLatestScanResult(scanResult)
        
        // Then
        XCTAssertFalse(success, "Should reject scan result with invalid category")
        
        let retrieved = sharedStorageManager.getLatestScanResult()
        XCTAssertNil(retrieved, "Should not store invalid scan result")
    }
    
    func testGetScanResult_NoData_ReturnsNil() {
        // When
        let retrieved = sharedStorageManager.getLatestScanResult()
        
        // Then
        XCTAssertNil(retrieved, "Should return nil when no scan result is stored")
    }
    
    // MARK: - Timestamp Tests
    
    func testUpdateAnalysisTimestamp_Success() {
        // Given
        let testDate = Date()
        
        // When
        sharedStorageManager.updateLastAnalysisTimestamp(testDate)
        
        // Then
        let retrieved = sharedStorageManager.getLastAnalysisTimestamp()
        XCTAssertNotNil(retrieved, "Should retrieve stored timestamp")
        
        // Allow for small time difference due to processing
        let timeDifference = abs(retrieved!.timeIntervalSince(testDate))
        XCTAssertLessThan(timeDifference, 1.0, "Timestamps should be very close")
    }
    
    func testUpdateAnalysisTimestamp_DefaultDate_Success() {
        // When - Using default Date()
        sharedStorageManager.updateLastAnalysisTimestamp()
        
        // Then
        let retrieved = sharedStorageManager.getLastAnalysisTimestamp()
        XCTAssertNotNil(retrieved, "Should retrieve stored timestamp")
        
        // Should be very recent
        let timeDifference = abs(retrieved!.timeIntervalSinceNow)
        XCTAssertLessThan(timeDifference, 1.0, "Timestamp should be very recent")
    }
    
    func testGetAnalysisTimestamp_NoData_ReturnsNil() {
        // When
        let retrieved = sharedStorageManager.getLastAnalysisTimestamp()
        
        // Then
        XCTAssertNil(retrieved, "Should return nil when no timestamp is stored")
    }
    
    // MARK: - Alert Preferences Tests
    
    func testStoreAlertPreferences_Success() {
        // Given
        let preferences = SharedStorageManager.AlertPreferences(
            showBanners: false,
            enableHapticFeedback: false,
            riskThreshold: "high"
        )
        
        // When
        let success = sharedStorageManager.storeAlertPreferences(preferences)
        
        // Then
        XCTAssertTrue(success, "Should successfully store alert preferences")
        
        let retrieved = sharedStorageManager.getAlertPreferences()
        XCTAssertEqual(retrieved.showBanners, false)
        XCTAssertEqual(retrieved.enableHapticFeedback, false)
        XCTAssertEqual(retrieved.riskThreshold, "high")
    }
    
    func testGetAlertPreferences_NoData_ReturnsDefault() {
        // When
        let retrieved = sharedStorageManager.getAlertPreferences()
        
        // Then - Should return default values
        XCTAssertEqual(retrieved.showBanners, true)
        XCTAssertEqual(retrieved.enableHapticFeedback, true)
        XCTAssertEqual(retrieved.riskThreshold, "medium")
    }
    
    // MARK: - Privacy Settings Tests
    
    func testStorePrivacySettings_Success() {
        // Given
        let settings = SharedStorageManager.PrivacySettings(
            enableAnalytics: true,
            shareAnonymousData: true
        )
        
        // When
        let success = sharedStorageManager.storePrivacySettings(settings)
        
        // Then
        XCTAssertTrue(success, "Should successfully store privacy settings")
        
        let retrieved = sharedStorageManager.getPrivacySettings()
        XCTAssertEqual(retrieved.enableAnalytics, true)
        XCTAssertEqual(retrieved.shareAnonymousData, true)
    }
    
    func testGetPrivacySettings_NoData_ReturnsDefault() {
        // When
        let retrieved = sharedStorageManager.getPrivacySettings()
        
        // Then - Should return default values
        XCTAssertEqual(retrieved.enableAnalytics, false)
        XCTAssertEqual(retrieved.shareAnonymousData, false)
    }
    
    // MARK: - Privacy Compliance Tests
    
    func testValidatePrivacyCompliance_EmptyData_Success() {
        // When
        let isCompliant = sharedStorageManager.validatePrivacyCompliance()
        
        // Then
        XCTAssertTrue(isCompliant, "Empty data should be privacy compliant")
    }
    
    func testValidatePrivacyCompliance_WithValidData_Success() {
        // Given - Store valid data
        let scanResult = SharedStorageManager.ScanResult(
            riskLevel: "medium",
            category: "personal",
            timestamp: Date(),
            hasRisks: true
        )
        sharedStorageManager.storeLatestScanResult(scanResult)
        sharedStorageManager.updateLastAnalysisTimestamp()
        
        let preferences = SharedStorageManager.AlertPreferences(
            showBanners: true,
            enableHapticFeedback: false,
            riskThreshold: "low"
        )
        sharedStorageManager.storeAlertPreferences(preferences)
        
        // When
        let isCompliant = sharedStorageManager.validatePrivacyCompliance()
        
        // Then
        XCTAssertTrue(isCompliant, "Valid data should be privacy compliant")
    }
    
    func testGetStoredDataSize_WithData_ReturnsReasonableSize() {
        // Given - Store some data
        let scanResult = SharedStorageManager.ScanResult(
            riskLevel: "high",
            category: "financial",
            timestamp: Date(),
            hasRisks: true
        )
        sharedStorageManager.storeLatestScanResult(scanResult)
        sharedStorageManager.updateLastAnalysisTimestamp()
        
        // When
        let dataSize = sharedStorageManager.getStoredDataSize()
        
        // Then
        XCTAssertGreaterThan(dataSize, 0, "Should have some data stored")
        XCTAssertLessThan(dataSize, 1024, "Should be under 1KB limit")
    }
    
    // MARK: - Data Clearing Tests
    
    func testClearAllSharedData_Success() {
        // Given - Store some data
        let scanResult = SharedStorageManager.ScanResult(
            riskLevel: "low",
            category: "work",
            timestamp: Date(),
            hasRisks: false
        )
        sharedStorageManager.storeLatestScanResult(scanResult)
        sharedStorageManager.updateLastAnalysisTimestamp()
        
        // Verify data exists
        XCTAssertNotNil(sharedStorageManager.getLatestScanResult())
        XCTAssertNotNil(sharedStorageManager.getLastAnalysisTimestamp())
        
        // When
        sharedStorageManager.clearAllSharedData()
        
        // Then
        XCTAssertNil(sharedStorageManager.getLatestScanResult())
        XCTAssertNil(sharedStorageManager.getLastAnalysisTimestamp())
        
        // Preferences should return to defaults
        let preferences = sharedStorageManager.getAlertPreferences()
        XCTAssertEqual(preferences.showBanners, true)
        XCTAssertEqual(preferences.enableHapticFeedback, true)
        XCTAssertEqual(preferences.riskThreshold, "medium")
    }
    
    // MARK: - Privacy Validation Tests
    
    func testScanResultPrivacyValidation_ValidRiskLevels() {
        let validRiskLevels = ["low", "medium", "high", "none"]
        
        for riskLevel in validRiskLevels {
            let scanResult = SharedStorageManager.ScanResult(
                riskLevel: riskLevel,
                category: "financial",
                timestamp: Date(),
                hasRisks: riskLevel != "low" && riskLevel != "none"
            )
            
            XCTAssertTrue(scanResult.isPrivacySafe, "Risk level '\(riskLevel)' should be valid")
        }
    }
    
    func testScanResultPrivacyValidation_ValidCategories() {
        let validCategories = ["financial", "personal", "work", "social", "unknown"]
        
        for category in validCategories {
            let scanResult = SharedStorageManager.ScanResult(
                riskLevel: "medium",
                category: category,
                timestamp: Date(),
                hasRisks: true
            )
            
            XCTAssertTrue(scanResult.isPrivacySafe, "Category '\(category)' should be valid")
        }
    }
    
    func testScanResultPrivacyValidation_InvalidData() {
        let invalidScanResult = SharedStorageManager.ScanResult(
            riskLevel: "invalid",
            category: "invalid",
            timestamp: Date(),
            hasRisks: true
        )
        
        XCTAssertFalse(invalidScanResult.isPrivacySafe, "Invalid data should fail privacy validation")
    }
}
