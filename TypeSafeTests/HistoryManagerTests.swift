//
//  HistoryManagerTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 18/01/25.
//

import XCTest
import CoreData
@testable import TypeSafe

/// Unit tests for HistoryManager functionality
final class HistoryManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    /// In-memory persistence controller for testing
    var testPersistenceController: PersistenceController!
    
    /// History manager instance for testing
    var historyManager: HistoryManager!
    
    /// Core Data context for testing
    var testContext: NSManagedObjectContext!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        testPersistenceController = PersistenceController(inMemory: true)
        testContext = testPersistenceController.container.viewContext
        
        // Create history manager with test persistence controller
        historyManager = HistoryManager(persistenceController: testPersistenceController)
        
        // Clear any existing data
        clearAllHistoryItems()
    }
    
    override func tearDownWithError() throws {
        // Clean up
        clearAllHistoryItems()
        testPersistenceController = nil
        historyManager = nil
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
    
    /// Create a test history item with specified parameters
    private func createTestHistoryItem(
        sessionId: String = "test-session",
        riskLevel: String = "medium",
        confidence: Double = 0.85,
        category: String = "phishing",
        explanation: String = "Test explanation",
        ocrText: String = "Test OCR text",
        daysAgo: Int = 0
    ) {
        let timestamp = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        
        let item = ScanHistoryItem(context: testContext)
        item.id = UUID()
        item.sessionId = sessionId
        item.riskLevel = riskLevel
        item.confidence = confidence
        item.category = category
        item.explanation = explanation
        item.ocrText = ocrText
        item.timestamp = timestamp
        
        try? testContext.save()
    }
    
    // MARK: - Save to History Tests
    
    func testSaveToHistory_ValidData_CreatesHistoryItem() {
        // Given
        let sessionId = "test-session-123"
        let riskLevel = "high"
        let confidence = 0.92
        let category = "phishing"
        let explanation = "Suspicious link detected"
        let ocrText = "Click here to verify your account"
        
        // When
        historyManager.saveToHistory(
            sessionId: sessionId,
            riskLevel: riskLevel,
            confidence: confidence,
            category: category,
            explanation: explanation,
            ocrText: ocrText
        )
        
        // Then
        let items = historyManager.getRecentHistory()
        XCTAssertEqual(items.count, 1)
        
        let savedItem = items.first!
        XCTAssertEqual(savedItem.sessionId, sessionId)
        XCTAssertEqual(savedItem.riskLevel, riskLevel)
        XCTAssertEqual(savedItem.confidence, confidence, accuracy: 0.001)
        XCTAssertEqual(savedItem.category, category)
        XCTAssertEqual(savedItem.explanation, explanation)
        XCTAssertEqual(savedItem.ocrText, ocrText)
        XCTAssertNotNil(savedItem.id)
        XCTAssertNotNil(savedItem.timestamp)
    }
    
    func testSaveToHistory_WithThumbnailData_SavesThumbnail() {
        // Given
        let thumbnailData = "test-image-data".data(using: .utf8)!
        
        // When
        historyManager.saveToHistory(
            sessionId: "test-session",
            riskLevel: "low",
            confidence: 0.15,
            category: "safe",
            explanation: "No threats detected",
            ocrText: "Meeting at 3 PM",
            thumbnailData: thumbnailData
        )
        
        // Then
        let items = historyManager.getRecentHistory()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.thumbnailData, thumbnailData)
    }
    
    func testSaveToHistory_MultipleItems_SavesAllItems() {
        // Given & When
        for i in 1...3 {
            historyManager.saveToHistory(
                sessionId: "session-\(i)",
                riskLevel: "medium",
                confidence: 0.5 + Double(i) * 0.1,
                category: "category-\(i)",
                explanation: "Explanation \(i)",
                ocrText: "OCR text \(i)"
            )
        }
        
        // Then
        let items = historyManager.getRecentHistory()
        XCTAssertEqual(items.count, 3)
        
        // Verify items are sorted by timestamp (newest first)
        for i in 0..<items.count-1 {
            XCTAssertGreaterThanOrEqual(items[i].timestamp, items[i+1].timestamp)
        }
    }
    
    // MARK: - Get Recent History Tests
    
    func testGetRecentHistory_EmptyDatabase_ReturnsEmptyArray() {
        // When
        let items = historyManager.getRecentHistory()
        
        // Then
        XCTAssertTrue(items.isEmpty)
    }
    
    func testGetRecentHistory_WithItems_ReturnsNewestFirst() {
        // Given
        createTestHistoryItem(category: "first", daysAgo: 2)
        createTestHistoryItem(category: "second", daysAgo: 1)
        createTestHistoryItem(category: "third", daysAgo: 0)
        
        // When
        let items = historyManager.getRecentHistory()
        
        // Then
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].category, "third")  // Most recent
        XCTAssertEqual(items[1].category, "second")
        XCTAssertEqual(items[2].category, "first")  // Oldest
    }
    
    func testGetRecentHistory_MoreThan5Items_ReturnsOnly5() {
        // Given - Create 7 items
        for i in 1...7 {
            createTestHistoryItem(category: "item-\(i)", daysAgo: 7-i)
        }
        
        // When
        let items = historyManager.getRecentHistory()
        
        // Then
        XCTAssertEqual(items.count, 5)
    }
    
    func testGetRecentHistory_ItemsOlderThan7Days_ExcludesOldItems() {
        // Given
        createTestHistoryItem(category: "recent", daysAgo: 3)
        createTestHistoryItem(category: "old", daysAgo: 8)
        createTestHistoryItem(category: "very-old", daysAgo: 10)
        
        // When
        let items = historyManager.getRecentHistory()
        
        // Then
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.category, "recent")
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupOldHistory_ItemsOlderThan7Days_RemovesOldItems() {
        // Given
        createTestHistoryItem(category: "keep-1", daysAgo: 3)
        createTestHistoryItem(category: "keep-2", daysAgo: 6)
        createTestHistoryItem(category: "remove-1", daysAgo: 8)
        createTestHistoryItem(category: "remove-2", daysAgo: 10)
        
        let initialCount = historyManager.getHistoryCount()
        XCTAssertEqual(initialCount, 4)
        
        // When
        historyManager.cleanupOldHistory()
        
        // Then
        let remainingItems = historyManager.getRecentHistory()
        XCTAssertEqual(remainingItems.count, 2)
        
        let categories = remainingItems.map { $0.category }
        XCTAssertTrue(categories.contains("keep-1"))
        XCTAssertTrue(categories.contains("keep-2"))
        XCTAssertFalse(categories.contains("remove-1"))
        XCTAssertFalse(categories.contains("remove-2"))
    }
    
    func testCleanupOldHistory_NoOldItems_DoesNothing() {
        // Given
        createTestHistoryItem(category: "recent-1", daysAgo: 1)
        createTestHistoryItem(category: "recent-2", daysAgo: 3)
        
        let initialCount = historyManager.getHistoryCount()
        
        // When
        historyManager.cleanupOldHistory()
        
        // Then
        let finalCount = historyManager.getHistoryCount()
        XCTAssertEqual(finalCount, initialCount)
    }
    
    func testPerformDailyCleanup_FirstTime_PerformsCleanup() {
        // Given
        UserDefaults.standard.removeObject(forKey: "lastHistoryCleanup")
        createTestHistoryItem(category: "old", daysAgo: 8)
        createTestHistoryItem(category: "new", daysAgo: 1)
        
        // When
        historyManager.performDailyCleanup()
        
        // Then
        let items = historyManager.getRecentHistory()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.category, "new")
        
        // Verify cleanup date was recorded
        let lastCleanup = UserDefaults.standard.object(forKey: "lastHistoryCleanup") as? Date
        XCTAssertNotNil(lastCleanup)
    }
    
    func testPerformDailyCleanup_AlreadyCleanedToday_SkipsCleanup() {
        // Given
        UserDefaults.standard.set(Date(), forKey: "lastHistoryCleanup")
        createTestHistoryItem(category: "old", daysAgo: 8)
        
        let initialCount = historyManager.getHistoryCount()
        
        // When
        historyManager.performDailyCleanup()
        
        // Then - Should not have cleaned up because already done today
        let finalCount = historyManager.getHistoryCount()
        XCTAssertEqual(finalCount, initialCount)
    }
    
    // MARK: - Utility Tests
    
    func testGetHistoryCount_WithItems_ReturnsCorrectCount() {
        // Given
        createTestHistoryItem(category: "item-1")
        createTestHistoryItem(category: "item-2")
        createTestHistoryItem(category: "item-3")
        
        // When
        let count = historyManager.getHistoryCount()
        
        // Then
        XCTAssertEqual(count, 3)
    }
    
    func testGetHistoryCount_EmptyDatabase_ReturnsZero() {
        // When
        let count = historyManager.getHistoryCount()
        
        // Then
        XCTAssertEqual(count, 0)
    }
    
    func testDeleteAllHistory_WithItems_RemovesAllItems() {
        // Given
        createTestHistoryItem(category: "item-1")
        createTestHistoryItem(category: "item-2")
        createTestHistoryItem(category: "item-3")
        
        XCTAssertEqual(historyManager.getHistoryCount(), 3)
        
        // When
        historyManager.deleteAllHistory()
        
        // Then
        XCTAssertEqual(historyManager.getHistoryCount(), 0)
        XCTAssertTrue(historyManager.getRecentHistory().isEmpty)
    }
    
    // MARK: - Edge Cases
    
    func testSaveToHistory_EmptyStrings_HandlesGracefully() {
        // When
        historyManager.saveToHistory(
            sessionId: "",
            riskLevel: "",
            confidence: 0.0,
            category: "",
            explanation: "",
            ocrText: ""
        )
        
        // Then
        let items = historyManager.getRecentHistory()
        XCTAssertEqual(items.count, 1)
        
        let item = items.first!
        XCTAssertEqual(item.sessionId, "")
        XCTAssertEqual(item.riskLevel, "")
        XCTAssertEqual(item.confidence, 0.0)
        XCTAssertEqual(item.category, "")
        XCTAssertEqual(item.explanation, "")
        XCTAssertEqual(item.ocrText, "")
    }
    
    func testSaveToHistory_ExtremeConfidenceValues_HandlesCorrectly() {
        // Given & When
        historyManager.saveToHistory(
            sessionId: "test",
            riskLevel: "high",
            confidence: 1.0,
            category: "test",
            explanation: "test",
            ocrText: "test"
        )
        
        historyManager.saveToHistory(
            sessionId: "test",
            riskLevel: "low",
            confidence: 0.0,
            category: "test",
            explanation: "test",
            ocrText: "test"
        )
        
        // Then
        let items = historyManager.getRecentHistory()
        XCTAssertEqual(items.count, 2)
        
        let confidenceValues = items.map { $0.confidence }.sorted()
        XCTAssertEqual(confidenceValues[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(confidenceValues[1], 1.0, accuracy: 0.001)
    }
}
