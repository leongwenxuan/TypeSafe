//
//  SessionManager.swift
//  TypeSafeKeyboard
//
//  Story 2.3: Backend API Integration
//  Manages anonymous session IDs for backend correlation
//

import Foundation

/// Manages session ID generation and persistence for backend API calls
/// Session IDs are anonymous UUIDs stored in App Group UserDefaults
class SessionManager {
    
    // MARK: - Properties
    
    /// App Group identifier for sharing data between keyboard and main app
    private let appGroupIdentifier = "group.com.typesafe.shared"
    
    /// UserDefaults key for storing session ID
    private let sessionIDKey = "typesafe.session_id"
    
    /// Cached session ID to avoid repeated UserDefaults reads
    private var cachedSessionID: String?
    
    /// Shared UserDefaults instance for App Group
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // MARK: - Public Methods
    
    /// Retrieves existing session ID or generates a new one
    /// - Returns: Session ID as UUID string (e.g., "550e8400-e29b-41d4-a716-446655440000")
    func getOrCreateSessionID() -> String {
        // Return cached value if available
        if let cached = cachedSessionID {
            return cached
        }
        
        // Try to retrieve from UserDefaults
        if let stored = sharedDefaults?.string(forKey: sessionIDKey) {
            cachedSessionID = stored
            return stored
        }
        
        // Generate new UUID if none exists
        let newSessionID = UUID().uuidString
        
        // Persist to UserDefaults (fail gracefully if unavailable)
        sharedDefaults?.set(newSessionID, forKey: sessionIDKey)
        
        // Cache the value
        cachedSessionID = newSessionID
        
        print("SessionManager: Generated new session ID: \(newSessionID)")
        return newSessionID
    }
    
    /// Clears the current session ID (useful for testing or logout)
    func clearSession() {
        sharedDefaults?.removeObject(forKey: sessionIDKey)
        cachedSessionID = nil
        print("SessionManager: Session cleared")
    }
}

