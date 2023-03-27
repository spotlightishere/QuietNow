//
//  ContentView.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import AVKit
import SwiftUI

struct ContentView: View {
    @State var audioPlayer: PlayerManager = .init()

    var body: some View {
        HStack {
            audioPlayer.currentTrackInfo.trackArtwork
                .fixedSize()
            VStack {
                Text("\(audioPlayer.currentTrackInfo.trackTitle)")
                Text("\(audioPlayer.currentTrackInfo.trackAlbum) \u{2014} \(audioPlayer.currentTrackInfo.trackArtist)")
            }
        }
        .padding()
        .frame(width: 500.0, height: 300.0)
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

                    try await audioPlayer.play(item: contents)
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
