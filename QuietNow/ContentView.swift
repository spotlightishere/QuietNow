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
    @State var exportProgress: Float = 0.0

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                VStack(alignment: .center) {
                    currentTrack.artwork
                        .resizable()
                        .scaledToFit()
                }.frame(minWidth: 0, maxWidth: .infinity)

                VStack(alignment: .center) {
                    Text("\(currentTrack.title)")
                    Text("\(currentTrack.album) \u{2014} \(currentTrack.artist)")
                    Spacer()
                    Text("Attenuation level: \(vocalLevel)")
                }.frame(minWidth: 0, maxWidth: .infinity)
            }.frame(minWidth: 0, maxWidth: .infinity)
                .padding()

            Slider(
                value: $vocalLevel,
                in: 0.0 ... 100.0
            ) {
                Text("Attenuation:")
            } onEditingChanged: { _ in
                currentTrack.adjust(attenuationLevel: vocalLevel)
            }

            // We'd also like an export button.
            Button("Export... \(exportProgress)") {
                Task {
                    do {
                        try await currentTrack.export(progress: $exportProgress)
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
        .frame(width: 500.0, height: 300.0)
        .onAppear {
            // Begin playing as soon as possible.
            audioPlayer.play()
        }
        .onDrop(of: [.audio], isTargeted: nil) { items, _ in
            // We'll only utilize the first file.
            if items.count != 1 {
                return false
            }
            guard let firstItem = items.first else {
                return false
            }

            // Load contents, and play!
            Task {
                do {
                    guard let contents = try await firstItem.loadItem(forTypeIdentifier: UTType.audio.identifier) as? URL else {
                        return
                    }

                    let potentialTrack = try await PlayingTrack(with: contents)
                    audioPlayer.replaceCurrentItem(with: potentialTrack.playerItem)
                    audioPlayer.play()
                    // We initialize the audio unit to be 85.0, and it
                    // would be a pain to persist that, so we are simply not.
                    vocalLevel = 85.0
                    currentTrack = potentialTrack
                } catch let e {
                    print("Exception while playing: \(e)")
                }
            }
            return true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
