//
//  MetaFileData.swift
//  VividPlayer
//
//  Created by Rohit Pal on 09/03/24.
//

import Foundation

struct MetaFileData: Codable {
    let url: URL
    var downloadedRanges: [ByteRange]

    func addedWith(byteRanges addedRanges: [ByteRange]) -> MetaFileData {
        let newRanges = downloadedRanges + addedRanges
        let newDownloadedRange =  combine(newRanges)
        return .init(url: self.url, downloadedRanges: newDownloadedRange)
    }
}
