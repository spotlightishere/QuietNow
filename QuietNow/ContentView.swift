//
//  ContentView.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import AVKit
import SwiftUI

struct ContentView: View {
    let audioPlayer = AVPlayer()
    @State var currentTrack = PlayingTrack()
    @State var vocalLevel: Float32 = 85.0
    @State var exportButton = "Export"
    @State var exportProgress: Float = 0.0

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                VStack(alignment: .center) {
                    currentTrack.artwork
                        .resizable()
                        .scaledToFit()
                }.frame(minWidth: 0, maxWidth: .infinity)
                    .padding()

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
            }.disabled(currentTrack.playerItem == nil)
            if exportProgress != 0.0 {
                ProgressView(value: exportProgress)
            }
        }
        .padding()
        .frame(maxWidth: 500.0, maxHeight: 300.0)
        .onAppear {
            // Begin playing as soon as possible.
            audioPlayer.play()
        }
        .onDrop(of: [.audio], isTargeted: nil) { items, _ in
            // We'll only utilize the first file.
            guard items.count == 1, let firstItem = items.first else {
                return false
            }

            Task {
                do {
                    guard let contents = try await firstItem.loadItem(forTypeIdentifier: UTType.audio.identifier) as? URL else {
                        return
                    }
                    try await loadSong(from: contents)
                } catch let e {
                    print("Error encountered while handling dropped song: \(e)")
                }
            }
            return true
        }
    }

    /// Loads a song for the current audio player, applying a custom audio mix.
    /// - Parameter contents: The URL to utilize when playing this song.
    func loadSong(from contents: URL) async throws {
        let potentialTrack = try await PlayingTrack(with: contents)
        audioPlayer.replaceCurrentItem(with: potentialTrack.playerItem)
        audioPlayer.play()
        // We initialize the audio unit to be 85.0, and it
        // would be a pain to persist that, so we are simply not.
        vocalLevel = 85.0
        currentTrack = potentialTrack
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
