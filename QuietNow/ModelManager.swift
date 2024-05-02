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
    func fetchSimulatorRuntimes() throws -> [URL] {
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
            // Append the runtime roots to the framework path.
            let frameworkPath = $0.runtimeRoot + "/System/Library/PrivateFrameworks/MediaPlaybackCore.framework"
            return URL(filePath: frameworkPath)
        }
        return allRuntimeRoots
    }

    // MARK: Model paths

    /// Attempts to search for a registered model path.
    /// - Returns: A string with the model path, suitable for providing to the Audio Unit. If not possible, returns empty.
    func getFrameworkPaths() -> [URL] {
        // First, let's check if it exists natively - just in case macOS begins shipping with this model.
        var possibleLocations = [
            URL(filePath: "/System/Library/PrivateFrameworks/MediaPlaybackCore.framework/Versions/A/Resources"),
        ]
        // Append simulator runtimes, if possible.
        do {
            let simulatorRuntimes = try fetchSimulatorRuntimes()
            possibleLocations += simulatorRuntimes
        } catch {
            // You'll have to configure the simulator path on your own, sorry :)
        }

        return possibleLocations
    }

#else

    // Shim to provide support for iOS, watchOS, tvOS, xrOS, [...] discovery. It does not throw.
    func getFrameworkPaths() -> [URL] {
        // We will rely on the location of MediaPlaybackCore.framework.
        // While we should likely look up its bundle by identifier, hardcoding will suffice for now.
        return [URL(filePath: "/System/Library/PrivateFrameworks/MediaPlaybackCore.framework")]
    }

#endif

extension URL {
    /// Quick quality-of-life hack to avoid repeatedly calling out to FileManager.
    func exists() -> Bool {
        FileManager.default.fileExists(atPath: rawPath)
    }

    /// A similar quality-of-life hack to avoid a ton of URL encoded paths.
    var rawPath: String {
        path(percentEncoded: false)
    }

    /// Determines whether the given URL is a directory.
    // https://stackoverflow.com/a/65152079
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

/// Determines whether the given location has a model.
/// We determine whether the model's "aufx-nnet-appl.plist" property list is present.
func pathHasValidModel(_ modelPath: URL) -> Bool {
    return modelPath.appending(path: "aufx-nnet-appl.plist").exists()
}

/// Attempts to search for a registered model path.
/// - Returns: A string with the model path, suitable for providing to the Audio Unit. If not possible, returns empty.
func getModelPath() -> String {
    // Under macOS, the user can configure their own model path.
    // Under iOS, watchOS, tvOS, [...], we configure it on their behalf.
    let modelPath = UserDefaults.standard.string(forKey: "modelPath")
    if let modelPath {
        let modelPathUrl = URL(filePath: modelPath)

        // Ensure our saved model path still contains a valid model.
        if pathHasValidModel(modelPathUrl) {
            return modelPathUrl.rawPath
        }

        // Otherwise, remove the stored default.
        UserDefaults.standard.removeObject(forKey: ModelPathKey)
    }

    // Let's iterate through all possible framework locations.
    let possibleLocations = getFrameworkPaths()
    print("Checking possible locations: \(possibleLocations)")

    // Attempt to find a default.
    let fileManager = FileManager.default
    for frameworkLocation in possibleLocations {
        // First, let's ensure this framework's directory exists.
        print("Checking \(frameworkLocation)")
        guard frameworkLocation.exists() else {
            continue
        }
        print("Checking framework location \(frameworkLocation)...")

        // In older iOS, watchOS, tvOS, [...] versions, the model is located directly within the framework.
        if pathHasValidModel(frameworkLocation) {
            UserDefaults.standard.setValue(frameworkLocation.rawPath, forKey: "modelPath")
            return frameworkLocation.rawPath
        }

        do {
            try fileManager.contentsOfDirectory(at: frameworkLocation, includingPropertiesForKeys: [.isDirectoryKey])
        } catch let e {
            print("uhh \(e)")
        }

        // In at least iOS 17.4 and later, the model resides within a subdirectory.
        // For example, as of iOS 17.5, the model resides in the subdirectory "czutbtg4y9".
        // We'll iterate to attempt to find a subdirectory with a valid model property list.
        guard let frameworkContents = try? fileManager.contentsOfDirectory(at: frameworkLocation, includingPropertiesForKeys: [.isDirectoryKey]) else {
            // Hmm... we should be able to recurse.
            continue
        }

        for contentLocation in frameworkContents {
            // Let's only iterate through directories within the framework.
            guard contentLocation.isDirectory else {
                continue
            }

            print("Checking subdirectory \(contentLocation)")

            // Ensure this directory has a model.
            if pathHasValidModel(contentLocation) {
                UserDefaults.standard.setValue(contentLocation.rawPath, forKey: "modelPath")
                return contentLocation.rawPath
            }
        }
    }

    // We were unable to find a model path.
    return ""
}
