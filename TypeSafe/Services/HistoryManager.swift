//
//  HistoryManager.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import CoreData
import Foundation
import Combine

/// Manager for handling scan history storage and cleanup operations
class HistoryManager: ObservableObject {
    /// Shared singleton instance
    static let shared = HistoryManager()
    
    /// Core Data persistence controller
    private let persistenceController: PersistenceController
    
    /// Initialize with persistence controller
    /// - Parameter persistenceController: Core Data controller (defaults to shared instance)
    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
    }
    
    /// Save a scan result to history
    /// - Parameters:
    ///   - sessionId: Current session identifier
    ///   - riskLevel: Risk level (low, medium, high)
    ///   - confidence: Confidence score (0.0-1.0)
    ///   - category: Risk category
    ///   - explanation: Risk explanation
    ///   - ocrText: OCR extracted text
    ///   - thumbnailData: Optional thumbnail image data
    ///   - isAutoScanned: Whether this was automatically scanned (Story 5.2)
    func saveToHistory(
        sessionId: String,
        riskLevel: String,
        confidence: Double,
        category: String,
        explanation: String,
        ocrText: String,
        thumbnailData: Data? = nil,
        isAutoScanned: Bool = false
    ) {
        let context = persistenceController.container.viewContext
        
        let historyItem = ScanHistoryItem(context: context)
        historyItem.id = UUID()
        historyItem.sessionId = sessionId
        historyItem.riskLevel = riskLevel
        historyItem.confidence = confidence
        historyItem.category = category
        historyItem.explanation = explanation
        historyItem.ocrText = ocrText
        historyItem.thumbnailData = thumbnailData
        historyItem.timestamp = Date()
        historyItem.isAutoScanned = isAutoScanned
        
        persistenceController.save()
    }
    
    /// Get recent history items (last 5, newest first)
    /// - Returns: Array of scan history items
    func getRecentHistory() -> [ScanHistoryItem] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        
        // Sort by timestamp (newest first) and limit to 5 items
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScanHistoryItem.timestamp, ascending: false)]
        request.fetchLimit = 5
        
        // Only fetch items from last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "timestamp >= %@", sevenDaysAgo as NSDate)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch history: \(error)")
            return []
        }
    }
    
    /// Clean up history items older than 7 days
    func cleanupOldHistory() {
        let context = persistenceController.container.viewContext
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let fetchRequest: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "timestamp < %@", sevenDaysAgo as NSDate)
        
        do {
            let oldItems = try context.fetch(fetchRequest)
            print("Cleaning up \(oldItems.count) old history items")
            
            oldItems.forEach { context.delete($0) }
            persistenceController.save()
        } catch {
            print("Failed to cleanup old history: \(error)")
        }
    }
    
    /// Perform daily cleanup - should be called on app launch
    func performDailyCleanup() {
        // Check if cleanup was already performed today
        let lastCleanupKey = "lastHistoryCleanup"
        let lastCleanup = UserDefaults.standard.object(forKey: lastCleanupKey) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastCleanup = lastCleanup {
            let lastCleanupDay = Calendar.current.startOfDay(for: lastCleanup)
            if lastCleanupDay >= today {
                return // Already cleaned up today
            }
        }
        
        cleanupOldHistory()
        UserDefaults.standard.set(Date(), forKey: lastCleanupKey)
    }
    
    /// Get history count for testing/debugging
    /// - Returns: Total number of history items
    func getHistoryCount() -> Int {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        
        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count history items: \(error)")
            return 0
        }
    }
    
    /// Delete all history items (for testing/reset)
    func deleteAllHistory() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<ScanHistoryItem> = ScanHistoryItem.fetchRequest()
        
        do {
            let items = try context.fetch(request)
            items.forEach { context.delete($0) }
            persistenceController.save()
        } catch {
            print("Failed to delete all history: \(error)")
        }
    }
}
