//
//  LocalFileReader.swift
//  VividPlayer
//
//  Created by Rohit Pal on 09/03/24.
//

import Foundation


class LocalFileReader {
    let fileLocator: LocalFileLocator = .init()
    private func readDataFromScratchFile(fileUrl: URL, range: ByteRange) throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileUrl.path()) else {
            throw NSError(domain: "com.example.app", code: -1, userInfo: ["reason": "No such file exist at: \(fileUrl.path())"])
        }
        let partialReadHandle = try FileHandle(forReadingFrom: fileUrl)
        try partialReadHandle.seek(toOffset: UInt64(range.lowerBound))
        let data = try partialReadHandle.read(upToCount: range.length.toInt())
        try partialReadHandle.close()
        return data
    }
    
    func getData(forRemoteUrl remoteUrl: URL, inRange range: ByteRange) throws -> Data? {
        let fileUrl = try fileLocator.getFileUrl(remoteUrl: remoteUrl, type: .scratch)
        return try readDataFromScratchFile(fileUrl: fileUrl, range: range)
    }

    func getMetaData(forRemoteUrl remoteUrl: URL) throws -> MetaFileData? {
        do {
            let fileUrl = try fileLocator.getFileUrl(remoteUrl: remoteUrl, type: .metaData)
            let data = try Data(contentsOf: fileUrl)
            
            if !data.isEmpty {
                return try JSONDecoder().decode(MetaFileData.self, from: data)//PropertyListDecoder().decode(MetaFileData.self, from: data)
            }
            return nil
        } catch {
            Logger.log("LocalFileReader: Error occured while reading meta data, error: \(error)")
            throw error
        }
    }
}
