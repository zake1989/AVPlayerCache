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
    case error = 100
}

class BasicFileData {
    static let bufferSize: Int = 15*1024
    static let predownloadSize: Int = 200*1024
    static let dataHandleQueueLabel: String = "VideoDataHandleQueue"
    static let sessionOperationQueueName: String = "VideoDownloadSessionQueue"
    
    static let localURLPrefix: String = "CacheUrlPrefix"
    
    static let logLevel: LogLevel = .error

}

class ItemURL {
    var baseURLString: String = ""
    
    var url: URL? {
        return URL(string: baseURLString)
    }
    
}
