//
//  AutoScanErrorBanner.swift
//  TypeSafe
//
//  Story 5.3: Error Handling & Edge Cases
//  Reusable error banner for automatic scan failures
//

import SwiftUI

/// Banner displaying user-friendly error messages for automatic scan failures
struct AutoScanErrorBanner: View {
    let error: ScreenshotFetchService.ScreenshotFetchError
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with icon and dismiss button
            HStack {
                Image(systemName: errorIcon)
                    .foregroundColor(.red)
                    .font(.title3)
                
                Text(errorTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
                .accessibilityLabel("Dismiss error")
            }
            
            // Error message
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Settings button (only for permission errors)
            if shouldShowSettingsButton {
                Button(action: onOpenSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .accessibilityLabel("Open iOS Settings to grant Photos permission")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // MARK: - Private Computed Properties
    
    private var errorIcon: String {
        switch error {
        case .permissionDenied, .limitedAccessNoScreenshot:
            return "lock.fill"
        case .timeout:
            return "clock.fill"
        case .notFound, .tooOld:
            return "photo.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .permissionDenied:
            return "Photos Access Required"
        case .limitedAccessNoScreenshot:
            return "Limited Photos Access"
        case .timeout:
            return "Fetch Timed Out"
        case .notFound:
            return "Screenshot Not Found"
        case .tooOld:
            return "Screenshot Too Old"
        default:
            return "Auto-Scan Failed"
        }
    }
    
    private var errorMessage: String {
        switch error {
        case .permissionDenied:
            return "Enable Photos access in Settings for automatic scanning. You can still select screenshots manually."
        case .limitedAccessNoScreenshot:
            return "Your screenshot isn't available in Limited Photos selection. Grant full access or select manually."
        case .timeout:
            return "Screenshot fetch took too long (>5 seconds). Opening manual picker instead."
        case .notFound:
            return "Screenshot not found in photo library. It may have been deleted. Opening manual picker..."
        case .tooOld:
            return "Screenshot is older than 60 seconds. Opening manual picker..."
        default:
            return "Couldn't load screenshot automatically. You can select it manually instead."
        }
    }
    
    private var shouldShowSettingsButton: Bool {
        return error == .permissionDenied || error == .limitedAccessNoScreenshot
    }
}

#Preview {
    VStack(spacing: 20) {
        AutoScanErrorBanner(
            error: .permissionDenied,
            onOpenSettings: {},
            onDismiss: {}
        )
        
        AutoScanErrorBanner(
            error: .timeout,
            onOpenSettings: {},
            onDismiss: {}
        )
        
        AutoScanErrorBanner(
            error: .notFound,
            onOpenSettings: {},
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

