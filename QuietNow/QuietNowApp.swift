//
//  QuietNowApp.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import SwiftUI

@main
struct QuietNowApp: App {
    #if os(macOS)
        init() {
            // Under macOS, attempt to determine a reasonable model path.
            let modelPath = UserDefaults.standard.string(forKey: "modelPath") ?? ""
            if modelPath.isEmpty {
                let possibleLocations = [
                    // Just in case macOS starts shipping with the model.
                    "/System/Library/PrivateFrameworks/MediaPlaybackCore.framework/Resources",
                    // Normal Xcode...
                    "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/MediaPlaybackCore.framework",
                    // ...and beta Xcode.
                    "/Applications/Xcode-beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/MediaPlaybackCore.framework",
                ]

                // Attempt to (rather lazily) find a default.
                for location in possibleLocations {
                    if FileManager.default.fileExists(atPath: location + "/aufx-nnet-appl.plist") {
                        UserDefaults.standard.setValue(location, forKey: "modelPath")
                        break
                    }
                }
            }
        }
    #endif

    var body: some Scene {
        DocumentGroup(viewing: TrackDocument.self) { loadedFile in
            TrackDocumentView(file: loadedFile.document)
                .frame(width: 500.0, height: 300.0)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif

        #if os(macOS)
            Settings {
                SettingsView()
            }
        #endif
    }
}
