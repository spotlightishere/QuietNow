//
//  SettingsView.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-27.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage("modelPath") private var modelPath = ""

    var body: some View {
        Form {
            Text("""
            macOS does not ship with the necessary neural network model to function.

            However, the Xcode simulator runtimes do. Please install Xcode and insert the path
            to MediaPlaybackCore.framework within a simulator runtime.
            Alternatively, obtain a copy from an iOS/watchOS/[...] device, OTA, or IPSW.")

            The resulting folder should contain three files prefixed with "vi-nnet.espresso",
            and one file titled "aufx-nnet-appl.plist".
            """).fixedSize()
                .padding()
            Spacer()
            TextField("Model Path", text: $modelPath)
                .padding()
        }.padding()
    }
}
