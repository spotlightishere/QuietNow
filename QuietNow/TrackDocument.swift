//
//  TrackDocument.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-27.
//

import AVFoundation
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct TrackDocument: FileDocument {
    // We will attempt to support any audio type.
    static var readableContentTypes: [UTType] = [.audio]

    // We do not want to support snapshotting as we're read-only.
    // We use Int simply because we can.
    static var writableContentTypes: [UTType] = []

    // Our view will interface with our AVPlayer and AVPlayerItem.
    let audioPlayer = AVPlayer()
    @State var currentTrack: PlayingTrack

    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let fileContents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadUnknown)
        }

        // We need to create an AVAsset from the provided file contents.
        // Frustratingly, this is rather difficult out-of-the-box.
        //
        // Here, we use a custom schema - "ingress-asset" - to force
        // our AVIngressDelegate to be called, allowing for us to feed
        // the user chosen file's data as-is.
        let ingressAsset = AVURLAsset(url: URL(string: "ingress-asset://example")!)
        let ingressDelegate = AVIngressDelegate(contents: fileContents, type: configuration.contentType)
        ingressAsset.resourceLoader.setDelegate(ingressDelegate, queue: .main)

        // Further frustratingly, we need async throughout initialization
        // for reading AVAsset components. On the other hand, we need to synchronously initialize.
        // Dear future employers, this code does not exist. Safety is gone. Welcome to the wild west.
        var trackValue: Result<PlayingTrack, Error> = .failure(CocoaError(.fileReadUnknown))
        let loadSemaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                let createdTrack = try await PlayingTrack(with: ingressAsset)
                trackValue = .success(createdTrack)
            } catch let e {
                print("Encountered error loading track: \(e)")
                trackValue = .failure(e)
            }
            loadSemaphore.signal()
        }
        loadSemaphore.wait()
        currentTrack = try trackValue.get()

        // Lastly, begin playing!
        audioPlayer.replaceCurrentItem(with: currentTrack.playerItem)
        audioPlayer.play()
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        // We do not support saving.
        throw CocoaError(.fileWriteNoPermission)
    }
}
