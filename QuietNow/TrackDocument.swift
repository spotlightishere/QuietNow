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

/// The primary track document used to load an asset. It should be considered read-only.
/// To export a track, asynchronously create an ``ExportTrackDocument``.
struct TrackDocument: FileDocument {
    // We will attempt to support any audio type.
    static var readableContentTypes: [UTType] = [.audio]
    // We do not want to saving as we are read-only.
    static var writableContentTypes: [UTType] = []

    let ingressQueue = DispatchQueue(label: "space.joscomputing.QuietNow.asset-ingress-queue")
    let ingressDelegate: AVIngressDelegate
    let audioAsset: AVURLAsset

    init(configuration: ReadConfiguration) throws {
        guard let fileContents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadUnknown)
        }

        // We need to create an AVAsset from the provided file contents.
        // Frustratingly, this is rather difficult out-of-the-box.
        //
        // Here, we use a custom schema - "asset-ingress" - to force
        // our AVIngressDelegate to be called, allowing for us to feed
        // the user chosen file's data as-is.
        audioAsset = AVURLAsset(url: URL(string: "asset-ingress://example")!)
        ingressDelegate = AVIngressDelegate(contents: fileContents, type: configuration.contentType)
        audioAsset.resourceLoader.setDelegate(ingressDelegate, queue: ingressQueue)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        // We do not support saving.
        throw CocoaError(.fileWriteNoPermission)
    }
}

/// To work around the need of Swift asynchronous and the lack of support with SwiftUI,
/// ExportTrackDocument exists. For normal reading and operations, use ``TrackDocument``.
struct ExportTrackDocument: FileDocument {
    // We do not want to reading as we are write-only.
    static var readableContentTypes: [UTType] = []
    static var writableContentTypes: [UTType] = [.audio]

    let fileLocation: URL?

    init(configuration _: ReadConfiguration) throws {
        // We do not support reading directly.
        throw CocoaError(.fileReadNoPermission)
    }

    init(location: URL) {
        fileLocation = location
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        guard let fileLocation else {
            throw CocoaError(.fileWriteUnknown)
        }

        return try FileWrapper(url: fileLocation, options: .immediate)
    }
}

struct TrackDocumentView: View {
    var file: TrackDocument
    @StateObject var currentTrack = PlayingTrack()

    // This is rather jank...
    @State private var trackLoaded = false
    @State private var errorText = ""
    @AppStorage(ModelPathKey) private var modelPath = getModelPath()

    var body: some View {
        if modelPath.isEmpty {
            SettingsView()
        } else if trackLoaded {
            PlayerView()
                .environmentObject(currentTrack)
        } else if errorText != "" {
            Text(errorText)
                .padding()
        } else {
            ProgressView("Loading track...")
                .task {
                    do {
                        try await currentTrack.load(asset: file.audioAsset)
                        trackLoaded = true
                    } catch let e {
                        print("Encountered exception while loading track: \(e)")
                        errorText = "An error occurred while loading: \(e)"
                    }
                }
                .padding()
        }
    }
}
