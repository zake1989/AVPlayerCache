//
//  CachePlayerItem.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/12.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit
import AVFoundation

public class CachePlayerItem {
    
    public weak var delegate: CachedItemHandleDelegate?
    
    deinit {
        Cache_Print("deinit cache player item", level: LogLevel.dealloc)
    }
    
    private lazy var loader = CachedItemResourceLoader(true)
    
    public init() {
        
    }
    
    public func createPlayerItem(_ urlString: String) -> (AVPlayerItem?, Bool) {
        if CacheFileHandler.isFullyDownload(videoUrl: urlString) {
            return (createLocalItem(urlString), false)
        } else {
            return (createOnlineItem(urlString), false)
        }
    }
    
    public func createPureOnlineItem(_ urlString: String) -> AVPlayerItem? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        return item
    }
    
    public func isLoading(_ urlString: String) -> Bool {
        return true
    }
    
    private func createLocalItem(_ urlString: String) -> AVPlayerItem {
        let filePath = CacheFilePathHelper.videoPath(from: urlString)
        let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
        
        let keys = ["duration" , "tracks"]
        asset.loadValuesAsynchronously(forKeys: keys) {
            
        }
        return AVPlayerItem(asset: asset)
    }
    
    private func createOnlineItem(_ urlString: String) -> AVPlayerItem? {
        let localURL = ItemURL.createLocalURL(urlString)
        guard let url = URL(string: localURL) else {
            return nil
        }
        loader.delegate = nil
        loader = CachedItemResourceLoader(true)
        loader.delegate = self
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.main)
        let item = AVPlayerItem(asset: asset)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        item.preferredPeakBitRate = 0
        if #available(iOS 10.0, *) {
            item.preferredForwardBufferDuration = 1
        }
        return item
    }
    
}

extension CachePlayerItem: CachedItemHandleDelegate {
    public func dataHandleStarted() {
        delegate?.dataHandleStarted()
    }
    
    public func needRecoverFromError() {
        delegate?.needRecoverFromError()
    }
    
    public func noMoreRequestCheck() {
        delegate?.noMoreRequestCheck()
    }
    
    public func canTryForcePlay() {
        delegate?.canTryForcePlay()
    }
    
    public func finishDownloadFile(duration: TimeInterval, dataSize: Int64, urlString: String?) {
        delegate?.finishDownloadFile(duration: duration, dataSize: dataSize, urlString: urlString)
    }
}
