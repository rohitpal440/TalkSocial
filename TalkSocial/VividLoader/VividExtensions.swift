//
//  Extensions.swift
//  VividPlayer
//
//  Created by Rohit Pal on 10/03/24.
//

import Foundation

extension URLRequest {
    /// Convenience method
    var byteRange: ByteRange? {
        if let value = allHTTPHeaderFields?["Range"] {
            if let prefixRange = value.range(of: "bytes=") {
                let rangeString = value.substring(from: prefixRange.upperBound)
                let comps = rangeString.components(separatedBy: "-")
                let ints = comps.flatMap{Int64($0)}
                if ints.count == 2 {
                    return (ints[0]..<(ints[1]+1))
                }
            }
        }
        return nil
    }
    
    /// Convenience method
    mutating func setByteRangeHeader(for range: ByteRange) {
        let rangeHeader = "bytes=\(range.lowerBound)-\(range.lastValidIndex)"
        setValue(rangeHeader, forHTTPHeaderField: "Range")
    }
    
    /// Convenience method for creating a byte range network request.
    static func dataRequest(from url: URL, for range: ByteRange) -> URLRequest {
        var request = URLRequest(url: url)
        request.setByteRangeHeader(for: range)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }
}


extension Data {
    func byteRangeResponseSubdata(in range: ByteRange) -> Data? {
        if Int64(count) >= range.length {
            return subdata(in: (0..<Int(range.length)))
        } else {
            return nil
        }
    }
    
}

protocol Summable: Comparable {
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    func decremented() -> Self
    func toInt() -> Int
}

extension Int64: Summable {
    func decremented() -> Int64 {
        return self - 1
    }
    func toInt() -> Int {
        return Int(self)
    }
}

public typealias ByteRange = Range<Int64>

enum ByteRangeIndexPosition {
    case before
    case inside
    case after
}

extension Range where Bound: Summable {
    
    var length: Bound {
        return upperBound - lowerBound
    }
    
    var lastValidIndex: Bound {
        return upperBound.decremented()
    }
    
    var subdataRange: Range<Int> {
        return lowerBound.toInt()..<(upperBound.toInt())
    }
    
    func leadingIntersection(in otherRange: Range) -> Range? {
        if lowerBound <= otherRange.lowerBound && lastValidIndex >= otherRange.lowerBound {
            if lastValidIndex > otherRange.lastValidIndex {
                return otherRange
            } else {
                let lowerBound = otherRange.lowerBound
                let upperBound = otherRange.lowerBound + length - otherRange.lowerBound
                return (lowerBound..<upperBound)
            }
        } else {
            return nil
        }
    }
    
    func trailingRange(in otherRange: Range) -> Range? {
        if let leading = leadingIntersection(in: otherRange), !fullySatisfies(otherRange) {
            return ((otherRange.lowerBound + leading.length)..<otherRange.upperBound)
        } else {
            return nil
        }
    }
    
    func fullySatisfies(_ requestedRange: Range) -> Bool {
        if let intersection = leadingIntersection(in: requestedRange) {
            return intersection == requestedRange
        } else {
            return false
        }
    }
    
    func intersects(_ otherRange: Range) -> Bool {
        return otherRange.lowerBound < upperBound && lowerBound < otherRange.upperBound
    }
    
    func isContiguousWith(_ otherRange: Range) -> Bool {
        if otherRange.upperBound == lowerBound {
            return true
        } else if upperBound == otherRange.lowerBound {
            return true
        } else {
            return false
        }
    }
    
    func relativePosition(of index: Bound) -> ByteRangeIndexPosition {
        if index < lowerBound {
            return .before
        } else if index >= upperBound {
            return .after
        } else {
            return .inside
        }
    }
    
    func isInsideOrEqual(_ otherRange: Range) -> Bool {
        lowerBound >= otherRange.lowerBound && upperBound <= otherRange.upperBound
    }
    
}

func combine(_ ranges: [ByteRange]) -> [ByteRange] {
    var combinedRanges = [ByteRange]()
    let uncheckedRanges = ranges.sorted{$0.length > $1.length}
    for uncheckedRange in uncheckedRanges {
        let intersectingRanges = combinedRanges.filter{
            $0.intersects(uncheckedRange) || $0.isContiguousWith(uncheckedRange)
        }
        if intersectingRanges.isEmpty {
            combinedRanges.append(uncheckedRange)
        } else {
            for range in intersectingRanges {
                if let index = combinedRanges.firstIndex(of: range) {
                    combinedRanges.remove(at: index)
                }
            }
            let combinedRange = intersectingRanges.reduce(uncheckedRange, +)
            combinedRanges.append(combinedRange)
        }
    }
    return combinedRanges.sorted{$0.lowerBound < $1.lowerBound}
}

private func +(lhs: ByteRange, rhs: ByteRange) -> ByteRange {
    let lowerBound = min(lhs.lowerBound, rhs.lowerBound)
    let upperBound = max(lhs.upperBound, rhs.upperBound)
    return (lowerBound..<upperBound)
}

