//
//  PlayingTrack.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-26.
//

import AVFoundation
import Foundation
import SwiftUI

class PlayingTrack: ObservableObject {
    public var title = "Unknown title"
    public var artist = "-"
    public var album = "-"
    public var artwork = Image(systemName: "music.quarternote.3")
    public var playerItem: AVPlayerItem? = nil
    private var audioMix: AVAudioMix?

    init() {
        title = "Not playing"
        album = "Drag and drop a file"
        artist = "to get started"
    }

    init(with item: URL) async throws {
        let asset = AVAsset(url: item)

        // Applying this audio mix allows us to leverage the audio unit throughout playback.
        audioMix = try await createAudioMix(for: item)
        playerItem = AVPlayerItem(asset: asset)
        playerItem!.audioMix = audioMix!

        // Attempt to fill in metadata if it is available.
        let assetMetadata = try await asset.load(.commonMetadata)
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
                title = identifierValue as! String
            case .commonKeyAlbumName:
                album = identifierValue as! String
            case .commonKeyArtist:
                artist = identifierValue as! String
            case .commonKeyArtwork:
                artwork = agnosticImage(data: identifierValue as! Data)
            default:
                break
            }
        }
    }
}
