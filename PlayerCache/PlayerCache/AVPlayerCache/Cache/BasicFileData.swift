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
    static let bufferSize: Int = 50*1000
    static let predownloadSize: Int = 500*1000
    static let dataHandleQueueLabel: String = "VideoDataHandleQueue"
    static let sessionOperationQueueName: String = "VideoDownloadSessionQueue"
    
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

