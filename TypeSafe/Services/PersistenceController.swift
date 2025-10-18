//
//  PersistenceController.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import CoreData
import Foundation
import Combine

/// Core Data persistence controller for managing scan history storage
class PersistenceController: ObservableObject {
    /// Shared singleton instance
    static let shared = PersistenceController()
    
    /// Core Data container
    let container: NSPersistentContainer
    
    /// Preview instance for SwiftUI previews with in-memory store
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Create sample data for previews
        let sampleItem = ScanHistoryItem(context: context)
        sampleItem.id = UUID()
        sampleItem.sessionId = "preview-session"
        sampleItem.riskLevel = "medium"
        sampleItem.confidence = 0.85
        sampleItem.category = "Phishing"
        sampleItem.explanation = "Suspicious link detected in message"
        sampleItem.ocrText = "Click here to claim your prize!"
        sampleItem.timestamp = Date()
        
        try? context.save()
        return controller
    }()
    
    /// Initialize persistence controller
    /// - Parameter inMemory: Whether to use in-memory store (for testing/previews)
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TypeSafe")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, you should handle this error appropriately
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    /// Save the Core Data context
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save Core Data context: \(error)")
            }
        }
    }
}
