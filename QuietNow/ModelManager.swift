//
//  ModelManager.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-06-14.
//

import Foundation

enum ModelError: Error {
    case modelNotFound
    case invalidSimctlOutput
}

let ModelPathKey = "modelPath"

#if os(macOS)

// MARK: simctl output parsing

// We expect the JSON out to look something like the following:
//
// {
//   "runtimes:" [
//     {
//       "runtimeRoot": "[...]"
//     },
//     [...]
//   ]
// }
struct SimctlRuntime: Decodable {
    let runtimeRoot: String
}

struct SimctlRuntimes: Decodable {
    let runtimes: [SimctlRuntime]
}


/// Fetch registered iOS simulator runtimes.
///
/// In Xcode 15.0 and above, the iOS simulator runtime exists outside of Xcode.
/// Additionally, in any version previously, Xcode is not necessarily installed within /Applications.
/// As such, we can utilize `xcrun simctl list runtimes --json` to get all available runtimes.
func fetchSimulatorRuntimes() throws -> [String] {
    let simctlPipe = Pipe()
    
    let simctl = Process()
    // We're hardcoding this - fingers crossed it doesn't change in the future
    simctl.executableURL = URL(filePath: "/usr/bin/xcrun")
    simctl.arguments = ["simctl", "list", "runtimes", "--json"]
    simctl.standardOutput = simctlPipe
    try simctl.run()
    simctl.waitUntilExit()
    
    // We should be able to parse this as JSON.
    let simctlOutputData = try simctlPipe.fileHandleForReading.readToEnd()
    guard let simctlOutputData else {
        throw ModelError.invalidSimctlOutput
    }
    
    let simctlRuntimes = try JSONDecoder().decode(SimctlRuntimes.self, from: simctlOutputData)
    let allRuntimeRoots = simctlRuntimes.runtimes.map {
        // Append the framework path to the runtime roots.
        $0.runtimeRoot + "/System/Library/PrivateFrameworks/MediaPlaybackCore.framework"
    }
    return allRuntimeRoots
}

// MARK: Model paths

/// Attempts to search for a registered model path.
/// - Returns: A string with the model path, suitable for providing to the Audio Unit. If not possible, returns empty.
func getModelPath() -> String {
    // Under macOS, attempt to determine a reasonable model path.
    let modelPath = UserDefaults.standard.string(forKey: "modelPath") ?? ""
    // Ensure our saved model path is still present.
    if FileManager.default.fileExists(atPath: modelPath) == false {
        UserDefaults.standard.removeObject(forKey: ModelPathKey)
    }

    guard modelPath.isEmpty else {
        // We have a model path, and it exists.
        return modelPath
    }

    // First, let's check if it exists natively, just in case macOS starts shipping with this model.
    var possibleLocations = [
        "/System/Library/PrivateFrameworks/MediaPlaybackCore.framework/Resources"
    ]
    // Append simulator runtimes, if possible.
    do {
        let simulatorRuntimes = try fetchSimulatorRuntimes()
        possibleLocations += simulatorRuntimes
        print("Simulator runtime paths: \(possibleLocations)")
    } catch {
        // You'll have to configure the path on your own, sorry :)
    }
    
    // Attempt to find a default.
    for location in possibleLocations {
        if FileManager.default.fileExists(atPath: location + "/aufx-nnet-appl.plist") {
            UserDefaults.standard.setValue(location, forKey: "modelPath")
            return location
        }
    }
    
    // We were unable to find a model path.
    return ""
}

#else

// Shim to provide support for macOS' discovery. It does not throw.
func getModelPath() -> String {
    // We will rely on the location of MediaPlaybackCore.framework.
    // While we should likely look up its bundle by identifier, hardcoding will suffice for now.
    return "/System/Library/PrivateFrameworks/MediaPlaybackCore.framework"
}

#endif
