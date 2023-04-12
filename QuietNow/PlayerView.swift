//
//  PlayerView.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import AVKit
import SwiftUI

struct PlayerView: View {
    // Track playback
    @EnvironmentObject var currentTrack: PlayingTrack
    // We mirror currentTrack.vocalLevel here within `task`.
    // 85.0 is a good default, and is also what it begins with.
    @State var vocalLevel: Float32 = 85.0

    // We'll leverage this AVPlayer for our track.
    let audioPlayer = AVPlayer()

    // Used for the attenuation text field.
    let levelFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 4
        return formatter
    }()

    // Export state
    @State var stateDocument: ExportTrackDocument? = nil
    @State var exportProgress: Float = 0.0
    @State var isExporting = false
    @State var readyToSave = false

    var body: some View {
        Grid(alignment: .center) {
            // Track album artwork
            currentTrack.artwork
                .resizable()
                .padding()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300.0)

            // Track metadata
            VStack {
                Text("\(currentTrack.title)")
                    .bold()
                Text("\(currentTrack.album) \u{2014} \(currentTrack.artist)")
            }

            // Attenuation controls
            VStack {
                Text("Attenuation:")
                TextField("", value: $vocalLevel, formatter: levelFormatter)

                Slider(value: $vocalLevel, in: 0.0 ... 100.0) {
                    Text("Attenuation Level")
                } minimumValueLabel: {
                    Image(systemName: "mic")
                } maximumValueLabel: {
                    Image(systemName: "mic.slash")
                }
            }.padding()
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        // Update attenuation level for slider and text field
        .onChange(of: vocalLevel) { level in
            currentTrack.adjust(attenuationLevel: level)
        }
        // Export progress
        .overlay(alignment: .topTrailing) {
            // Export progress
            if isExporting {
                VStack {
                    Text("Exporting...")
                    ProgressView(value: exportProgress)
                }.padding()
                    .frame(width: 200.0)
                    .background(.gray)
                    .cornerRadius(10)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Export") {
                    Task {
                        do {
                            isExporting = true
                            let exportLocation = try await currentTrack.export(progress: $exportProgress)
                            stateDocument = ExportTrackDocument(location: exportLocation)
                            // Present our save dialog.
                            readyToSave = true
                        } catch let e {
                            print("Exception while exporting: \(e)")
                            readyToSave = false
                        }
                    }
                }.disabled(isExporting)
            }
        }
        .task {
            audioPlayer.replaceCurrentItem(with: currentTrack.playerItem)
            audioPlayer.play()
        }
        .fileExporter(isPresented: $readyToSave, document: stateDocument, contentType: .audio, defaultFilename: "exported.m4a", onCompletion: { result in
            switch result {
            case let .failure(e):
                print("Encountered exception while saving: \(e)")
            case let .success(url):
                print("Saved to \(url)!")
                // Clean up after ourselves.
                do {
                    guard let fileLocation = stateDocument?.fileLocation else {
                        // ...how did we complete with a nil origin location?
                        return
                    }

                    try FileManager.default.removeItem(at: fileLocation)
                } catch _ {}
            }

            isExporting = false
            readyToSave = false
        })
    }
}

struct PlayerView_Previews: PreviewProvider {
    @StateObject private static var artworkTrack: PlayingTrack = {
        let track = PlayingTrack()
        track.title = "Scream And Shout"
        track.album = "Trash Tracks"
        track.artist = "Playing Possum"
        track.artwork = Image("Example Album Artwork")
        return track
    }()

    @StateObject private static var noArtTrack: PlayingTrack = {
        let track = PlayingTrack()
        track.title = "Hanging On By A Tail"
        track.album = "Trash Tracks"
        track.artist = "Playing Possum"
        return track
    }()

    @StateObject private static var exportTrack: PlayingTrack = {
        let track = PlayingTrack()
        track.title = "Our Possability"
        track.album = "Trash Tracks"
        track.artist = "Playing Possum"
        track.artwork = Image("Example Album Artwork")
        return track
    }()

    static var previews: some View {
        // Track with artwork
        PlayerView()
            .environmentObject(artworkTrack)
            .previewDisplayName("With Artwork")
        // Track without artwork
        PlayerView()
            .environmentObject(noArtTrack)
            .previewDisplayName("Without Artwork")
        // Track with export progress
        PlayerView(exportProgress: 75.0, isExporting: true)
            .environmentObject(exportTrack)
            .previewDisplayName("Export Progress")
    }
}
