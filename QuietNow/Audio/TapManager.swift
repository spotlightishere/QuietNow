//
//  TapManager.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import AVFoundation
import AVKit
import Foundation

enum PlaybackError: Error {
    case songNotFound
    case audioUnitNotFound
    case audioUnitError(OSStatus)
}

/// Values within tap metadata are passed around throughout tap callbacks.
@objc class TapMetadata: NSObject {
    var audioUnit: AudioUnit? = nil
    var maxFrameCount: UInt32 = 0
    var processingFormat: UnsafePointer<AudioStreamBasicDescription>? = nil
    var sampleCount: Float64 = 0.0
}

/// Our global storage, used within tap callbacks.
var tapMetadata = TapMetadata()

// Via tap callbacks, we can glean information about the track
// and apply our audio unit accordingly.
//
// This design is taken from Apple's AudioTapProcessor sample code:
// https://developer.apple.com/library/ios/samplecode/AudioTapProcessor/Introduction/Intro.html
// It is also very similar to that of MediaPlaybackCore.framework.
enum TapLifecycle {
    static let tapInitCallback: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
        // [... we have nothing to initialize, as we use the global TapMetadata variable ...]
        tapStorageOut.pointee = clientInfo
    }

    static let tapFinalizeCallback: MTAudioProcessingTapFinalizeCallback = { _ in
        // [... we have nothing to clean up, probably. phew! ...]
    }

    // Within prepare, we create our audio unit.
    static let tapPrepareCallback: MTAudioProcessingTapPrepareCallback = { currentTap, maxFrameCount, processingFormat in
        // Here, we create and initialize an audio unit we can work with.
        //
        // Note: For readability purposes, creating the voice isolation
        // audio unit is within VoiceIsolationUnit.swift.
        let storage = MTAudioProcessingTapGetStorage(currentTap)
        var metadata = unsafeBitCast(storage, to: TapMetadata.self)
        metadata.maxFrameCount = UInt32(maxFrameCount)
        metadata.processingFormat = processingFormat

        let audioUnit = createVocalIsolationUnit(with: currentTap)
        metadata.audioUnit = audioUnit
    }

    // When unpreparing, only handle tearing down the audio unit.
    static let tapUnprepareCallback: MTAudioProcessingTapUnprepareCallback = { currentTap in
        // Sweet dreams, sweet audio unit.
        var metadata = unsafeBitCast(MTAudioProcessingTapGetStorage(currentTap), to: TapMetadata.self)
        disposeAudioUnit(metadata.audioUnit!)
    }

    // Here's what really matters: our process callback.
    // Here, we apply the audio unit.
    static let tapProcessCallback: MTAudioProcessingTapProcessCallback = { currentTap, frameCount, _, bufferList, frameCountOut, _ in
        var metadata = unsafeBitCast(MTAudioProcessingTapGetStorage(currentTap), to: TapMetadata.self)

        // We need to let the unit know where to start.
        var audioTimeStamp = AudioTimeStamp()
        audioTimeStamp.mSampleTime = metadata.sampleCount
        audioTimeStamp.mFlags = .sampleTimeValid

        // And... we're off!
        do {
            try AudioUnitRender(metadata.audioUnit!, nil, &audioTimeStamp, 0, UInt32(frameCount), bufferList).audioSuccess()
        } catch let e {
            print("Error while rendering via audio unit: \(e)")
        }

        // Keep track of how many frames we handled.
        metadata.sampleCount += Double(frameCount)
        frameCountOut.pointee = frameCount
    }
}

func createExampleItem() async throws -> AVPlayerItem {
    // TODO: Something something streaming, configuration
    guard let songLocation = Bundle.main.url(forResource: "Drugstore Perfume", withExtension: "mp3") else {
        throw PlaybackError.songNotFound
    }

    // Let's load the asset, and find the first track that's audio.
    let audioAsset = AVAsset(url: songLocation)
    guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
        throw PlaybackError.songNotFound
    }

    // Next, we'll create an audio mix for this track.
    // This allows us to attach a tap that samples the song as it plays,
    // provide input to the voice isolation AudioUnit and rendering accordingly.
    let audioMix = AVMutableAudioMix()
    let mixInputParameters = AVMutableAudioMixInputParameters(track: audioTrack)

    // Create the tap.
    var tapCallbacks = MTAudioProcessingTapCallbacks(
        version: kMTAudioProcessingTapCallbacksVersion_0,
        clientInfo: Unmanaged.passUnretained(tapMetadata).toOpaque(),
        init: TapLifecycle.tapInitCallback,
        finalize: TapLifecycle.tapFinalizeCallback,
        prepare: TapLifecycle.tapPrepareCallback,
        unprepare: TapLifecycle.tapUnprepareCallback,
        process: TapLifecycle.tapProcessCallback
    )
    var audioTap: Unmanaged<MTAudioProcessingTap>?
    try MTAudioProcessingTapCreate(kCFAllocatorDefault, &tapCallbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &audioTap).audioSuccess()

    // Now, apply it to the mix.
    mixInputParameters.audioTapProcessor = audioTap?.takeRetainedValue()
    audioMix.inputParameters = [mixInputParameters]

    // This AVPlayerItem utilizes our custom mix, and thus is suitable for playback.
    let audioItem = AVPlayerItem(asset: audioAsset)
    audioItem.audioMix = audioMix
    return audioItem
}
