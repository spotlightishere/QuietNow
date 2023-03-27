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

    var body: some View {
        HStack {
            currentTrack.artwork
                .fixedSize()
            VStack {
                Text("\(currentTrack.title)")
                Text("\(currentTrack.album) \u{2014} \(currentTrack.artist)")
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
