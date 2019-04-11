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
    
    private var urlList: [String] = []
    
    private init() {
        
    }
    
    func isDownloading(_ url: String) -> Bool {
        return urlList.filter { (u) -> Bool in
            return u == url
        }.count != 0
    }

    func startDownloading(_ url: String) {
        urlList.append(url)
    }
    
    func endDownloading(_ url: String) {
        objc_sync_enter(urlList)
        guard urlList.count > 0, let index = urlList.enumerated().filter({ (content) -> Bool in
            return content.element == url
        }).first?.offset  else {
            return
        }
        urlList.remove(at: index)
        objc_sync_exit(urlList)
    }
}
