//
//  CacheFile.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/1.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit

enum CacheType: Int {
    case local   = 0
    case remote  = 1
}

struct SavedCacheData: Codable {
    var chunkList: [CacheMetaData] {
        didSet {
            fileInfo.downloadedContentLength = Int64(updateDownloadedSize())
        }
    }
    var fileInfo: CacheFileInfo
    var downloadSpeed: Int      // KB/s
    
    fileprivate func handleTwoRange(_ lr: Range<Int>, rr: Range<Int>) -> Range<Int>? {
        let minLower = min(lr.lowerBound, rr.lowerBound)
        let maxUpper = max(lr.upperBound, rr.upperBound)
        if lr.overlaps(rr) {
            return Range<Int>(uncheckedBounds: (minLower , maxUpper))
        }
        let clampedRange = lr.clamped(to: rr)
        if clampedRange.lowerBound < clampedRange.upperBound {
            return Range<Int>(uncheckedBounds: (minLower , maxUpper))
        } else if clampedRange.lowerBound == clampedRange.upperBound {
            if lr.lowerBound == rr.upperBound || lr.upperBound == rr.lowerBound {
                return Range<Int>(uncheckedBounds: (minLower , maxUpper))
            }
        }
        return nil
    }
    
    fileprivate func updateDownloadedSize() -> Int {
        let chunkSize: [Int] = chunkList.map { (chunk) -> Int in
            return chunk.range.upperBound-chunk.range.lowerBound
        }
        return chunkSize.reduce(0, +)
    }
    
    func inserRangeToList(_ chunkList: inout [CacheMetaData], rr: CacheMetaData) {
        for (index, lr) in chunkList.enumerated() {
            if let endRange = handleTwoRange(lr.range, rr: rr.range) {
                chunkList.remove(at: index)
                inserRangeToList(&chunkList, rr: CacheMetaData(type: rr.type, range: endRange))
                return
            }
        }
        chunkList.append(rr)
        chunkList.sort { (l, r) -> Bool in
            return l.range.lowerBound < r.range.lowerBound
        }
    }
    
    func readChunkList(_ chunkList: [CacheMetaData], range: Range<Int>) -> [CacheMetaData] {
        guard chunkList.count > 0 else {
            return [CacheMetaData(type: .remote, range: range)]
        }
        
        var localRange: [CacheMetaData] = []
        var remotRange: [CacheMetaData] = []
        for chunk in chunkList {
            if range.overlaps(chunk.range) {
                let maxLower = max(range.lowerBound, chunk.range.lowerBound)
                let minUpper = min(range.upperBound, chunk.range.upperBound)
                let dr = Range<Int>(uncheckedBounds: (maxLower , minUpper))
                localRange.append(CacheMetaData(type: .local, range: dr))
            }
        }
        
        guard localRange.count > 0 else {
            return [CacheMetaData(type: .remote, range: range)]
        }
        
        localRange.sort { (l, r) -> Bool in
            return l.range.lowerBound < r.range.lowerBound
        }
        
        for (index,dr) in localRange.enumerated() {
            if index == 0 {
                if dr.range.lowerBound > range.lowerBound {
                    let crr = Range<Int>(uncheckedBounds: (range.lowerBound, dr.range.lowerBound))
                    remotRange.append(CacheMetaData(type: .remote, range: crr))
                }
            }
            if index == localRange.count-1 {
                if dr.range.upperBound < range.upperBound {
                    let crr = Range<Int>(uncheckedBounds: (dr.range.upperBound , range.upperBound))
                    remotRange.append(CacheMetaData(type: .remote, range: crr))
                }
            } else if index > 0 {
                let lastR = localRange[index-1]
                let crr = Range<Int>(uncheckedBounds: (lastR.range.upperBound , dr.range.lowerBound))
                remotRange.append(CacheMetaData(type: .remote, range: crr))
            }
        }
        
        localRange.append(contentsOf: remotRange)
        localRange.sort { (l, r) -> Bool in
            return l.range.lowerBound < r.range.lowerBound
        }
        
        return localRange
    }
}

struct CacheMetaData: Equatable, Codable {
    var type: CacheType
    var range: Range<Int>

    init(type: CacheType, range: Range<Int>) {
        self.type = type
        self.range = range
    }
    
    enum CodingKeys: String, CodingKey {
        case type = "code"
        case range = "range"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = .local
        if let typeNumber = try container.decodeIfPresent(Int.self, forKey: CacheMetaData.CodingKeys.type) {
            type = CacheType(rawValue: typeNumber) ?? .local
        }
        range = try container.decodeIfPresent(Range<Int>.self, forKey: CacheMetaData.CodingKeys.range) ?? Range<Int>(uncheckedBounds: (0, 0))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: CacheMetaData.CodingKeys.type)
        try container.encode(range, forKey: CacheMetaData.CodingKeys.range)
    }
}

struct CacheFileInfo: Codable {
    var contentType: String = ""
    var byteRangeAccessSupported: Bool = false
    var contentLength: Int64 = 0
    var downloadedContentLength: Int64 = 0
    
    func isEmptyInfo() -> Bool {
        return contentType == "" || contentLength == 0
    }
}
