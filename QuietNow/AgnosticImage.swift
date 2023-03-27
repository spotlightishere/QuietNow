//
//  AgnosticImage.swift
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

func agnosticImage(data: Data) -> Image {
    #if os(macOS)
        Image(nsImage: NSImage(data: data)!)
    #else
        Image(uiImage: UIImage(data: data)!)
    #endif
}
