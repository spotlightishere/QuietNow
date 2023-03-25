//
//  AudioUnitWrapper.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-25.
//

import AVFoundation
import Foundation

extension OSStatus {
    func audioSuccess() throws {
        guard self == noErr else {
            throw PlaybackError.audioUnitError(self)
        }
    }
}

func AudioComponentInstanceNew(_ component: AudioComponent) throws -> AudioComponentInstance {
    var componentInstance: AudioComponentInstance?
    try AudioComponentInstanceNew(component, &componentInstance).audioSuccess()
    return componentInstance!
}

extension AudioUnitScope {
    static let global = kAudioUnitScope_Global
    static let input = kAudioUnitScope_Input
    static let output = kAudioUnitScope_Output
}

extension AudioComponentInstance {
    func initialize() throws {
        try AudioUnitInitialize(self).audioSuccess()
    }

    func uninitialize() throws {
        try AudioUnitUninitialize(self).audioSuccess()
    }

    func setProperty(property: AudioUnitPropertyID, scope: AudioUnitScope, data: UnsafeRawPointer?, dataSize: UInt32) throws {
        // Here, we assume element will always be zero.
        try AudioUnitSetProperty(self, property, scope, 0, data, dataSize).audioSuccess()
    }
    
    func setParameter(parameter: AudioUnitParameterID, scope: AudioUnitScope, value: AudioUnitParameterValue, offset: UInt32) throws {
        try AudioUnitSetParameter(self, parameter, scope, 0, value, offset).audioSuccess()
    }
}
