//
//  LocalFileLoader.swift
//  VividPlayer
//
//  Created by Rohit Pal on 09/03/24.
//

import Foundation


class LocalFileLoaderPool {
    var collection: [URL: LocalFileLoader] = [:]
    
    func getFileLoader(remoteUrl: URL) -> LocalFileLoader {
        guard collection[remoteUrl] == nil else {
            return collection[remoteUrl]!
        }
        let loader = LocalFileLoader(remoteUrl: remoteUrl)
        collection[remoteUrl] = loader
        return loader
    }
}


class LocalFileLoader {
    private let operationQueue: OperationQueue = .init()
    private let reader = LocalFileReader()
    private let writer = LocalFileWriter()
    private let remoteUrl: URL
    
    init(remoteUrl: URL) {
        self.remoteUrl = remoteUrl
        self.operationQueue.maxConcurrentOperationCount = 1
        self.operationQueue.qualityOfService = .default
        
    }
    
    func getData(inRange range: ByteRange, completion: @escaping (Data?, Error?) -> Void)  {
        createOperation {[weak self] in
            guard let reader = self?.reader, let remoteFileUrl = self?.remoteUrl else {
                return
            }
            do {
                let data = try reader.getData(forRemoteUrl: remoteFileUrl, inRange: range)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    func getMetaData(completion: @escaping (MetaFileData?, Error?) -> Void)  {
        createOperation {[weak self] in
            guard let reader = self?.reader, let remoteFileUrl = self?.remoteUrl else {
                return
            }
            do {
                let data = try reader.getMetaData(forRemoteUrl: remoteFileUrl)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    func save(data: Data, range: ByteRange, completion: @escaping (Error?) -> Void) {
        createOperation {[weak self] in
            guard let writer = self?.writer, let remoteUrl = self?.remoteUrl else {
                return
            }
            do {
                try writer.save(data: data, remoteUrl: remoteUrl, range: range)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    private func createOperation(workItem: @escaping () -> Void) {
        operationQueue.addOperation(workItem)
    }
    
    
}
