//
//  SessionManagerTests.swift
//  TypeSafeTests
//
//  Story 2.3: Backend API Integration
//  Unit tests for SessionManager
//

import XCTest
@testable import TypeSafe

class SessionManagerTests: XCTestCase {
    
    var sessionManager: SessionManager!
    let testAppGroupID = "group.com.typesafe.shared"
    let testSessionKey = "typesafe.session_id"
    
    override func setUp() {
        super.setUp()
        sessionManager = SessionManager()
        
        // Clear any existing session before each test
        if let defaults = UserDefaults(suiteName: testAppGroupID) {
            defaults.removeObject(forKey: testSessionKey)
        }
    }
    
    override func tearDown() {
        // Clean up after each test
        if let defaults = UserDefaults(suiteName: testAppGroupID) {
            defaults.removeObject(forKey: testSessionKey)
        }
        sessionManager = nil
        super.tearDown()
    }
    
    // MARK: - Test: UUID Generation
    
    func testGeneratesNewUUIDOnFirstCall() {
        // When: Getting session ID for the first time
        let sessionID = sessionManager.getOrCreateSessionID()
        
        // Then: Should return a valid UUID string
        XCTAssertFalse(sessionID.isEmpty, "Session ID should not be empty")
        XCTAssertNotNil(UUID(uuidString: sessionID), "Session ID should be a valid UUID")
    }
    
    func testUUIDFormatIsRFC4122Compliant() {
        // When: Getting session ID
        let sessionID = sessionManager.getOrCreateSessionID()
        
        // Then: Should be a valid RFC 4122 UUID (8-4-4-4-12 format)
        let uuidPattern = "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
        let regex = try? NSRegularExpression(pattern: uuidPattern)
        let range = NSRange(location: 0, length: sessionID.utf16.count)
        let match = regex?.firstMatch(in: sessionID, range: range)
        
        XCTAssertNotNil(match, "Session ID should match RFC 4122 UUID format")
    }
    
    // MARK: - Test: Persistence
    
    func testSessionIDPersistsAcrossMultipleCalls() {
        // When: Getting session ID twice
        let firstSessionID = sessionManager.getOrCreateSessionID()
        let secondSessionID = sessionManager.getOrCreateSessionID()
        
        // Then: Should return the same ID
        XCTAssertEqual(firstSessionID, secondSessionID, "Session ID should persist across calls")
    }
    
    func testSessionIDPersistsAcrossManagerInstances() {
        // Given: First manager creates a session
        let firstSessionID = sessionManager.getOrCreateSessionID()
        
        // When: Creating a new SessionManager instance
        let newManager = SessionManager()
        let newSessionID = newManager.getOrCreateSessionID()
        
        // Then: Should return the same persisted ID
        XCTAssertEqual(firstSessionID, newSessionID, "Session ID should persist across manager instances")
    }
    
    func testSessionIDIsStoredInAppGroupUserDefaults() {
        // When: Getting session ID
        let sessionID = sessionManager.getOrCreateSessionID()
        
        // Then: Should be stored in App Group UserDefaults
        let defaults = UserDefaults(suiteName: testAppGroupID)
        let storedID = defaults?.string(forKey: testSessionKey)
        
        XCTAssertNotNil(storedID, "Session ID should be stored in UserDefaults")
        XCTAssertEqual(storedID, sessionID, "Stored ID should match returned ID")
    }
    
    // MARK: - Test: Clear Session
    
    func testClearSessionRemovesStoredID() {
        // Given: A session exists
        let sessionID = sessionManager.getOrCreateSessionID()
        XCTAssertFalse(sessionID.isEmpty)
        
        // When: Clearing the session
        sessionManager.clearSession()
        
        // Then: Stored ID should be removed from UserDefaults
        let defaults = UserDefaults(suiteName: testAppGroupID)
        let storedID = defaults?.string(forKey: testSessionKey)
        
        XCTAssertNil(storedID, "Session ID should be removed after clearing")
    }
    
    func testClearSessionAllowsNewIDGeneration() {
        // Given: A session exists
        let firstSessionID = sessionManager.getOrCreateSessionID()
        
        // When: Clearing and getting a new session
        sessionManager.clearSession()
        let newSessionID = sessionManager.getOrCreateSessionID()
        
        // Then: Should generate a different ID
        XCTAssertNotEqual(firstSessionID, newSessionID, "Should generate new ID after clearing")
    }
    
    // MARK: - Test: Edge Cases
    
    func testHandlesUnavailableUserDefaultsGracefully() {
        // Note: This is difficult to test directly since UserDefaults(suiteName:) 
        // will return nil if the App Group is not configured, but the implementation
        // should handle this gracefully by still returning a UUID (though not persisted)
        
        // When: Getting session ID (even if persistence fails)
        let sessionID = sessionManager.getOrCreateSessionID()
        
        // Then: Should still return a valid UUID
        XCTAssertNotNil(UUID(uuidString: sessionID), "Should return valid UUID even if persistence fails")
    }
    
    func testMultipleManagersShareSameSession() {
        // Given: First manager creates a session
        let manager1 = SessionManager()
        let sessionID1 = manager1.getOrCreateSessionID()
        
        // When: Second manager gets session
        let manager2 = SessionManager()
        let sessionID2 = manager2.getOrCreateSessionID()
        
        // Then: Both should return the same ID
        XCTAssertEqual(sessionID1, sessionID2, "Multiple managers should share the same session")
    }
    
    func testSessionIDIsConsistentWithinSession() {
        // When: Calling getOrCreateSessionID multiple times rapidly
        let ids = (0..<10).map { _ in sessionManager.getOrCreateSessionID() }
        
        // Then: All IDs should be identical
        let uniqueIDs = Set(ids)
        XCTAssertEqual(uniqueIDs.count, 1, "Should return consistent ID within session")
    }
}

