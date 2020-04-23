//
//  FileDownlaodingManager.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/10.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit

class FileDownlaodingManager {
    
    static let shared = FileDownlaodingManager()
    
    private let urlProcessQueue = DispatchQueue(label: "Video.URL.Process.Queue", qos: .utility ,attributes: .concurrent)
    
    private var urlList: [String] = []
    
    private init() {
        
    }
    
    func isDownloading(_ url: String) -> Bool {
        var containElement: Bool = false
        self.urlProcessQueue.sync {
            containElement = self.urlList.contains(url)
        }
        return containElement
    }

    func startDownloading(_ url: String) {
        urlProcessQueue.async(flags:.barrier) {
            self.urlList.append(url)
        }
    }
    
    func endDownloading(_ url: String) {
        urlProcessQueue.async(flags:.barrier) {
            self.urlList = self.urlList.filter({ (content) -> Bool in
                return content != url
            })
        }
    }
}
