//
//  VividAsset.swift
//  VividPlayer
//
//  Created by Rohit Pal on 11/03/24.
//

import Foundation
import AVFoundation

class VividAsset: AVURLAsset {
    let resourceLoaderDelegateObj = ResourceLoaderDelegateImpl()
    override init(url: URL, options: [String : Any]? = nil) {
        let assetUrl = url.convertToRedirectURL(prefix: URL.vividCustomScheme)
        super.init(url: assetUrl ?? url, options: options)
        self.resourceLoader.setDelegate(resourceLoaderDelegateObj, queue: DispatchQueue.global())
    }
    
    func preload() {
        guard let remoteUrl = self.url.convertFromRedirectURL(prefix: URL.vividCustomScheme) else { return }
        resourceLoaderDelegateObj.preload(url: remoteUrl)
    }
}

struct LoadingRequestWaitWrapper {
    let loadingRequest: AVAssetResourceLoadingRequest
    let cursorPositionOfParentRequest: Int64?
    let parentLoadingRequest: AVAssetResourceLoadingRequest?
}

class ResourceLoaderDelegateImpl: NSObject, AVAssetResourceLoaderDelegate {
    var outStandingRequests: Atomic<[ByteRange: (loadingRequest: AVAssetResourceLoadingRequest, dataOperation: AsyncOperation)]> = .init([:])
    var outstandinWaitingList: Atomic<[(range: ByteRange, requests: [AVAssetResourceLoadingRequest])]> = .init([])
    var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    var preloadOperation: AsyncOperation?
    var isPreloadingCancelled: Bool = false
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        cancel(loadingRequest: loadingRequest)
        
    }

    private func cancel(loadingRequest: AVAssetResourceLoadingRequest) {
        guard loadingRequest.contentInformationRequest == nil,
              let requestedRange = loadingRequest.dataRequest?.byteRange else {
            return
        }
        
        outStandingRequests.mutate { value in
            value[requestedRange]?.dataOperation.cancel()
            value.removeValue(forKey: requestedRange)
        }
        
        Logger.log("ResourceLoaderDelegateImpl: Did Cancel loading request: \(loadingRequest)")
    }
    
    private func finish(loadingRequest: AVAssetResourceLoadingRequest, error: Error?) {
        guard loadingRequest.contentInformationRequest == nil,
              let requestedRange = loadingRequest.dataRequest?.byteRange else {
            return
        }
        outStandingRequests.mutate { value in
            value.removeValue(forKey: requestedRange)
        }
        if error != nil {
            //TODO: initiate pending loading request to fetch data
        }
        if let info = self.outstandinWaitingList.value.first(where: { requestedRange.isInsideOrEqual($0.range) }) {
            outstandinWaitingList.mutate { value in
                value.removeAll { requestedRange.isInsideOrEqual($0.range) }
            }
            info.requests.forEach { $0.finishLoading() }
        }
        
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard loadingRequest.contentInformationRequest == nil else {
            let operation = ContentRequestOperation(loadingRequest: loadingRequest)
            operationQueue.addOperation(operation)
            return true
        }
        guard let dataRequest = loadingRequest.dataRequest else {
            return false
        }
        let requestedRange = dataRequest.byteRange
        
        if let index = outstandinWaitingList.value.firstIndex(where: { requestedRange.isInsideOrEqual($0.range) }) {
            var info = outstandinWaitingList.value[index]
            
            if let outstandingRequest = outStandingRequests.value[info.range]?.loadingRequest,
               outstandingRequest.isCancelled,
               let currentOffset = outstandingRequest.dataRequest?.currentOffset {
                
                if requestedRange.lowerBound > currentOffset {
                    let cursorDistanceFromLowerBound = requestedRange.lowerBound - currentOffset
                    if Double(cursorDistanceFromLowerBound) <= (Double(requestedRange.length) * 0.1) {
                        info.requests.append(loadingRequest)
                        outstandinWaitingList.mutate { value in
                            value[index] = info
                        }
                        return true
                    }
                    // continue normal execution
                } else if requestedRange.upperBound > currentOffset { // i.e lower bound is less than cursor
                    info.requests.append(loadingRequest)
                    outstandinWaitingList.mutate { value in
                        value[index] = info
                    }
                    return true
                }
            }
        }
        guard let remoteUrl = loadingRequest.request.url?.convertFromRedirectURL(prefix: URL.vividCustomScheme) else {
            return false
        }
        
        let operation = DataRequestOperation(loadingRequest: loadingRequest, remoteUrl: remoteUrl, reqByteRanges: requestedRange)
        operation.onFinishTask = {[weak self] error in
            self?.finish(loadingRequest: loadingRequest, error: error)
        }
        outStandingRequests.mutate { value in
            value[requestedRange] = (loadingRequest, operation)
        }
        outstandinWaitingList.mutate { value in
            value.append((requestedRange, []))
        }
        cancelPreload()
//        print("Added loading request range: \(requestedRange)")
        operationQueue.addOperation(operation)
        return true
    }
    
    func preload(url: URL) {
        guard !isPreloadingCancelled else { return }
        loadContentInfo(url: url) {[weak self] response, error in
            guard let response else {
                Logger.log("ResourceLoaderDelegateImpl: Preload Failed to get content info")
                return
            }
            self?.executePreloadBasedOn(response: response, remoteUrl: url)
        }
    }
    
    private func executePreloadBasedOn(response: URLResponse, remoteUrl: URL) {
        guard !isPreloadingCancelled else {
            return
        }
        let length = response.expectedContentLengthContentRange ?? response.expectedContentLength
        Logger.log("ResourceLoaderDelegateImpl: Preloading 10% of data: (0...\(length/10))")
        let loadingRequest = FakeLoadingRequest()
        let operation = DataRequestOperation(loadingRequest: loadingRequest, remoteUrl: remoteUrl, reqByteRanges: .init(0...(length/10)))
        operation.onFinishTask = {[weak self] _ in
            self?.preloadOperation  = nil
        }
        preloadOperation = operation
        operationQueue.addOperation(operation)
    }
    
    func cancelPreload() {
        
        isPreloadingCancelled = true
        preloadOperation?.cancel()
        preloadOperation = nil
        Logger.log("Preload operation cancelled \(isPreloadingCancelled)")
    }
    
    func loadContentInfo(url: URL, completion: @escaping (URLResponse?, Error?) -> Void) {
        DispatchQueue.global().async {
            let request: URLRequest = {
                let request = URLRequest(url: url)
                return request
            }()
            
            let task = URLSession.shared.downloadTask(with: request) {(tempUrl, response, error) in
                if let response = response, error == nil {
                    Logger.log("ResourceLoaderDelegateImpl: Preload Finished loading content info: \(response)")
                }
                else {
                    Logger.log("ResourceLoaderDelegateImpl: Preload Error fetching content info: \(error)")
                }
                completion(response, error)
            }
            task.resume()
        }
        
    }
}

class FakeLoadingRequest: LoadingRequestable {
    var isCancelled: Bool = false
    var isFinished: Bool = false
    
    func respond(withData data: Data) {
        Logger.log("FakeLoadingRequest: Received data of length: \(data.count)")
    }
    
    func finishLoading() {
        isFinished = true
    }
    
    func finishLoading(with error: (any Error)?) {
        isCancelled = true
        isFinished = true
    }
}


struct Logger {
    enum LogType: String {
        case verbose
        case info
        case warning
        case error
    }
    
    static func log(_ message: String, type: LogType = .verbose, fileName: String = #file, functionName: String = #function, line: Int = #line ) {
        print("=====================================================================================")
        print("\n\n\(type.rawValue.uppercased()): \(fileName) \(functionName) \(line)\n")
        print(message)
        print("======================================================================================")
        
    }
    
}



final class Atomic<A> {
    private let queue: DispatchQueue
    private var _value: A

    init(_ value: A) {
        self._value = value
        queue = DispatchQueue(label: "Atomic queue-\(UUID().uuidString)", attributes: .concurrent)
    }

    var value: A {
        get { return queue.sync { self._value } }
    }

    func mutate(_ transform: (inout A) -> ()) {
        queue.sync(flags: .barrier) { transform(&self._value) }
    }
}

