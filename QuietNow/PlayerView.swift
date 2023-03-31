//
//  PlayerView.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import AVKit
import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var currentTrack: PlayingTrack
    @State var vocalLevel: Float32 = 85.0
    @State var exportButton = "Export"
    @State var exportProgress: Float = 0.0

    // We'll leverage this AVPlayer for our track.
    let audioPlayer = AVPlayer()

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                // Track album artwork
                VStack(alignment: .center) {
                    currentTrack.artwork
                        .resizable()
                        .scaledToFit()
                }.frame(minWidth: 0, maxWidth: .infinity)

                // Track metadata
                VStack(alignment: .center) {
                    Text("\(currentTrack.title)")
                    Text("\(currentTrack.album) \u{2014} \(currentTrack.artist)")
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
                currentTrack.adjust(attenuationLevel: vocalLevel)
            }.padding()

            // We'd also like an export button.
            Button("\(exportButton)") {
                Task {
                    do {
                        exportButton = "Exporting..."
                        try await currentTrack.export(progress: $exportProgress)
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
        .task {
            audioPlayer.replaceCurrentItem(with: currentTrack.playerItem)
            audioPlayer.play()
        }
    }
}
