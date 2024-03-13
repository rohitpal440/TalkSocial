//
//  RemoteDataRequestOperation.swift
//  VividPlayer
//
//  Created by Rohit Pal on 10/03/24.
//

import Foundation

class RemoteDataRequestOperation: AsyncOperation {
    private let url: URL
    private let requestedRange: ByteRange
    private var session: URLSession?
    private var task: URLSessionTask?
    private let responseSink: OperationResponseAdapter
    private var cursor: Int64
    private let localfileLoader: LocalFileLoader
    
    init(url: URL, requestedRange: ByteRange, responseSink: OperationResponseAdapter) {
        self.url = url
        self.cursor = requestedRange.lowerBound - 1 // points to last filled location
        self.requestedRange = requestedRange
        self.responseSink = responseSink
        self.localfileLoader = LocalFileLoaderPool().getFileLoader(remoteUrl: url)
        
    }
    
    private func createSession() -> URLSession {
        URLSession.init(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    
    override func main() {
        guard !isCancelled && !isFinished else {
            return
        }
        let request: URLRequest = .dataRequest(from: url, for: requestedRange)
        Logger.log("NEW REMOTE DATA OPERATION")
//        print("RemoteDataRequestOperation Executing remote data operation in range \(requestedRange)")
        self.session = URLSession.init(configuration: .default, delegate: self, delegateQueue: nil)
        task = self.session?.dataTask(with: request)
        task?.resume()
    }
    
    override func cancel() {
        super.cancel()
        task?.cancel()
        session?.invalidateAndCancel()
    }
    
    override func finish() {
//        print("Finished remote data operation \(requestedRange)")
        super.finish()
        session?.invalidateAndCancel()
    }
}

extension RemoteDataRequestOperation: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !self.isCancelled else {
            return
        }
        let lowerBound = cursor + 1
        let upperBound = lowerBound + Int64(data.count)
        cursor = upperBound - 1
        let byteRange: ByteRange = lowerBound..<upperBound
        localfileLoader.save(data: data, range: byteRange) {[weak self] error in
            guard self?.isCancelled == false && self?.isFinished == false else { return }
            if let error {
                Logger.log("RemoteDataRequestOperation: Failed to save data in range: \(byteRange), error: \(error)")
            } else {
                self?.responseSink.didReceive(data: data, inRange:  byteRange)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let nsError = error as? NSError {
            if nsError.code == NSURLErrorCancelled {
                Logger.log("RemoteDataRequestOperation: Cancelled fetch data from remote server error: \(nsError)")
                // do nothing
            } else {
                Logger.log("RemoteDataRequestOperation: Failed to fetch data from remote server error: \(nsError)")
                self.responseSink.finishLoading(with: nsError)
            }
//            print("Failed remote data operation \(requestedRange)")
        } else if let error {
//            print("Failed remote data operation \(requestedRange)")
            Logger.log("RemoteDataRequestOperation: Failed to fetch data from remote server error: \(error)")
            self.responseSink.finishLoading(with: error)
        } else {
            Logger.log("RemoteDataRequestOperation: finished data fetching in range: \(requestedRange), cursorPostion: \(cursor)")
            self.responseSink.finishLoading()
        }
        self.finish()
        self.task = nil
    }
}
