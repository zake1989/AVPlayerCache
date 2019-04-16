//
//  CachePlayerItem.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/12.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit
import AVFoundation

class CachePlayerItem {
    
    deinit {
        Cache_Print("deinit cache player item", level: LogLevel.dealloc)
    }
    
    private lazy var loader = CachedItemResourceLoader()
    
    init() {
        
    }
    
    func createPlayerItem(_ urlString: String) -> AVPlayerItem? {
        if CacheFileHandler.isFullyDownload(videoUrl: urlString) {
            return createLocalItem(urlString)
        } else {
            return createOnlineItem(urlString)
        }
    }
    
    func createPureOnlineItem(_ urlString: String) -> AVPlayerItem? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        return item
    }
    
    private func createLocalItem(_ urlString: String) -> AVPlayerItem {
        let filePath = CacheFilePathHelper.videoPath(from: urlString)
        let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
        return AVPlayerItem(asset: asset)
    }
    
    private func createOnlineItem(_ urlString: String) -> AVPlayerItem? {
        let localURL = ItemURL.createLocalURL(urlString)
        guard let url = URL(string: localURL) else {
            return nil
        }
        loader = CachedItemResourceLoader()
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.main)
        let item = AVPlayerItem(asset: asset)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
//        item.preferredPeakBitRate = 1000*10
        if #available(iOS 10.0, *) {
//            item.preferredForwardBufferDuration = 1
        }
        return item
    }
    
}
