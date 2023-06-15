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
            TrackDocumentView(file: loadedFile.document)
            #if os(macOS)
                // Under macOS, SwiftUI allows a very interesting default layout without a minimum set.
                .frame(minWidth: 500.0, minHeight: 500.0)
            #endif
        }
        #if os(macOS)
        // Attempt to avoid having a save button.
        .commands {
            CommandGroup(replacing: .saveItem) {}
        }
        #endif

        #if os(macOS)
            // Allow configuring model path
            Settings {
                SettingsView()
            }
        #endif
    }
}
