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
    
    static func createPlayerItem(_ urlString: String) -> AVPlayerItem? {
        if CacheFileHandler.isFullyDownload(videoUrl: urlString) {
            return createLocalItem(urlString)
        } else {
            return createOnlineItem(urlString)
        }
    }
    
    private static func createLocalItem(_ urlString: String) -> AVPlayerItem {
        let filePath = CacheFilePathHelper.videoPath(from: urlString)
        let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
        return AVPlayerItem(asset: asset)
    }
    
    private static func createOnlineItem(_ urlString: String) -> AVPlayerItem? {
        let localURL = ItemURL.createLocalURL(urlString)
        guard let url = URL(string: localURL) else {
            return nil
        }
        let asset = AVURLAsset(url: url)
        let loader = CachedItemResourceLoader()
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.main)
        let item = AVPlayerItem(asset: asset)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        return item
    }
    
}
