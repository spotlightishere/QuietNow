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
    public var playerItem: AVPlayerItem
    private var audioMix: AVAudioMix

    init(with asset: AVAsset) async throws {
        // Applying this audio mix allows us to leverage the audio unit throughout playback.
        audioMix = try await createAudioMix(for: asset)
        playerItem = AVPlayerItem(asset: asset)
        playerItem.audioMix = audioMix

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

    /// Adjusts the vocal attenuation level for the currently playing item.
    /// - Parameter attenuationLevel: The desired level.
    /// 0.0 represents off. Upper bounds are 1000.0, although any value beyond 100.0 produces rather unique results.
    func adjust(attenuationLevel: Float32) {
        let currentTap = audioMix.inputParameters.first!.audioTapProcessor!
        let metadata = unsafeBitCast(MTAudioProcessingTapGetStorage(currentTap), to: TapMetadata.self)
        let audioUnit = metadata.audioUnit!
        do {
            try audioUnit.setParameter(parameter: 0, scope: .global, value: attenuationLevel, offset: 0)
            print("Attenuation level is now \(attenuationLevel)")
        } catch let e {
            print("Error adjusting vocal attenuation level: \(e)")
        }
    }

    func export(progress currentProgress: Binding<Float>) async throws {
        // Prompt the user to select where to export.
        guard let userLocation = await DialogHandler().fileSaveDialog() else {
            // The user (hopefully) cancelled.
            return
        }

        let asset = playerItem.asset
        let exportAudioMix = try await createAudioMix(for: asset)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw PlaybackError.exportFailed
        }
        exportSession.audioMix = exportAudioMix
        exportSession.outputURL = userLocation
        exportSession.outputFileType = .m4a

        let exportTimer = Timer(timeInterval: 0.5, repeats: true) { currentTimer in
            switch exportSession.status {
            case .exporting:
                currentProgress.wrappedValue = exportSession.progress
            case .failed, .cancelled:
                print("Error occurred whilst exporting: \(exportSession.error?.localizedDescription ?? "Empty error")")
                currentProgress.wrappedValue = 0.0
                currentTimer.invalidate()
            case .completed:
                print("Export complete.")
                currentProgress.wrappedValue = 0.0
                currentTimer.invalidate()
            default:
                print("Export session in state \(exportSession.status)")
            }
        }
        RunLoop.main.add(exportTimer, forMode: .common)
        await exportSession.export()
    }
}
