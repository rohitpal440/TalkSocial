//
//  LocalFileWriter.swift
//  VividPlayer
//
//  Created by Rohit Pal on 09/03/24.
//

import Foundation

class LocalFileWriter {
    private let fileLocator: LocalFileLocator = .init()
    private let fileReader: LocalFileReader = .init()
    private let lock = NSLock()
    
    private func createFileIfNotExist(atLocation filelocation: URL) throws {
        guard !FileManager.default.fileExists(atPath: filelocation.path()) else {
            return
        }
        let directoryLocation = filelocation.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryLocation, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: filelocation.path(), contents: nil)
    }
    
    private func writeToFile(fileUrl: URL, data: Data, in range: ByteRange) throws {
        lock.lock()
        do {
            try createFileIfNotExist(atLocation: fileUrl)
            let partialWriteHandle = try FileHandle(forUpdating: fileUrl)
            try partialWriteHandle.seek(toOffset: UInt64(range.lowerBound))
            guard let subData = data.byteRangeResponseSubdata(in: range) else {
                throw NSError(domain: "com.example.app", code: -1, userInfo: ["reason": "Provided Range Length is larger than data size"])
            }
            partialWriteHandle.write(subData)
            try partialWriteHandle.synchronize()
            try partialWriteHandle.close()
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
    }
    
    private func writeToScratchFile(remoteUrl: URL, data: Data, in range: ByteRange) throws {
        let scratchFileUrl = try fileLocator.getFileUrl(remoteUrl: remoteUrl, type: .scratch)
        try writeToFile(fileUrl: scratchFileUrl, data: data, in: range)
    }
    
    private func writeMetaFile(fileUrl: URL, metaData: MetaFileData) throws {
        lock.lock()
        do {
            let encodedData = try JSONEncoder().encode(metaData)//PropertyListEncoder().encode(metaData)
            try encodedData.write(to: fileUrl, options: .atomic)
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
    }
    
    private func addAndUpdateMetaDataRanges(remoteUrl: URL, in range: ByteRange) throws  {
        let metaFileUrl = try fileLocator.getFileUrl(remoteUrl: remoteUrl, type: .metaData)
        try createFileIfNotExist(atLocation: metaFileUrl)
        
        let storedData = try fileReader.getMetaData(forRemoteUrl: remoteUrl)
        let updatedData: MetaFileData = storedData?.addedWith(byteRanges: [range]) ?? .init(url: remoteUrl, downloadedRanges: [range])
        try writeMetaFile(fileUrl: metaFileUrl, metaData: updatedData)
        
    }
    
    private func doCleanupIfRequired(remoteUrl: URL) throws {
        lock.lock()
        do {
            let metaFileUrl = try fileLocator.getFileUrl(remoteUrl: remoteUrl, type: .metaData)
            if !FileManager.default.fileExists(atPath: metaFileUrl.path()) {
                Logger.log("Meta file missing for remote url :\(remoteUrl), cleaning up!")
                let scratchFileUrl = try fileLocator.getFileUrl(remoteUrl: remoteUrl, type: .scratch)
                try FileManager.default.removeItem(atPath: scratchFileUrl.path())
            }
            lock.unlock()
        } catch { // to isolate debugging without changing the effect
            lock.unlock()
            throw error
        }
    }
    
    func save(data: Data, remoteUrl: URL, range: ByteRange) throws {
//        try doCleanupIfRequired(remoteUrl: remoteUrl) // not required as of now file handles overwrite data at given range
        try writeToScratchFile(remoteUrl: remoteUrl, data: data, in: range)
//        print("LocalFileWriter: Saved Data in range: \(range) for remoteURL: \(remoteUrl)")
        try addAndUpdateMetaDataRanges(remoteUrl: remoteUrl, in: range)
//        print("LocalFileWriter: Updated MetaData in range: \(range) for remoteURL: \(remoteUrl)")
        
    }

}
