//
//  PlayerView.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import AVKit
import SwiftUI

struct PlayerView: View {
    var file: TrackDocument
    @State var vocalLevel: Float32 = 85.0
    @State var exportButton = "Export"
    @State var exportProgress: Float = 0.0

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                VStack(alignment: .center) {
                    file.currentTrack.artwork
                        .resizable()
                        .scaledToFit()
                }.frame(minWidth: 0, maxWidth: .infinity)
                    .padding()

                VStack(alignment: .center) {
                    Text("\(file.currentTrack.title)")
                    Text("\(file.currentTrack.album) \u{2014} \(file.currentTrack.artist)")
                    Spacer()
                    Text("Attenuation level: \(vocalLevel)")
                }.frame(minWidth: 0, maxWidth: .infinity)
                    .padding()
            }.frame(minWidth: 0, maxWidth: .infinity)
                .padding()

            Slider(
                value: $vocalLevel,
                in: 0.0 ... 100.0
            ) {
                Text("Attenuation:")
            } onEditingChanged: { _ in
                file.currentTrack.adjust(attenuationLevel: vocalLevel)
            }.padding()

            // We'd also like an export button.
            Button("\(exportButton)") {
                Task {
                    do {
                        exportButton = "Exporting..."
                        try await file.currentTrack.export(progress: $exportProgress)
                        exportButton = "Export"
                    } catch let e {
                        print("Exception while exporting: \(e)")
                    }
                }
            }
            if exportProgress != 0.0 {
                ProgressView(value: exportProgress)
            }
        }
        .padding()
        .frame(maxWidth: 500.0, maxHeight: 300.0)
    }
}
