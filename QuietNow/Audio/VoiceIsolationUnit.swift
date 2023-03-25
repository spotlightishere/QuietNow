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

/// Creates the custom vocal isolation audio unit.
func createUnit(with tap: MTAudioProcessingTap) throws -> AudioUnit {
    // Attempt to find the voice isolation audio component.
    //  - Manufacturer: Apple
    //  - Type: Effect
    //  - Subtype: Voice Isolation ('vois')
    var searchDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: OSType(0x766F_6973), // vois
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
    var metadata = unsafeBitCast(MTAudioProcessingTapGetStorage(tap), to: TapMetadata.self)

    // First, we learned the stream format and maximum frame count from the tap.
    // We can set those as properties on our audio unit.
    try audioUnit.setProperty(property: kAudioUnitProperty_MaximumFramesPerSlice, scope: kAudioUnitScope_Input, data: &metadata.maxFrameCount, dataSize: uint32DataSize)
    // For stream format, this should apply to both our input and output.
    try audioUnit.setProperty(property: kAudioUnitProperty_StreamFormat, scope: kAudioUnitScope_Input, data: metadata.processingFormat, dataSize: formatDescSize)
    try audioUnit.setProperty(property: kAudioUnitProperty_StreamFormat, scope: kAudioUnitScope_Output, data: metadata.processingFormat, dataSize: formatDescSize)

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
    try audioUnit.setProperty(property: kAudioUnitProperty_SetRenderCallback, scope: kAudioUnitScope_Input, data: &audioInputFunc, dataSize: UInt32(MemoryLayout<AURenderCallbackStruct>.size))

    // Lastly, specify models...(?)
    // TODO: properties 30000, 40000, 50000
    
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
