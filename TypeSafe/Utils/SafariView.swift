//
//  SafariView.swift
//  TypeSafe
//
//  Story 3.8: Privacy Controls & Settings
//  Safari view wrapper for displaying privacy policy and external web content
//

import SwiftUI
import SafariServices

/// SwiftUI wrapper for SFSafariViewController
/// Displays web content within the app using Safari's rendering engine
struct SafariView: UIViewControllerRepresentable {
    
    /// URL to display
    let url: URL
    
    /// Creates the Safari view controller
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredBarTintColor = UIColor.systemBackground
        safari.preferredControlTintColor = UIColor.systemBlue
        
        return safari
    }
    
    /// Updates the Safari view controller (no-op for this use case)
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // Safari view controller doesn't need updates
    }
}

// MARK: - Preview Provider

#Preview {
    SafariView(url: URL(string: "https://www.apple.com")!)
}

