//
//  BasicFileData.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/1.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit

enum LogLevel: Int {
    case net = 0
    case file = 1
    case resource = 2
    case dealloc = 99
    case error = 100
}

class BasicFileData {
    static let bufferSize: Int = 40*1000
    static let predownloadSize: Int = 400*1000
    static let firstBufferMinSize: Int = 150*1000
    static let dataHandleQueueLabel: String = "VideoDataHandleQueue"
    static let sessionOperationQueueName: String = "VideoDownloadSessionQueue"
    static let maxCacheSize = 150
    
    static let tryForcePlayBufferCount = 6
    static let localURLPrefix: String = "CacheUrlPrefix"
    static let logLevel: LogLevel = .error
}

class ItemURL {
    deinit {
        Cache_Print("deinit item url", level: LogLevel.dealloc)
    }
    
    var baseURLString: String = ""
    
    var url: URL? {
        return URL(string: baseURLString)
    }
    
    static func createLocalURL(_ urlString: String) -> String {
        return urlString.replacingOccurrences(of: "http", with: BasicFileData.localURLPrefix)
    }
    
    static func onlineUrl(_ urlString: String) -> String {
        return urlString.replacingOccurrences(of: BasicFileData.localURLPrefix, with: "http")
    }
}

typealias DataRange = Range<Int64>

extension Range where Bound == Int64 {
    
    func rangeClamped(_ range: Range) -> Range? {
        if self.overlaps(range) {
            return self.clamped(to: range)
        }
        return nil
    }
    
    func rangeDecrease(_ range: Range) -> Range {
        guard let commonRange = self.rangeClamped(range) else {
            return self
        }
        if commonRange.upperBound == self.upperBound {
            return Range(uncheckedBounds: (lower: self.lowerBound, upper: commonRange.lowerBound))
        } else if commonRange.lowerBound == self.lowerBound {
            return Range(uncheckedBounds: (lower: commonRange.upperBound, upper: self.upperBound))
        }
        return self
    }
    
    func rangeAdd(_ range: Range) -> Range {
        guard self.overlaps(range) || upperBound == range.lowerBound || lowerBound == range.upperBound else {
            return self
        }
        let lower = Swift.min(range.lowerBound, self.lowerBound)
        let upper = Swift.max(range.upperBound, self.upperBound)
        return Range(uncheckedBounds: (lower: lower, upper: upper))
    }
    
    var dataRange: Range<Int> {
        return Range<Int>(uncheckedBounds: (lower: Int(lowerBound), upper: Int(upperBound)))
    }
    
    func rangeStartFrom(_ startLowerBound: Int) -> Range<Int> {
        return Range<Int>(uncheckedBounds: (lower: Int(lowerBound)-startLowerBound,
                                            upper: Int(upperBound)-startLowerBound))
    }
    
}
