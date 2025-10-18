//
//  PhotoPickerView.swift
//  TypeSafe
//
//  Created by Dev Agent on 18/01/25.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Photos

/// UIViewControllerRepresentable wrapper for PHPickerViewController
/// Handles photo selection from the user's photo library
struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var onImageSelected: ((UIImage) -> Void)?
    var onError: ((PhotoPickerError) -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss picker first
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
            
            guard let result = results.first else {
                return // User cancelled selection
            }
            
            // Check if the selected item is a supported image format
            guard result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
                DispatchQueue.main.async {
                    self.parent.onError?(.unsupportedFormat)
                }
                return
            }
            
            // Validate specific image formats (PNG, JPEG only)
            let supportedTypes = [UTType.png.identifier, UTType.jpeg.identifier]
            var isSupported = false
            
            for type in supportedTypes {
                if result.itemProvider.hasItemConformingToTypeIdentifier(type) {
                    isSupported = true
                    break
                }
            }
            
            guard isSupported else {
                DispatchQueue.main.async {
                    self.parent.onError?(.unsupportedFormat)
                }
                return
            }
            
            // Load the image with proper error handling
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        self.parent.onError?(.loadingFailed(error))
                        return
                    }
                    
                    guard let image = object as? UIImage else {
                        self.parent.onError?(.invalidImageData)
                        return
                    }
                    
                    // Ensure we're on main thread for UI updates
                    self.parent.selectedImage = image
                    self.parent.onImageSelected?(image)
                }
            }
        }
    }
}

/// Errors that can occur during photo picking
enum PhotoPickerError: LocalizedError {
    case unsupportedFormat
    case loadingFailed(Error)
    case invalidImageData
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported image format. Please select a PNG or JPEG image."
        case .loadingFailed(let error):
            return "Failed to load image: \(error.localizedDescription)"
        case .invalidImageData:
            return "The selected image data is invalid or corrupted."
        case .accessDenied:
            return "Access to photos is denied. Please enable photo access in Settings."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat:
            return "Try selecting a different image in PNG or JPEG format."
        case .loadingFailed, .invalidImageData:
            return "Please try selecting a different image."
        case .accessDenied:
            return "Go to Settings > Privacy & Security > Photos to enable access."
        }
    }
}
