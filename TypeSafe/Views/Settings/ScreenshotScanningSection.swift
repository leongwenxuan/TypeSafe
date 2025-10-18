//
//  ScreenshotScanningSection.swift
//  TypeSafe
//
//  Story 5.1: Photos Framework Integration & Permission Management
//  Settings section for automatic screenshot scanning and Photos permission management
//

import SwiftUI
import Photos

/// Settings section for automatic screenshot scanning
/// Includes automatic scan toggle and Photos permission management
struct ScreenshotScanningSection: View {
    
    // MARK: - Properties
    
    /// Settings manager for scan preferences
    @ObservedObject var settingsManager: SettingsManager
    
    /// Photos permission manager
    @StateObject private var photosPermission = PhotosPermissionManager.shared
    
    /// State for permission request in progress
    @State private var isRequestingPermission = false
    
    /// State for showing permission info alert
    @State private var showingPermissionInfo = false
    
    // MARK: - Body
    
    var body: some View {
        Section {
            // Automatic Screenshot Scanning Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.automaticScreenshotScanEnabled },
                    set: { settingsManager.updateAutomaticScanSetting($0) }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic Screenshot Scanning")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(settingsManager.settings.automaticScreenshotScanEnabled ? "Auto-fetch enabled" : "Manual selection only")
                                .font(.caption)
                                .foregroundColor(settingsManager.settings.automaticScreenshotScanEnabled ? .green : .secondary)
                        }
                    }
                }
                .accessibilityLabel("Automatic Screenshot Scanning")
                .accessibilityHint("Toggle whether to automatically fetch screenshots when tapping Scan Now")
                
                // Contextual explanation and permission status
                scanningExplanationView
            }
            .padding(.vertical, 8)
            
        } header: {
            Text("Screenshot Scanning")
                .font(.headline)
        } footer: {
            Text("When enabled, tapping 'Scan Now' automatically fetches your most recent screenshot. Requires Photos access.")
                .font(.caption)
        }
        .alert("Photos Permission", isPresented: $showingPermissionInfo) {
            Button("OK") { }
        } message: {
            Text(photosPermission.permissionExplanation)
        }
    }
    
    // MARK: - Subviews
    
    /// Contextual explanation based on current setting and permission status
    private var scanningExplanationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if settingsManager.settings.automaticScreenshotScanEnabled {
                // Automatic scanning enabled - show permission status
                permissionStatusView
            } else {
                // Automatic scanning disabled - show info
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manual Selection Mode")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("You'll use the photo picker to select screenshots manually. No Photos permission required.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(8)
    }
    
    /// Permission status view with actions
    private var permissionStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                    
                    Text(statusDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Action buttons based on permission state
            permissionActionButtons
        }
    }
    
    /// Action buttons for permission management
    @ViewBuilder
    private var permissionActionButtons: some View {
        if photosPermission.authorizationStatus == .notDetermined {
            // Not yet requested - show request button
            Button(action: { requestPermission() }) {
                HStack {
                    Image(systemName: "photo.circle")
                    Text("Grant Photos Access")
                }
                .frame(maxWidth: .infinity)
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequestingPermission)
            
        } else if photosPermission.authorizationStatus == .denied || photosPermission.authorizationStatus == .restricted {
            // Denied or restricted - show Settings button
            Button(action: { photosPermission.openAppSettings() }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .frame(maxWidth: .infinity)
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            
        } else if photosPermission.authorizationStatus == .limited {
            // Limited access - show upgrade option
            VStack(spacing: 8) {
                Button(action: { requestPermission() }) {
                    HStack {
                        Image(systemName: "photo.stack")
                        Text("Grant Full Access")
                    }
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequestingPermission)
                
                Button(action: { showingPermissionInfo = true }) {
                    Text("Why full access?")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        } else {
            // Authorized - show success message
            Button(action: { showingPermissionInfo = true }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("About Photos Access")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Background color based on permission status
    private var backgroundColor: Color {
        if !settingsManager.settings.automaticScreenshotScanEnabled {
            return Color.secondary.opacity(0.1)
        }
        
        switch photosPermission.authorizationStatus {
        case .authorized:
            return Color.green.opacity(0.1)
        case .limited:
            return Color.yellow.opacity(0.1)
        case .denied, .restricted:
            return Color.red.opacity(0.1)
        case .notDetermined:
            return Color.blue.opacity(0.1)
        @unknown default:
            return Color.secondary.opacity(0.1)
        }
    }
    
    /// Status icon based on permission state
    private var statusIcon: String {
        switch photosPermission.authorizationStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .limited:
            return "exclamationmark.triangle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    /// Status color based on permission state
    private var statusColor: Color {
        switch photosPermission.authorizationStatus {
        case .authorized:
            return .green
        case .limited:
            return .yellow
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .blue
        @unknown default:
            return .secondary
        }
    }
    
    /// Status title text
    private var statusTitle: String {
        switch photosPermission.authorizationStatus {
        case .authorized:
            return "Full Access Granted"
        case .limited:
            return "Limited Access"
        case .denied:
            return "Access Denied"
        case .restricted:
            return "Access Restricted"
        case .notDetermined:
            return "Permission Not Requested"
        @unknown default:
            return "Unknown Status"
        }
    }
    
    /// Status description text
    private var statusDescription: String {
        switch photosPermission.authorizationStatus {
        case .authorized:
            return "TypeSafe can automatically fetch your most recent screenshot."
        case .limited:
            return "Screenshots may not be available. Consider granting full access."
        case .denied:
            return "Photos access is required for automatic scanning. You can still use the manual picker."
        case .restricted:
            return "Photos access is restricted by device policy. Manual picker available."
        case .notDetermined:
            return "Grant Photos access to enable automatic screenshot fetching."
        @unknown default:
            return "Unknown permission status."
        }
    }
    
    // MARK: - Actions
    
    /// Request Photos permission
    private func requestPermission() {
        isRequestingPermission = true
        
        Task {
            let status = await photosPermission.requestAuthorization()
            
            await MainActor.run {
                isRequestingPermission = false
                
                // Show info if permission was granted or denied
                if status == .authorized || status == .limited {
                    showingPermissionInfo = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        ScreenshotScanningSection(settingsManager: SettingsManager.shared)
    }
}

