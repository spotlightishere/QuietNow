//
//  AVIngressDelegate.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-27.
//

import AVFoundation
import Foundation
import OSLog

let ingressLogger = Logger(subsystem: "space.joscomputing.QuietNow", category: "Asset Ingress")

/// It is alarmingly difficult to create an AVAsset from Data.
/// (This is probably for fair reasons - it would be awful to download a 1.7 GB movie and synchronously load it.)
/// Unfortunately, that goes against what we want - FileWrapper only provides the file's contents.
/// Here, we fake reading from a URL by providing data directly.
///
/// Derived from this Stack Overflow answer: https://stackoverflow.com/a/60298272
class AVIngressDelegate: NSObject, AVAssetResourceLoaderDelegate {
    let internalData: Data
    let internalType: UTType

    init(contents: Data, type: UTType) {
        internalData = contents
        internalType = type
    }

    func resourceLoader(_: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        // Here we basically create a jank range-request type thing.
        let requestedOffset = loadingRequest.dataRequest?.requestedOffset ?? 0
        let requestedLength = Int64(loadingRequest.dataRequest?.requestedLength ?? 0)
        let endOffset = requestedOffset + requestedLength
        if endOffset > internalData.count {
            return false
        }

        ingressLogger.debug("Resource loader requested \(requestedLength) bytes starting at offset \(requestedOffset)")

        // This appears to require UTI form (public.mpeg) verses MIME (audio/mpeg).
        loadingRequest.contentInformationRequest?.contentType = internalType.identifier
        loadingRequest.contentInformationRequest?.contentLength = Int64(internalData.count)

        let resultingData = internalData[requestedOffset ... endOffset - 1]
        loadingRequest.dataRequest?.respond(with: resultingData)
        loadingRequest.finishLoading()
        return true
    }
}
