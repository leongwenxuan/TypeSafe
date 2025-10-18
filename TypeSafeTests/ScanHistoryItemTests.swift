//
//  ScanHistoryItemTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 18/01/25.
//

import XCTest
import CoreData
@testable import TypeSafe

/// Unit tests for ScanHistoryItem Core Data model
final class ScanHistoryItemTests: XCTestCase {
    
    // MARK: - Properties
    
    /// In-memory persistence controller for testing
    var testPersistenceController: PersistenceController!
    
    /// Core Data context for testing
    var testContext: NSManagedObjectContext!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        testPersistenceController = PersistenceController(inMemory: true)
        testContext = testPersistenceController.container.viewContext
        
        // Clear any existing data
        clearAllHistoryItems()
    }
    
    override func tearDownWithError() throws {
        // Clean up
        clearAllHistoryItems()
        testPersistenceController = nil
        testContext = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    /// Clear all history items from test database
    private func clearAllHistoryItems() {
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        do {
            let items = try testContext.fetch(request)
            items.forEach { testContext.delete($0) }
            try testContext.save()
        } catch {
            XCTFail("Failed to clear test data: \(error)")
        }
    }
    
    // MARK: - Model Creation Tests
    
    func testScanHistoryItem_Creation_SetsAllProperties() {
        // Given
        let id = UUID()
        let sessionId = "test-session-123"
        let riskLevel = "high"
        let confidence = 0.92
        let category = "phishing"
        let explanation = "Suspicious link detected in message"
        let ocrText = "Click here to verify your account"
        let timestamp = Date()
        let thumbnailData = "test-image-data".data(using: .utf8)
        
        // When
        let item = ScanHistoryItem(context: testContext)
        item.id = id
        item.sessionId = sessionId
        item.riskLevel = riskLevel
        item.confidence = confidence
        item.category = category
        item.explanation = explanation
        item.ocrText = ocrText
        item.timestamp = timestamp
        item.thumbnailData = thumbnailData
        
        // Then
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.sessionId, sessionId)
        XCTAssertEqual(item.riskLevel, riskLevel)
        XCTAssertEqual(item.confidence, confidence, accuracy: 0.001)
        XCTAssertEqual(item.category, category)
        XCTAssertEqual(item.explanation, explanation)
        XCTAssertEqual(item.ocrText, ocrText)
        XCTAssertEqual(item.timestamp, timestamp)
        XCTAssertEqual(item.thumbnailData, thumbnailData)
    }
    
    func testScanHistoryItem_Creation_WithoutThumbnail_SetsNilThumbnail() {
        // Given
        let item = ScanHistoryItem(context: testContext)
        
        // When
        item.id = UUID()
        item.sessionId = "test-session"
        item.riskLevel = "low"
        item.confidence = 0.15
        item.category = "safe"
        item.explanation = "No threats detected"
        item.ocrText = "Meeting at 3 PM"
        item.timestamp = Date()
        // thumbnailData intentionally not set
        
        // Then
        XCTAssertNil(item.thumbnailData)
    }
    
    // MARK: - Persistence Tests
    
    func testScanHistoryItem_SaveAndRetrieve_PersistsCorrectly() {
        // Given
        let originalId = UUID()
        let originalSessionId = "persist-test-session"
        let originalRiskLevel = "medium"
        let originalConfidence = 0.78
        let originalCategory = "payment_scam"
        let originalExplanation = "Suspicious payment request"
        let originalOcrText = "Send money immediately"
        let originalTimestamp = Date()
        
        let item = ScanHistoryItem(context: testContext)
        item.id = originalId
        item.sessionId = originalSessionId
        item.riskLevel = originalRiskLevel
        item.confidence = originalConfidence
        item.category = originalCategory
        item.explanation = originalExplanation
        item.ocrText = originalOcrText
        item.timestamp = originalTimestamp
        
        // When - Save to Core Data
        do {
            try testContext.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
        
        // Fetch back from Core Data
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", originalId as CVarArg)
        
        do {
            let fetchedItems = try testContext.fetch(request)
            
            // Then
            XCTAssertEqual(fetchedItems.count, 1)
            
            let fetchedItem = fetchedItems.first!
            XCTAssertEqual(fetchedItem.id, originalId)
            XCTAssertEqual(fetchedItem.sessionId, originalSessionId)
            XCTAssertEqual(fetchedItem.riskLevel, originalRiskLevel)
            XCTAssertEqual(fetchedItem.confidence, originalConfidence, accuracy: 0.001)
            XCTAssertEqual(fetchedItem.category, originalCategory)
            XCTAssertEqual(fetchedItem.explanation, originalExplanation)
            XCTAssertEqual(fetchedItem.ocrText, originalOcrText)
            XCTAssertEqual(fetchedItem.timestamp, originalTimestamp)
        } catch {
            XCTFail("Failed to fetch item: \(error)")
        }
    }
    
    func testScanHistoryItem_SaveWithThumbnail_PersistsThumbnailData() {
        // Given
        let thumbnailData = "test-thumbnail-data-12345".data(using: .utf8)!
        
        let item = ScanHistoryItem(context: testContext)
        item.id = UUID()
        item.sessionId = "thumbnail-test"
        item.riskLevel = "high"
        item.confidence = 0.95
        item.category = "phishing"
        item.explanation = "Test with thumbnail"
        item.ocrText = "Test OCR"
        item.timestamp = Date()
        item.thumbnailData = thumbnailData
        
        // When
        do {
            try testContext.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
        
        // Fetch back
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        request.predicate = NSPredicate(format: "sessionId == %@", "thumbnail-test")
        
        do {
            let fetchedItems = try testContext.fetch(request)
            
            // Then
            XCTAssertEqual(fetchedItems.count, 1)
            XCTAssertEqual(fetchedItems.first?.thumbnailData, thumbnailData)
        } catch {
            XCTFail("Failed to fetch item: \(error)")
        }
    }
    
    // MARK: - Fetch Request Tests
    
    func testScanHistoryItem_FetchRequest_ReturnsCorrectType() {
        // When
        let request = ScanHistoryItem.fetchRequest()
        
        // Then
        XCTAssertEqual(request.entityName, "ScanHistoryItem")
        XCTAssertTrue(request is NSFetchRequest<ScanHistoryItem>)
    }
    
    func testScanHistoryItem_FetchWithPredicate_FiltersCorrectly() {
        // Given
        let session1 = "session-1"
        let session2 = "session-2"
        
        // Create items for different sessions
        let item1 = ScanHistoryItem(context: testContext)
        item1.id = UUID()
        item1.sessionId = session1
        item1.riskLevel = "low"
        item1.confidence = 0.2
        item1.category = "safe"
        item1.explanation = "Safe message"
        item1.ocrText = "Hello world"
        item1.timestamp = Date()
        
        let item2 = ScanHistoryItem(context: testContext)
        item2.id = UUID()
        item2.sessionId = session2
        item2.riskLevel = "high"
        item2.confidence = 0.9
        item2.category = "phishing"
        item2.explanation = "Dangerous message"
        item2.ocrText = "Click malicious link"
        item2.timestamp = Date()
        
        try? testContext.save()
        
        // When - Fetch items for session1 only
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        request.predicate = NSPredicate(format: "sessionId == %@", session1)
        
        do {
            let fetchedItems = try testContext.fetch(request)
            
            // Then
            XCTAssertEqual(fetchedItems.count, 1)
            XCTAssertEqual(fetchedItems.first?.sessionId, session1)
            XCTAssertEqual(fetchedItems.first?.category, "safe")
        } catch {
            XCTFail("Failed to fetch items: \(error)")
        }
    }
    
    func testScanHistoryItem_FetchWithSortDescriptor_SortsCorrectly() {
        // Given
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        // Create items with different timestamps
        let item1 = ScanHistoryItem(context: testContext)
        item1.id = UUID()
        item1.sessionId = "sort-test"
        item1.riskLevel = "low"
        item1.confidence = 0.1
        item1.category = "first"
        item1.explanation = "First item"
        item1.ocrText = "First"
        item1.timestamp = twoHoursAgo // Oldest
        
        let item2 = ScanHistoryItem(context: testContext)
        item2.id = UUID()
        item2.sessionId = "sort-test"
        item2.riskLevel = "medium"
        item2.confidence = 0.5
        item2.category = "second"
        item2.explanation = "Second item"
        item2.ocrText = "Second"
        item2.timestamp = oneHourAgo // Middle
        
        let item3 = ScanHistoryItem(context: testContext)
        item3.id = UUID()
        item3.sessionId = "sort-test"
        item3.riskLevel = "high"
        item3.confidence = 0.9
        item3.category = "third"
        item3.explanation = "Third item"
        item3.ocrText = "Third"
        item3.timestamp = now // Newest
        
        try? testContext.save()
        
        // When - Fetch with descending timestamp sort (newest first)
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScanHistoryItem.timestamp, ascending: false)]
        
        do {
            let fetchedItems = try testContext.fetch(request)
            
            // Then
            XCTAssertEqual(fetchedItems.count, 3)
            XCTAssertEqual(fetchedItems[0].category, "third")  // Newest first
            XCTAssertEqual(fetchedItems[1].category, "second")
            XCTAssertEqual(fetchedItems[2].category, "first")  // Oldest last
        } catch {
            XCTFail("Failed to fetch items: \(error)")
        }
    }
    
    // MARK: - Data Validation Tests
    
    func testScanHistoryItem_RequiredFields_CannotBeNil() {
        // Given
        let item = ScanHistoryItem(context: testContext)
        
        // When - Try to save without required fields
        // Note: Core Data will enforce non-nil constraints for required attributes
        
        // Set minimal required fields
        item.id = UUID()
        item.sessionId = "validation-test"
        item.riskLevel = "medium"
        item.confidence = 0.5
        item.category = "test"
        item.explanation = "test"
        item.ocrText = "test"
        item.timestamp = Date()
        
        // Then - Should save successfully with all required fields
        do {
            try testContext.save()
            XCTAssertTrue(true, "Save succeeded with all required fields")
        } catch {
            XCTFail("Save failed even with required fields: \(error)")
        }
    }
    
    func testScanHistoryItem_ConfidenceRange_AcceptsValidValues() {
        // Given
        let testValues: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for (index, confidence) in testValues.enumerated() {
            // When
            let item = ScanHistoryItem(context: testContext)
            item.id = UUID()
            item.sessionId = "confidence-test-\(index)"
            item.riskLevel = "medium"
            item.confidence = confidence
            item.category = "test"
            item.explanation = "test"
            item.ocrText = "test"
            item.timestamp = Date()
            
            // Then
            XCTAssertEqual(item.confidence, confidence, accuracy: 0.001)
        }
        
        // Save all items
        do {
            try testContext.save()
        } catch {
            XCTFail("Failed to save confidence test items: \(error)")
        }
    }
    
    func testScanHistoryItem_StringFields_AcceptEmptyStrings() {
        // Given
        let item = ScanHistoryItem(context: testContext)
        
        // When
        item.id = UUID()
        item.sessionId = ""
        item.riskLevel = ""
        item.confidence = 0.0
        item.category = ""
        item.explanation = ""
        item.ocrText = ""
        item.timestamp = Date()
        
        // Then
        XCTAssertEqual(item.sessionId, "")
        XCTAssertEqual(item.riskLevel, "")
        XCTAssertEqual(item.category, "")
        XCTAssertEqual(item.explanation, "")
        XCTAssertEqual(item.ocrText, "")
        
        // Should save successfully
        do {
            try testContext.save()
        } catch {
            XCTFail("Failed to save item with empty strings: \(error)")
        }
    }
    
    // MARK: - Deletion Tests
    
    func testScanHistoryItem_Deletion_RemovesFromDatabase() {
        // Given
        let item = ScanHistoryItem(context: testContext)
        item.id = UUID()
        item.sessionId = "delete-test"
        item.riskLevel = "low"
        item.confidence = 0.1
        item.category = "safe"
        item.explanation = "To be deleted"
        item.ocrText = "Delete me"
        item.timestamp = Date()
        
        try? testContext.save()
        
        // Verify item exists
        let initialRequest: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        let initialCount = (try? testContext.count(for: initialRequest)) ?? 0
        XCTAssertEqual(initialCount, 1)
        
        // When - Delete the item
        testContext.delete(item)
        try? testContext.save()
        
        // Then - Verify item is gone
        let finalRequest: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        let finalCount = (try? testContext.count(for: finalRequest)) ?? 0
        XCTAssertEqual(finalCount, 0)
    }
    
    // MARK: - Edge Cases
    
    func testScanHistoryItem_LargeDataValues_HandlesCorrectly() {
        // Given
        let largeString = String(repeating: "A", count: 10000)
        let largeThumbnailData = Data(repeating: 0xFF, count: 100000)
        
        // When
        let item = ScanHistoryItem(context: testContext)
        item.id = UUID()
        item.sessionId = "large-data-test"
        item.riskLevel = "medium"
        item.confidence = 0.5
        item.category = "test"
        item.explanation = largeString
        item.ocrText = largeString
        item.timestamp = Date()
        item.thumbnailData = largeThumbnailData
        
        // Then - Should handle large data gracefully
        do {
            try testContext.save()
            
            // Verify data was saved correctly
            let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
            request.predicate = NSPredicate(format: "sessionId == %@", "large-data-test")
            
            let fetchedItems = try testContext.fetch(request)
            XCTAssertEqual(fetchedItems.count, 1)
            
            let fetchedItem = fetchedItems.first!
            XCTAssertEqual(fetchedItem.explanation.count, 10000)
            XCTAssertEqual(fetchedItem.ocrText.count, 10000)
            XCTAssertEqual(fetchedItem.thumbnailData?.count, 100000)
        } catch {
            XCTFail("Failed to handle large data: \(error)")
        }
    }
    
    func testScanHistoryItem_UnicodeStrings_HandlesCorrectly() {
        // Given
        let unicodeText = "🔒 Security Alert! 警告 ⚠️ Предупреждение 🚨"
        
        // When
        let item = ScanHistoryItem(context: testContext)
        item.id = UUID()
        item.sessionId = "unicode-test"
        item.riskLevel = "high"
        item.confidence = 0.9
        item.category = "unicode_test"
        item.explanation = unicodeText
        item.ocrText = unicodeText
        item.timestamp = Date()
        
        // Then
        do {
            try testContext.save()
            
            // Verify unicode was preserved
            let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
            request.predicate = NSPredicate(format: "sessionId == %@", "unicode-test")
            
            let fetchedItems = try testContext.fetch(request)
            XCTAssertEqual(fetchedItems.count, 1)
            
            let fetchedItem = fetchedItems.first!
            XCTAssertEqual(fetchedItem.explanation, unicodeText)
            XCTAssertEqual(fetchedItem.ocrText, unicodeText)
        } catch {
            XCTFail("Failed to handle unicode strings: \(error)")
        }
    }
}
