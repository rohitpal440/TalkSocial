//
//  ContentRequestOperation.swift
//  VividPlayer
//
//  Created by Rohit Pal on 10/03/24.
//

import Foundation
import AVFoundation

extension URL {
    
    // Returns true if the receiver's path extension is equal to `pathExt`.
    func hasPathExtension(_ pathExt: String) -> Bool {
        guard let comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else {return false}
        return (comps.path as NSString).pathExtension == pathExt
    }
    
    // Adds the scheme prefix to a copy of the receiver.
    func convertToRedirectURL(prefix: String) -> URL? {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else {return nil}
        guard let scheme = comps.scheme else {return nil}
        comps.scheme = prefix + scheme
        return comps.url
    }
    
    // Removes the scheme prefix from a copy of the receiver.
    func convertFromRedirectURL(prefix: String) -> URL? {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else {return nil}
        guard let scheme = comps.scheme else {return nil}
        comps.scheme = scheme.replacingOccurrences(of: prefix, with: "")
        return comps.url
    }
    
    static let vividCustomScheme: String = "vvd"

}

extension URLResponse {
    
    var isByteRangeEnabled: Bool {
        return responseRange != nil
    }
    
    var responseRange: ByteRange? {
        guard let response = self as? HTTPURLResponse else {return nil}
        if let fullString = response.allHeaderFields["Content-Range"] as? String,
            let firstPart = fullString.split(separator: "/").map({String($0)}).first
        {
            if let prefixRange = firstPart.range(of: "bytes ") {
                let rangeString = firstPart.substring(from: prefixRange.upperBound)
                let comps = rangeString.components(separatedBy: "-")
                let ints = comps.flatMap{Int64($0)}
                if ints.count == 2 {
                    return (ints[0]..<(ints[1]+1))
                }
            }
        }
        return nil
    }
    
    var expectedContentLengthContentRange: Int64? {
        guard let response = self as? HTTPURLResponse else {return nil}
        if let rangeString = response.allHeaderFields["content-range"] as? String,
            let bytesString = rangeString.split(separator: "/").map({String($0)}).last,
            let bytes = Int64(bytesString)
        {
            return bytes
        } else {
            return nil
        }
    }
    
    var etag: String? {
        guard let response = self as? HTTPURLResponse else {return nil}
        return response.allHeaderFields["Etag"] as? String
    }
    
//    func lastModified(using formatter: RFC822Formatter) -> Date? {
//        guard let response = self as? HTTPURLResponse else {return nil}
//        if let string = response.allHeaderFields["Last-Modified"] as? String {
//            return formatter.date(from: string)
//        } else {
//            return nil
//        }
//    }
    
}


extension AVAssetResourceLoadingContentInformationRequest {
    
    func update(with response: URLResponse) {
        
        if let response = response as? HTTPURLResponse {
            if let type = response.allHeaderFields["Content-Type"] as? String {
                contentType = type
            }

            if let length = response.expectedContentLengthContentRange {
                contentLength = length
            } else if response.expectedContentLength > 0{
                contentLength = response.expectedContentLength
            }
            
            if let acceptRanges = response.allHeaderFields["Accept-Ranges"] as? String,
                acceptRanges == "bytes"
            {
                isByteRangeAccessSupported = true
            } else {
                isByteRangeAccessSupported = false
            }
        }
        else {
            assertionFailure("Invalid URL Response.")
        }
    }
    
}

class ContentRequestOperation: AsyncOperation {
    
    private let loadingRequest: AVAssetResourceLoadingRequest
    
    var onFinished: (() -> Void)?
    
    init(loadingRequest: AVAssetResourceLoadingRequest) {
        self.loadingRequest = loadingRequest
    }
    
    override func main() {
        handleContentInfoRequest(for: loadingRequest)
    }
    
    fileprivate func handleContentInfoRequest(for loadingRequest: AVAssetResourceLoadingRequest)  {
        guard let infoRequest = loadingRequest.contentInformationRequest else { return }
        guard let redirectURL = loadingRequest.request.url else { return }
        guard let originalURL = redirectURL.convertFromRedirectURL(prefix: URL.vividCustomScheme) else { return }
        
        let request: URLRequest = {
            var request = URLRequest(url: originalURL)
            if let dataRequest = loadingRequest.dataRequest {
                request.setByteRangeHeader(for: dataRequest.byteRange)
            }
            return request
        }()
        
        let task = URLSession.shared.downloadTask(with: request) {[weak self] (tempUrl, response, error) in
            defer { self?.finish() }
            guard !loadingRequest.isCancelled else {
                return
            }
            if let response = response, error == nil {
                infoRequest.update(with: response)
                
                loadingRequest.finishLoading()
                Logger.log("ContentRequestOperation Finished loading content info: \(infoRequest)")
            }
            else {
                self?.loadingRequest.finishLoading(with: error)
            }
        }
        task.resume()
    }
}




