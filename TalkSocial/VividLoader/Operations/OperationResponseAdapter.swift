//
//  OperationResponseAdapter.swift
//  VividPlayer
//
//  Created by Rohit Pal on 10/03/24.
//

import AVFoundation
import Foundation

protocol LoadingRequestable: AnyObject {

    var isCancelled: Bool { get }
    var isFinished: Bool { get }
    
    func respond(withData data: Data)
    
    func finishLoading()
    
    func finishLoading(with error: Error?)
    
}

extension AVAssetResourceLoadingDataRequest {
    var byteRange: ByteRange {
        let lowerBound = requestedOffset
        let upperBound = (lowerBound + Int64(requestedLength))
        return (lowerBound..<upperBound)
    }
    
}

extension AVAssetResourceLoadingRequest: LoadingRequestable {
    func respond(withData data: Data) {
        self.dataRequest?.respond(with: data)
    }
}

protocol OperationResponseAdapter: AnyObject {
    var onFinishLoading: ((_ error: Error?) -> Void)? { get set }

    func didReceive(data: Data, inRange range: ByteRange)
    func finishLoading()
    func finishLoading(with error: Error?)
}

class OperationResponseAdapterImpl: OperationResponseAdapter {
    var onFinishLoading: ((_ error: Error?) -> Void)?
    private let requestedByteRange: ByteRange
    private var cursorPosition: Int64
    private var pendingSeqDataRange: [(range: ByteRange, data: Data)] = []
    private let loadingRequest: LoadingRequestable
    
    init(requestedByteRange: ByteRange, loadingRequest: LoadingRequestable) {
        self.requestedByteRange = requestedByteRange
        self.cursorPosition = requestedByteRange.lowerBound// last filled location
        self.loadingRequest = loadingRequest
    }
    
    // add serialization
    func didReceive(data: Data, inRange range: ByteRange) {
        guard !(loadingRequest.isCancelled || loadingRequest.isFinished) else {
            return
        }
        if cursorPosition == range.lowerBound {
            respond(withData: data, range: range)
            processPendingSeqDataRange()
        } else {
            pendingSeqDataRange.append((range, data))
        }
    }
    
    func finishLoading() {
        loadingRequest.finishLoading()
        onFinishLoading?(nil)
        Logger.log("finished loading \(loadingRequest)")
    }
    
    func finishLoading(with error: Error?) {
        loadingRequest.finishLoading(with: error)
        onFinishLoading?(error)
        Logger.log("finished loading \(loadingRequest) with error")
    }
    
    private func processPendingSeqDataRange() {
        guard !(loadingRequest.isCancelled || loadingRequest.isFinished) else {
            return
        }
        guard !pendingSeqDataRange.isEmpty else {
            if (cursorPosition - 1) == requestedByteRange.upperBound {
                loadingRequest.finishLoading()
            }
            return
        }
        let firstItem = pendingSeqDataRange.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }).first
        guard let firstItem,
              cursorPosition == firstItem.range.lowerBound else {
            return
        }
        respond(withData: firstItem.data, range: firstItem.range)
        pendingSeqDataRange.removeAll(where: { $0.range == firstItem.range })
        processPendingSeqDataRange()
    }
    
    private func respond(withData data: Data, range: ByteRange) {
        guard let dataToRespond = data.byteRangeResponseSubdata(in: range) else {
            return
        }
        cursorPosition = range.upperBound
//        print("Responded with data in range: \(range)")
        loadingRequest.respond(withData: dataToRespond)
    }

}
