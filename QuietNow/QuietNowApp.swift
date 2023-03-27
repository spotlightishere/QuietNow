//
//  QuietNowApp.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import SwiftUI

@main
struct QuietNowApp: App {
    var body: some Scene {
        DocumentGroup(viewing: TrackDocument.self) { loadedFile in
            PlayerView(file: loadedFile.document)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
