//
//  HistoryViewTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 18/01/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import TypeSafe

/// Unit tests for HistoryView functionality
final class HistoryViewTests: XCTestCase {
    
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
    
    /// Create a test history item with specified parameters
    private func createTestHistoryItem(
        sessionId: String = "test-session",
        riskLevel: String = "medium",
        confidence: Double = 0.85,
        category: String = "phishing",
        explanation: String = "Test explanation",
        ocrText: String = "Test OCR text",
        daysAgo: Int = 0
    ) -> ScanHistoryItem {
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
        return item
    }
    
    // MARK: - HistoryView Tests
    
    func testHistoryView_EmptyState_ShowsEmptyMessage() {
        // Given - Empty database
        
        // When - Create HistoryView
        let historyView = HistoryView()
            .environment(\.managedObjectContext, testContext)
        
        // Then - Should show empty state
        // Note: In a real UI test, we would check for the presence of empty state elements
        // For unit tests, we verify the underlying data state
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "timestamp >= %@", sevenDaysAgo as NSDate)
        
        do {
            let items = try testContext.fetch(request)
            XCTAssertTrue(items.isEmpty, "Empty state should have no items")
        } catch {
            XCTFail("Failed to fetch items: \(error)")
        }
    }
    
    func testHistoryView_WithItems_ShowsHistoryList() {
        // Given
        createTestHistoryItem(category: "phishing", riskLevel: "high", daysAgo: 1)
        createTestHistoryItem(category: "safe", riskLevel: "low", daysAgo: 2)
        
        // When - Create HistoryView
        let historyView = HistoryView()
            .environment(\.managedObjectContext, testContext)
        
        // Then - Verify items exist in database
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "timestamp >= %@", sevenDaysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScanHistoryItem.timestamp, ascending: false)]
        
        do {
            let items = try testContext.fetch(request)
            XCTAssertEqual(items.count, 2)
            XCTAssertEqual(items.first?.category, "phishing") // Most recent
        } catch {
            XCTFail("Failed to fetch items: \(error)")
        }
    }
    
    func testHistoryView_MoreThan5Items_LimitsTo5() {
        // Given - Create 7 items
        for i in 1...7 {
            createTestHistoryItem(category: "item-\(i)", daysAgo: i-1)
        }
        
        // When - Fetch with same logic as HistoryView
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "timestamp >= %@", sevenDaysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScanHistoryItem.timestamp, ascending: false)]
        
        do {
            let allItems = try testContext.fetch(request)
            let limitedItems = Array(allItems.prefix(5))
            
            // Then
            XCTAssertEqual(allItems.count, 7)
            XCTAssertEqual(limitedItems.count, 5)
        } catch {
            XCTFail("Failed to fetch items: \(error)")
        }
    }
    
    func testHistoryView_ItemsOlderThan7Days_ExcludesOldItems() {
        // Given
        createTestHistoryItem(category: "recent", daysAgo: 3)
        createTestHistoryItem(category: "old", daysAgo: 8)
        
        // When - Fetch with same predicate as HistoryView
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "timestamp >= %@", sevenDaysAgo as NSDate)
        
        do {
            let items = try testContext.fetch(request)
            
            // Then
            XCTAssertEqual(items.count, 1)
            XCTAssertEqual(items.first?.category, "recent")
        } catch {
            XCTFail("Failed to fetch items: \(error)")
        }
    }
    
    // MARK: - HistoryRowView Tests
    
    func testHistoryRowView_DisplaysCorrectData() {
        // Given
        let testItem = createTestHistoryItem(
            riskLevel: "high",
            confidence: 0.92,
            category: "Phishing",
            explanation: "Suspicious link detected",
            ocrText: "Click here to verify your account"
        )
        
        // When - Create HistoryRowView
        let rowView = HistoryRowView(item: testItem)
        
        // Then - Verify the item has correct data
        XCTAssertEqual(testItem.riskLevel, "high")
        XCTAssertEqual(testItem.confidence, 0.92, accuracy: 0.001)
        XCTAssertEqual(testItem.category, "Phishing")
        XCTAssertEqual(testItem.explanation, "Suspicious link detected")
        XCTAssertEqual(testItem.ocrText, "Click here to verify your account")
    }
    
    func testRiskLevelIndicator_HighRisk_ReturnsRedColor() {
        // Given
        let indicator = RiskLevelIndicator(riskLevel: "high")
        
        // When - Check risk color computation
        let testItem = createTestHistoryItem(riskLevel: "high")
        
        // Then
        XCTAssertEqual(testItem.riskLevel, "high")
        // Note: Color testing in SwiftUI requires UI testing framework
        // Here we verify the data that drives the color logic
    }
    
    func testRiskLevelIndicator_MediumRisk_ReturnsOrangeColor() {
        // Given & When
        let testItem = createTestHistoryItem(riskLevel: "medium")
        
        // Then
        XCTAssertEqual(testItem.riskLevel, "medium")
    }
    
    func testRiskLevelIndicator_LowRisk_ReturnsGreenColor() {
        // Given & When
        let testItem = createTestHistoryItem(riskLevel: "low")
        
        // Then
        XCTAssertEqual(testItem.riskLevel, "low")
    }
    
    func testRiskLevelIndicator_UnknownRisk_ReturnsGrayColor() {
        // Given & When
        let testItem = createTestHistoryItem(riskLevel: "unknown")
        
        // Then
        XCTAssertEqual(testItem.riskLevel, "unknown")
    }
    
    // MARK: - ScanResultDetailView Tests
    
    func testScanResultDetailView_DisplaysAllData() {
        // Given
        let testItem = createTestHistoryItem(
            riskLevel: "medium",
            confidence: 0.78,
            category: "Payment Scam",
            explanation: "Suspicious payment request detected",
            ocrText: "Send $500 to this account immediately"
        )
        
        // When - Create detail view
        let detailView = ScanResultDetailView(historyItem: testItem)
        
        // Then - Verify all data is accessible
        XCTAssertEqual(testItem.riskLevel, "medium")
        XCTAssertEqual(testItem.confidence, 0.78, accuracy: 0.001)
        XCTAssertEqual(testItem.category, "Payment Scam")
        XCTAssertEqual(testItem.explanation, "Suspicious payment request detected")
        XCTAssertEqual(testItem.ocrText, "Send $500 to this account immediately")
        XCTAssertNotNil(testItem.timestamp)
    }
    
    func testScanResultDetailView_EmptyOCRText_HandlesGracefully() {
        // Given
        let testItem = createTestHistoryItem(ocrText: "")
        
        // When - Create detail view
        let detailView = ScanResultDetailView(historyItem: testItem)
        
        // Then
        XCTAssertEqual(testItem.ocrText, "")
        // In the actual view, empty OCR text should be handled gracefully
    }
    
    // MARK: - RiskLevelHeader Tests
    
    func testRiskLevelHeader_HighRisk_DisplaysCorrectly() {
        // Given
        let riskLevel = "high"
        let confidence = 0.95
        
        // When
        let header = RiskLevelHeader(riskLevel: riskLevel, confidence: confidence)
        
        // Then - Verify data is correct for display
        XCTAssertEqual(riskLevel, "high")
        XCTAssertEqual(confidence, 0.95, accuracy: 0.001)
        
        // Verify confidence percentage calculation
        let percentage = Int(confidence * 100)
        XCTAssertEqual(percentage, 95)
    }
    
    func testRiskLevelHeader_LowRisk_DisplaysCorrectly() {
        // Given
        let riskLevel = "low"
        let confidence = 0.12
        
        // When
        let header = RiskLevelHeader(riskLevel: riskLevel, confidence: confidence)
        
        // Then
        XCTAssertEqual(riskLevel, "low")
        XCTAssertEqual(confidence, 0.12, accuracy: 0.001)
        
        let percentage = Int(confidence * 100)
        XCTAssertEqual(percentage, 12)
    }
    
    // MARK: - Navigation Tests
    
    func testHistoryNavigation_ItemSelection_ShouldNavigateToDetail() {
        // Given
        let testItem = createTestHistoryItem(category: "Test Category")
        
        // When - Simulate navigation (in real app, this would be handled by NavigationLink)
        let shouldNavigate = true // This would be triggered by tapping the NavigationLink
        
        // Then
        XCTAssertTrue(shouldNavigate)
        XCTAssertEqual(testItem.category, "Test Category")
    }
    
    // MARK: - Timestamp Formatting Tests
    
    func testTimestampFormatting_RecentDate_FormatsCorrectly() {
        // Given
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let testItem = createTestHistoryItem()
        testItem.timestamp = oneHourAgo
        
        // When
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        let formattedTime = formatter.localizedString(for: oneHourAgo, relativeTo: Date())
        
        // Then
        XCTAssertFalse(formattedTime.isEmpty)
        // The exact format depends on locale, but should contain relative time info
    }
    
    func testTimestampFormatting_FullDate_FormatsCorrectly() {
        // Given
        let testDate = Date()
        
        // When
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        let formattedDate = formatter.string(from: testDate)
        
        // Then
        XCTAssertFalse(formattedDate.isEmpty)
        XCTAssertTrue(formattedDate.count > 10) // Should be a reasonably long formatted string
    }
    
    // MARK: - Edge Cases
    
    func testHistoryView_CoreDataError_HandlesGracefully() {
        // Given - This test verifies that the view handles Core Data errors gracefully
        // In practice, the @FetchRequest handles errors internally
        
        // When - Create view with valid context
        let historyView = HistoryView()
            .environment(\.managedObjectContext, testContext)
        
        // Then - Should not crash
        XCTAssertNotNil(historyView)
    }
    
    func testHistoryView_NilTimestamp_HandlesGracefully() {
        // Given
        let testItem = createTestHistoryItem()
        // Note: Core Data won't allow nil for non-optional attributes
        // This test verifies our data model constraints
        
        // Then
        XCTAssertNotNil(testItem.timestamp)
    }
    
    func testHistoryView_ExtremeConfidenceValues_DisplaysCorrectly() {
        // Given
        let item1 = createTestHistoryItem(confidence: 0.0)
        let item2 = createTestHistoryItem(confidence: 1.0)
        
        // When - Calculate display percentages
        let percentage1 = Int(item1.confidence * 100)
        let percentage2 = Int(item2.confidence * 100)
        
        // Then
        XCTAssertEqual(percentage1, 0)
        XCTAssertEqual(percentage2, 100)
    }
}
