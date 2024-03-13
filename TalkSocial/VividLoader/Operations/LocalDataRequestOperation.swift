//
//  LocalDataRequestOperation.swift
//  VividPlayer
//
//  Created by Rohit Pal on 10/03/24.
//

import Foundation


class LocalDataRequestOperation: AsyncOperation {
    private let url: URL
    private let requestedRange: ByteRange
    private var cursor: Int64
    private let localfileLoader: LocalFileLoader
    private let responseSink: OperationResponseAdapter
    
    init(url: URL, requestedRange: ByteRange, responseSink: OperationResponseAdapter) {
        self.url = url
        self.requestedRange = requestedRange
        self.cursor = requestedRange.lowerBound
        self.responseSink = responseSink
        self.localfileLoader = LocalFileLoaderPool().getFileLoader(remoteUrl: url)
    }
    
    override func main() {
        Logger.log("LocalDataRequestOperation: Executing local data operation in range \(requestedRange)")
        guard !isCancelled else {
            Logger.log("LocalDataRequestOperation: Cancelled befor load read data in range from file: \(requestedRange)")
            return
        }
        let requestedByteRange = self.requestedRange
        localfileLoader.getData(inRange: requestedByteRange) {[weak self] data, error in
            guard self?.isCancelled == false else {
                Logger.log("LocalDataRequestOperation: Cancelled read data in range from file: \(requestedByteRange)")
                return
            }
            guard let data, error == nil else {
                Logger.log("LocalDataRequestOperation: Failed to read data in range from file: \(requestedByteRange)")
                self?.responseSink.finishLoading(with: error)
                return
            }
            self?.responseSink.didReceive(data: data, inRange: requestedByteRange)
            self?.responseSink.finishLoading()
            self?.finish()
        }
    }
}
