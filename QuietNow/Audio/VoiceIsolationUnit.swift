//
//  VoiceIsolationUnit.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-25.
//

import AVFoundation
import Foundation

/// There's no clean way for us to handle errors while processing, so we handle this
/// by crashing. Sure, this brings us back to Microsoft® Windows™ levels of error handling,
/// but this is okay. Probably.
func createVocalIsolationUnit(with tap: MTAudioProcessingTap) -> AudioUnit {
    do {
        return try createUnit(with: tap)
    } catch let e {
        print("Encountered exception while creating vocal isolation unit: \(e)")
        abort()
    }
}

// If this ever changes, something is very wrong.
let uint32DataSize = UInt32(MemoryLayout<UInt32>.size)
let formatDescSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
let renderCallbackSize = UInt32(MemoryLayout<AURenderCallbackStruct>.size)
let stringPointerSize = UInt32(MemoryLayout<CFString>.size)

/// Creates the custom vocal isolation audio unit.
func createUnit(with tap: MTAudioProcessingTap) throws -> AudioUnit {
    // Attempt to find the voice isolation audio component.
    //  - Manufacturer: Apple
    //  - Type: Effect
    //  - Subtype: Sound/Voice Isolation ('vois')
    var searchDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_AUSoundIsolation,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )
    guard let audioComponent = AudioComponentFindNext(nil, &searchDescription) else {
        throw PlaybackError.audioUnitNotFound
    }

    // Create an audio unit we can work with.
    let audioUnit = try AudioComponentInstanceNew(audioComponent)

    // We'll need to set a few properties...
    let metadata = unsafeBitCast(MTAudioProcessingTapGetStorage(tap), to: TapMetadata.self)

    // First, we learned the stream format and maximum frame count from the tap.
    // We can set those as properties on our audio unit.
    try audioUnit.setProperty(property: kAudioUnitProperty_MaximumFramesPerSlice, scope: .global, data: &metadata.maxFrameCount, dataSize: uint32DataSize)
    // For stream format, this should apply to both our input and output.
    try audioUnit.setProperty(property: kAudioUnitProperty_StreamFormat, scope: .input, data: metadata.processingFormat, dataSize: formatDescSize)
    try audioUnit.setProperty(property: kAudioUnitProperty_StreamFormat, scope: .output, data: metadata.processingFormat, dataSize: formatDescSize)

    // XXX: Denosing off. Default seems to be 1.0
    try audioUnit.setParameter(parameter: 0x17626, scope: .global, value: 1.0, offset: 0)
    // XXX: Tuning mode
    try audioUnit.setParameter(parameter: 0x17627, scope: .global, value: 1.0, offset: 0)
    // XXX: Attenuation level - referred to as "wet/dry mix percent"
    try audioUnit.setParameter(parameter: kAUSoundIsolationParam_WetDryMixPercent, scope: .global, value: 85.0, offset: 0)

    // Next, we'll need to create a render callback to give audio input.
    let audioInputCallback: AURenderCallback = { inputRef, _, _, _, frameCount, dataBuffer -> OSStatus in
        if dataBuffer == nil {
            // This isn't on us.
            return kAudioCodecIllegalOperationError
        }

        // Return the amount of frames we were requested of.
        // inputRef is set to the current MTAudioProcessingTap via AURenderCallbackStruct.
        let passedTap = unsafeBitCast(inputRef, to: MTAudioProcessingTap.self)
        return MTAudioProcessingTapGetSourceAudio(passedTap, CMItemCount(frameCount), dataBuffer!, nil, nil, nil)
    }
    var audioInputFunc = AURenderCallbackStruct(inputProc: audioInputCallback, inputProcRefCon: Unmanaged.passUnretained(tap).toOpaque())
    try audioUnit.setProperty(property: kAudioUnitProperty_SetRenderCallback, scope: .input, data: &audioInputFunc, dataSize: renderCallbackSize)

    // Lastly, specify models locations.
    #if os(macOS)
        // Under macOS, this must be a configurable location.
        let modelDirectory = URL(filePath: UserDefaults.standard.string(forKey: "modelPath") ?? "")
    #else
        // We will rely on the location of MediaPlaybackCore.framework.
        // While we should likely look up its bundle by identifier, hardcoding will suffice for now.
        let modelDirectory = URL(filePath: "/System/Library/PrivateFrameworks/MediaPlaybackCore.framework")
    #endif
    guard try modelDirectory.checkResourceIsReachable() else {
        throw PlaybackError.modelNotFound
    }

    // XXX: 30000 is plist path
    var plistPath = modelDirectory.appending(component: "aufx-nnet-appl.plist").path() as CFString
    try audioUnit.setProperty(property: 30000, scope: .global, data: &plistPath, dataSize: stringPointerSize)

    // XXX: 40000 is model base path
    var modelBasePath = modelDirectory.path() as CFString
    try audioUnit.setProperty(property: 40000, scope: .global, data: &modelBasePath, dataSize: stringPointerSize)

    // XXX: 50000 disables dereverb
    // TODO: This seems to disable a neural network for dereverb - how is it used? Why?
    var dereverbModelPath = "" as CFString
    try audioUnit.setProperty(property: 50000, scope: .global, data: &dereverbModelPath, dataSize: stringPointerSize)

    try audioUnit.initialize()
    return audioUnit
}

func disposeAudioUnit(_ unit: AudioUnit) {
    do {
        try unit.uninitialize()
        try AudioComponentInstanceDispose(unit).audioSuccess()
    } catch let e {
        print("Encountered exception while disposing of vocal isolation unit: \(e)")
        abort()
    }
}
