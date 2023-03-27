//
//  PlayerManager.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-26.
//

import AVFoundation
import Foundation
import SwiftUI

class TrackInfo: ObservableObject {
    public var trackTitle = "Unknown title"
    public var trackArtist = "-"
    public var trackAlbum = "-"
    public var trackArtwork = Image(systemName: "music.quarternote.3")
}

class PlayerManager {
    @ObservedObject var currentTrackInfo = TrackInfo()
    let audioPlayer = AVPlayer()

    init() {
        // Begin playing as soon as possible.
        audioPlayer.play()
        currentTrackInfo.trackTitle = "Not playing"
        currentTrackInfo.trackAlbum = "Drag and drop a file"
        currentTrackInfo.trackArtist = "to get started"
    }

    func play(item: URL) async throws {
        let audioItem = try await createPlayerItem(for: item)
        let asset = audioItem.asset

        // Attempt to fill in metadata if it is available.
        let assetMetadata = try await asset.load(.commonMetadata)
        let trackInfo = TrackInfo()
        for metadata in assetMetadata {
            guard let keyName = metadata.commonKey else {
                continue
            }

            // We may not have a value in a form we expect - ensure we do.
            guard let identifierValue = try await metadata.load(.value) else {
                continue
            }

            switch keyName {
            case .commonKeyTitle:
                trackInfo.trackTitle = identifierValue as! String
            case .commonKeyAlbumName:
                trackInfo.trackAlbum = identifierValue as! String
            case .commonKeyArtist:
                trackInfo.trackArtist = identifierValue as! String
            case .commonKeyArtwork:
                trackInfo.trackArtwork = agnosticImage(data: identifierValue as! Data)
            default:
                break
            }
        }
        currentTrackInfo = trackInfo

        audioPlayer.replaceCurrentItem(with: audioItem)
    }
}
