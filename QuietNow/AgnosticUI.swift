//
//  AgnosticUI.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-26.
//

import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Allows agnostically loading an image via NSImage or an UIimage.
/// - Parameter data: Data that can be representable by an image
/// - Returns: A SwiftUI image
func agnosticImage(data: Data) -> Image {
    #if os(macOS)
        Image(nsImage: NSImage(data: data)!)
    #else
        Image(uiImage: UIImage(data: data)!)
    #endif
}

@MainActor
struct DialogHandler {
    /// Prompts the user to save an audio file.
    /// - Returns: The URL the user chose, or nil if cancelled.
    func fileSaveDialog() async -> URL? {
        #if os(macOS)
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = "exported.m4a"
            switch await savePanel.begin() {
            case .OK:
                return savePanel.url
            default:
                return nil
            }

        #else
            // TODO: Implement
            return URL.temporaryDirectory.appending(path: "exported.m4a")
        #endif
    }
}
