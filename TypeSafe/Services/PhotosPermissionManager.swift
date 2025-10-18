//
//  PhotosPermissionManager.swift
//  TypeSafe
//
//  Story 5.1: Photos Framework Integration & Permission Management
//  Manages Photos library access permissions for automatic screenshot scanning
//

import Photos
import SwiftUI
import Combine

/// Manages Photos library permissions for automatic screenshot scanning
/// Handles authorization requests, status checking, and permission state management
@MainActor
class PhotosPermissionManager: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    static let shared = PhotosPermissionManager()
    
    // MARK: - Published Properties
    
    /// Current Photos library authorization status
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    // MARK: - Initialization
    
    /// Initialize and check current authorization status
    private init() {
        // Check initial status on creation
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("PhotosPermissionManager: Initialized with status: \(statusDescription(authorizationStatus))")
    }
    
    // MARK: - Permission Request Methods
    
    /// Request Photos library access with clear messaging
    /// - Returns: Granted authorization status
    /// - Note: This should only be called when user explicitly triggers automatic scanning
    func requestAuthorization() async -> PHAuthorizationStatus {
        print("PhotosPermissionManager: Requesting authorization...")
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        // Update published property on main actor
        self.authorizationStatus = status
        
        print("PhotosPermissionManager: Authorization result: \(statusDescription(status))")
        return status
    }
    
    /// Check current authorization status (synchronous)
    /// - Returns: Current PHAuthorizationStatus
    func checkAuthorizationStatus() -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.authorizationStatus = status
        print("PhotosPermissionManager: Current status: \(statusDescription(status))")
        return status
    }
    
    // MARK: - Permission State Helpers
    
    /// Returns true if automatic screenshot fetching is possible
    /// Both .authorized and .limited allow photo access (limited may not have all photos)
    var canAutomaticallyFetchScreenshots: Bool {
        let canFetch = authorizationStatus == .authorized || authorizationStatus == .limited
        print("PhotosPermissionManager: Can automatically fetch: \(canFetch)")
        return canFetch
    }
    
    /// Returns true if permission has been determined (not first time)
    var isPermissionDetermined: Bool {
        return authorizationStatus != .notDetermined
    }
    
    /// Returns true if user has explicitly denied permission
    var isPermissionDenied: Bool {
        return authorizationStatus == .denied
    }
    
    /// Returns true if permission is restricted (e.g., parental controls)
    var isPermissionRestricted: Bool {
        return authorizationStatus == .restricted
    }
    
    /// Returns true if user has granted full photo library access
    var hasFullAccess: Bool {
        return authorizationStatus == .authorized
    }
    
    /// Returns true if user has granted limited photo library access
    var hasLimitedAccess: Bool {
        return authorizationStatus == .limited
    }
    
    // MARK: - User-Facing Messages
    
    /// Get user-friendly status description
    /// - Parameter status: PHAuthorizationStatus to describe
    /// - Returns: Human-readable description
    func userFacingStatusDescription(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not yet requested"
        case .authorized:
            return "Full access granted"
        case .limited:
            return "Limited access (selected photos only)"
        case .denied:
            return "Access denied"
        case .restricted:
            return "Access restricted (parental controls or device policy)"
        @unknown default:
            return "Unknown status"
        }
    }
    
    /// Get user-friendly explanation for current permission state
    var permissionExplanation: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Photos access has not been requested yet. Tap 'Scan Now' to enable automatic screenshot scanning."
        case .authorized:
            return "TypeSafe can automatically fetch your most recent screenshot when you tap 'Scan Now'."
        case .limited:
            return "You've granted limited photo access. Automatic scanning may not work if screenshots aren't in your selection. Consider granting full access."
        case .denied:
            return "Photos access is required for automatic scanning. You can still use the manual photo picker. To enable automatic scanning, please allow Photos access in Settings."
        case .restricted:
            return "Photos access is restricted by parental controls or device policy. Automatic scanning is not available. You can still use the manual photo picker."
        @unknown default:
            return "Unknown permission status. Please try again or contact support."
        }
    }
    
    // MARK: - Settings Deep Link
    
    /// Opens iOS Settings to app's permission page
    /// Allows user to grant or revoke permissions
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("PhotosPermissionManager: Failed to create Settings URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL) { success in
                print("PhotosPermissionManager: Opened Settings: \(success)")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Get debug-friendly status description
    private func statusDescription(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .authorized: return "authorized"
        case .limited: return "limited"
        case .denied: return "denied"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Permission State Enum for SwiftUI

/// Simplified permission state for UI decisions
enum PhotoPermissionState {
    case notDetermined
    case granted
    case limitedAccess
    case denied
    case restricted
    
    init(from status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .authorized:
            self = .granted
        case .limited:
            self = .limitedAccess
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .denied
        }
    }
    
    /// Can proceed with automatic scanning
    var canAutomaticallyScan: Bool {
        return self == .granted || self == .limitedAccess
    }
    
    /// Should show settings button
    var shouldShowSettingsButton: Bool {
        return self == .denied || self == .restricted
    }
}

