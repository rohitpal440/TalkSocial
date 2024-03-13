//
//  LocalFileLocator.swift
//  VividPlayer
//
//  Created by Rohit Pal on 09/03/24.
//

import Foundation

class LocalFileLocator {
    enum CachedFileType: String {
        case scratch
        case metaData
    }

    func getFileUrl(remoteUrl: URL, type: CachedFileType) throws -> URL {
        guard let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "com.example.app", code: -1, userInfo: ["reason": "Could not find document directory"])
        }
        let cacheDir = documentDirectoryURL.appendingPathComponent("video_cache_directory")
        let lastPathComponent = remoteUrl.lastPathComponent
        var lastPathComponents = lastPathComponent.split(separator: ".")
        if lastPathComponents.count > 1 {
            lastPathComponents = lastPathComponents.dropLast()
        }
            
        var l = Array(lastPathComponents)
        switch type {
        case .metaData:
            l.append(".meta")
        case .scratch:
            l.append(".scratch")
        }
        let lastPath = l.joined()
        var remoteUrlPaths: [String] = []
        if let host = remoteUrl.host?.split(separator: ".").joined(separator: "_") {
            remoteUrlPaths.append(host)
        }
        let pathComponents = remoteUrl.pathComponents.filter({ $0 != "/"}).dropLast()
        remoteUrlPaths.append(contentsOf: pathComponents)
        remoteUrlPaths.append(lastPath)
        
        let filename = remoteUrlPaths.map{ $0.replacingOccurrences(of: " ", with: "_") }.joined(separator: "/")
        let fileURL = cacheDir.appendingPathComponent(filename)
        return fileURL
    }
}
