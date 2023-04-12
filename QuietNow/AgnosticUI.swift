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
