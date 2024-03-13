//
//  ByteRangeOperationFactory.swift
//  VividPlayer
//
//  Created by Rohit Pal on 10/03/24.
//

import Foundation


private enum OperationType {
    case remote
    case local
}


class ByteRangeOperationFactory {
    
    class func getOperations(requestedRange: ByteRange, remoteUrl: URL, downloadedRanges: [ByteRange], respSink: OperationResponseAdapter) -> [Operation] {
        let defragmentedOpsData = defragmentedOperationData(requestedRange: requestedRange, remoteUrl: remoteUrl, downloadedRanges: downloadedRanges)
        return createOperation(forInfo: defragmentedOpsData, remoteUrl: remoteUrl, respSink: respSink)
    }

    private class func createOperation(forInfo info: [(range: ByteRange, type: OperationType)], remoteUrl: URL, respSink: OperationResponseAdapter) -> [Operation] {
        var operations: [Operation] = []
        info.forEach { opData in
            switch opData.type {
            case .local:
                let op = LocalDataRequestOperation(url: remoteUrl, requestedRange: opData.range, responseSink: respSink)
                operations.append(op)
            case .remote:
                let op = RemoteDataRequestOperation(url: remoteUrl, requestedRange: opData.range, responseSink: respSink)
                operations.append(op)
            }
        }
        return operations
    }
    
    private class func defragmentedOperationData(requestedRange: ByteRange, remoteUrl: URL, downloadedRanges: [ByteRange]) -> [(range: ByteRange, type: OperationType)] {
        var subrequests:[(range: ByteRange, type: OperationType)] = []
        let intersectingRanges = downloadedRanges
            .filter{$0.intersects(requestedRange)}
            .sorted{$0.lowerBound < $1.lowerBound}
        guard !intersectingRanges.isEmpty else {
            subrequests.append((requestedRange, .remote))
            return subrequests
        }
        
        var cursor = requestedRange.lowerBound
        var nextRangeIndex = 0
        while cursor < requestedRange.upperBound && nextRangeIndex < intersectingRanges.count {
            let nextRange = intersectingRanges[nextRangeIndex]
            let position = nextRange.relativePosition(of: cursor)
            switch position {
            case .before:
                let lowerBound = cursor
                let upperBound = min(nextRange.lowerBound, requestedRange.upperBound)
                let range = lowerBound..<upperBound
                subrequests.append((range, .remote))
                cursor = upperBound
            case .inside:
                let lowerBound = cursor
                let upperBound = min(nextRange.upperBound, requestedRange.upperBound)
                let range: ByteRange = lowerBound..<upperBound//.init((lowerBound...upperBound))
            
                subrequests.append((range, .local))
                cursor = upperBound
                nextRangeIndex += 1
            case .after:
                fatalError("An intersecting range's upper bound should not be lower than the requested range's lower bound. This is a programmer error. In production this will fall back to a single network request for the entire requested range.")
            }
        }
        if cursor < requestedRange.upperBound {
            let lowerBound = cursor
            let upperBound = requestedRange.upperBound
            let range = (lowerBound..<upperBound)
            subrequests.append((range, .remote))
        }
        return subrequests
    }
}
