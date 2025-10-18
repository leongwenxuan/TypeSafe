//
//  PhotosPermissionManagerTests.swift
//  TypeSafeTests
//
//  Story 5.1: Photos Framework Integration & Permission Management
//  Unit tests for PhotosPermissionManager
//

import XCTest
import Photos
@testable import TypeSafe

/// Unit tests for PhotosPermissionManager
/// Tests authorization flow, permission states, and user-facing messages
@MainActor
final class PhotosPermissionManagerTests: XCTestCase {
    
    var sut: PhotosPermissionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = PhotosPermissionManager.shared
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() throws {
        // Given/When - manager is initialized
        // Then - it should have valid initial state
        XCTAssertNotNil(sut, "PhotosPermissionManager should initialize")
        
        // Authorization status should be one of the valid states
        let validStatuses: [PHAuthorizationStatus] = [
            .notDetermined, .authorized, .limited, .denied, .restricted
        ]
        XCTAssertTrue(validStatuses.contains(sut.authorizationStatus), 
                      "Initial authorization status should be valid")
    }
    
    // MARK: - Permission State Helper Tests
    
    func testCanAutomaticallyFetchScreenshots_Authorized() {
        // Given - authorized status
        sut.authorizationStatus = .authorized
        
        // When/Then
        XCTAssertTrue(sut.canAutomaticallyFetchScreenshots, 
                      "Should allow automatic fetching when authorized")
        XCTAssertTrue(sut.hasFullAccess, 
                      "Should have full access when authorized")
    }
    
    func testCanAutomaticallyFetchScreenshots_Limited() {
        // Given - limited status
        sut.authorizationStatus = .limited
        
        // When/Then
        XCTAssertTrue(sut.canAutomaticallyFetchScreenshots, 
                      "Should allow automatic fetching with limited access")
        XCTAssertTrue(sut.hasLimitedAccess, 
                      "Should have limited access")
        XCTAssertFalse(sut.hasFullAccess, 
                       "Should not have full access when limited")
    }
    
    func testCanAutomaticallyFetchScreenshots_Denied() {
        // Given - denied status
        sut.authorizationStatus = .denied
        
        // When/Then
        XCTAssertFalse(sut.canAutomaticallyFetchScreenshots, 
                       "Should not allow automatic fetching when denied")
        XCTAssertTrue(sut.isPermissionDenied, 
                      "Should detect denied permission")
    }
    
    func testCanAutomaticallyFetchScreenshots_Restricted() {
        // Given - restricted status
        sut.authorizationStatus = .restricted
        
        // When/Then
        XCTAssertFalse(sut.canAutomaticallyFetchScreenshots, 
                       "Should not allow automatic fetching when restricted")
        XCTAssertTrue(sut.isPermissionRestricted, 
                      "Should detect restricted permission")
    }
    
    func testCanAutomaticallyFetchScreenshots_NotDetermined() {
        // Given - not determined status
        sut.authorizationStatus = .notDetermined
        
        // When/Then
        XCTAssertFalse(sut.canAutomaticallyFetchScreenshots, 
                       "Should not allow automatic fetching before permission requested")
        XCTAssertFalse(sut.isPermissionDetermined, 
                       "Should not be determined yet")
    }
    
    // MARK: - User-Facing Message Tests
    
    func testUserFacingStatusDescription_AllStates() {
        // Test all permission states have meaningful descriptions
        let testCases: [(PHAuthorizationStatus, String)] = [
            (.notDetermined, "Not yet requested"),
            (.authorized, "Full access granted"),
            (.limited, "Limited access"),
            (.denied, "Access denied"),
            (.restricted, "Access restricted")
        ]
        
        for (status, expectedSubstring) in testCases {
            sut.authorizationStatus = status
            let description = sut.userFacingStatusDescription(status)
            
            XCTAssertTrue(description.contains(expectedSubstring), 
                          "Status description for \(status) should contain '\(expectedSubstring)'")
        }
    }
    
    func testPermissionExplanation_AllStates() {
        // Test all states have explanations
        let allStates: [PHAuthorizationStatus] = [
            .notDetermined, .authorized, .limited, .denied, .restricted
        ]
        
        for status in allStates {
            sut.authorizationStatus = status
            let explanation = sut.permissionExplanation
            
            XCTAssertFalse(explanation.isEmpty, 
                           "Should have explanation for status: \(status)")
            XCTAssertGreaterThan(explanation.count, 20, 
                                 "Explanation should be detailed for status: \(status)")
        }
    }
    
    func testPermissionExplanation_Authorized_MentionsAutomatic() {
        // Given - authorized status
        sut.authorizationStatus = .authorized
        
        // When
        let explanation = sut.permissionExplanation
        
        // Then - should mention automatic fetching
        XCTAssertTrue(explanation.lowercased().contains("automatic"), 
                      "Authorized explanation should mention automatic fetching")
    }
    
    func testPermissionExplanation_Denied_MentionsSettings() {
        // Given - denied status
        sut.authorizationStatus = .denied
        
        // When
        let explanation = sut.permissionExplanation
        
        // Then - should mention Settings
        XCTAssertTrue(explanation.contains("Settings"), 
                      "Denied explanation should mention Settings")
    }
    
    func testPermissionExplanation_Limited_MentionsGranularAccess() {
        // Given - limited status
        sut.authorizationStatus = .limited
        
        // When
        let explanation = sut.permissionExplanation
        
        // Then - should mention limitations
        XCTAssertTrue(explanation.lowercased().contains("limited") || 
                      explanation.lowercased().contains("selection"), 
                      "Limited explanation should mention access limitations")
    }
    
    // MARK: - Permission State Enum Tests
    
    func testPhotoPermissionState_Initialization() {
        // Test PhotoPermissionState enum initialization from PHAuthorizationStatus
        let testCases: [(PHAuthorizationStatus, PhotoPermissionState)] = [
            (.notDetermined, .notDetermined),
            (.authorized, .granted),
            (.limited, .limitedAccess),
            (.denied, .denied),
            (.restricted, .restricted)
        ]
        
        for (phStatus, expectedState) in testCases {
            let state = PhotoPermissionState(from: phStatus)
            XCTAssertEqual(state, expectedState, 
                           "PhotoPermissionState should map \(phStatus) correctly")
        }
    }
    
    func testPhotoPermissionState_CanAutomaticallyScan() {
        // Granted and limited access should allow scanning
        XCTAssertTrue(PhotoPermissionState.granted.canAutomaticallyScan, 
                      "Granted should allow automatic scan")
        XCTAssertTrue(PhotoPermissionState.limitedAccess.canAutomaticallyScan, 
                      "Limited access should allow automatic scan")
        
        // Other states should not
        XCTAssertFalse(PhotoPermissionState.notDetermined.canAutomaticallyScan, 
                       "Not determined should not allow automatic scan")
        XCTAssertFalse(PhotoPermissionState.denied.canAutomaticallyScan, 
                       "Denied should not allow automatic scan")
        XCTAssertFalse(PhotoPermissionState.restricted.canAutomaticallyScan, 
                       "Restricted should not allow automatic scan")
    }
    
    func testPhotoPermissionState_ShouldShowSettingsButton() {
        // Only denied and restricted should show settings button
        XCTAssertTrue(PhotoPermissionState.denied.shouldShowSettingsButton, 
                      "Denied should show settings button")
        XCTAssertTrue(PhotoPermissionState.restricted.shouldShowSettingsButton, 
                      "Restricted should show settings button")
        
        // Other states should not
        XCTAssertFalse(PhotoPermissionState.notDetermined.shouldShowSettingsButton, 
                       "Not determined should not show settings button")
        XCTAssertFalse(PhotoPermissionState.granted.shouldShowSettingsButton, 
                       "Granted should not show settings button")
        XCTAssertFalse(PhotoPermissionState.limitedAccess.shouldShowSettingsButton, 
                       "Limited access should not show settings button")
    }
    
    // MARK: - Settings Deep Link Tests
    
    func testOpenAppSettings_DoesNotCrash() {
        // Test that opening settings doesn't crash
        // Note: Cannot actually verify Settings opens in unit tests
        XCTAssertNoThrow(sut.openAppSettings(), 
                         "Opening app settings should not throw")
    }
    
    // MARK: - Integration Tests
    
    func testCheckAuthorizationStatus_ReturnsValidStatus() {
        // When
        let status = sut.checkAuthorizationStatus()
        
        // Then - should return a valid status
        let validStatuses: [PHAuthorizationStatus] = [
            .notDetermined, .authorized, .limited, .denied, .restricted
        ]
        XCTAssertTrue(validStatuses.contains(status), 
                      "Should return valid authorization status")
        
        // Should update published property
        XCTAssertEqual(sut.authorizationStatus, status, 
                       "Should update authorizationStatus property")
    }
    
    func testSingletonInstance_IsSame() {
        // Given - get shared instance twice
        let instance1 = PhotosPermissionManager.shared
        let instance2 = PhotosPermissionManager.shared
        
        // When/Then - should be same instance
        XCTAssertTrue(instance1 === instance2, 
                      "Shared instances should be identical")
    }
    
    // MARK: - Edge Case Tests
    
    func testIsPermissionDetermined_EdgeCases() {
        // Test all determined states
        sut.authorizationStatus = .authorized
        XCTAssertTrue(sut.isPermissionDetermined, 
                      "Authorized should be determined")
        
        sut.authorizationStatus = .limited
        XCTAssertTrue(sut.isPermissionDetermined, 
                      "Limited should be determined")
        
        sut.authorizationStatus = .denied
        XCTAssertTrue(sut.isPermissionDetermined, 
                      "Denied should be determined")
        
        sut.authorizationStatus = .restricted
        XCTAssertTrue(sut.isPermissionDetermined, 
                      "Restricted should be determined")
        
        // Test not determined
        sut.authorizationStatus = .notDetermined
        XCTAssertFalse(sut.isPermissionDetermined, 
                       "Not determined should return false")
    }
}

