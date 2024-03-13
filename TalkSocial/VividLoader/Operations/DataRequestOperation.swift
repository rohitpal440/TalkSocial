//
//  DataRequestOperation.swift
//  VividPlayer
//
//  Created by Rohit Pal on 10/03/24.
//

import Foundation
import AVFoundation

class DataRequestOperation: AsyncOperation {
    private let loadingRequest: LoadingRequestable
    private let operationQueue: OperationQueue = .init()
    private let localFileLoader: LocalFileLoader
    private let remoteUrl: URL
    private let reqByteRange: ByteRange
    
    var onFinishTask: ((_ error: Error?) -> Void)?
    
    private var outstandingOperations: [Operation] = []

    init(loadingRequest: LoadingRequestable, remoteUrl: URL, reqByteRanges: ByteRange) {
        self.loadingRequest = loadingRequest
        self.remoteUrl = remoteUrl
        self.reqByteRange = reqByteRanges
        self.localFileLoader = LocalFileLoaderPool().getFileLoader(remoteUrl: remoteUrl)
    
    }
    
    override func main() {
        guard !isCancelled else { return }
        Logger.log("NEW DATA REQUEST OPERATION\n")
        Logger.log("Loading Request: \(loadingRequest)\n\n")
        localFileLoader.getMetaData {[weak self] metaData, error in
            if let error {
                Logger.log("DataRequestOperation: Some problem occured while reading meta Data: \(error)")
                self?.executeRequest(downloadedRanges: [])
            } else if let metaData {
                self?.executeRequest(downloadedRanges: metaData.downloadedRanges)
            } else {
                Logger.log("DataRequestOperation: No Meta Data Found")
                self?.executeRequest(downloadedRanges: [])
            }
        }
    }

    func executeRequest(downloadedRanges: [ByteRange]) {
        guard let operationRespAdapter = getOpResponseAdapter() else {
            return
        }
        let operations = getOperations(downloadedRanges: downloadedRanges, adapter: operationRespAdapter)
        self.outstandingOperations = operations
        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
    
    private func getOpResponseAdapter() -> OperationResponseAdapter? {
        let adapter = OperationResponseAdapterImpl(requestedByteRange: reqByteRange, loadingRequest: loadingRequest)
        adapter.onFinishLoading = {[weak self] error in
            self?.finish()
            self?.onFinishTask?(error)
        }
        return adapter
    }
    
    private func getOperations(downloadedRanges: [ByteRange], adapter: OperationResponseAdapter) -> [Operation] {
        return ByteRangeOperationFactory.getOperations(requestedRange: reqByteRange, remoteUrl: remoteUrl, downloadedRanges: downloadedRanges, respSink: adapter)
    }
    
    override func cancel() {
        super.cancel()
        outstandingOperations.forEach { $0.cancel() }
        
    }
    
    static func getDataRequestOperation(fromLoadingRequest loadingRequest: AVAssetResourceLoadingRequest, remoteUrl: URL) -> DataRequestOperation? {
        guard let byteRange = loadingRequest.dataRequest?.byteRange else {
            return nil
        }
        return .init(loadingRequest: loadingRequest, remoteUrl: remoteUrl, reqByteRanges: byteRange)
    }
}


