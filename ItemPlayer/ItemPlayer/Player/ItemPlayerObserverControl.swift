//
//  ItemPlayerObserverControl.swift
//  ItemPlayer
//
//  Created by zeng on 2021/6/24.
//  Copyright © 2021 Stephen.Zeng. All rights reserved.
//

import UIKit
import AVFoundation


protocol ItemPlayerObserverCallBack: AnyObject {
    func itemPlayer(likelyToKeepUp new: Bool, old: Bool)
    func itemPlayer(steamAt time: TimeInterval, totalDuration: TimeInterval)
    func itemPlayer(totalDurationChanged duration: CMTime)
    func itemPlayer(presentationSizeChanged size: CGSize)
    
    func itemPlayerDidReachEnd()
    func itemPlayer(playToTime time: CMTime)
}

class ItemPlayerObserverControl {
    deinit {
        print("deinit item player observer control")
    }
    
    weak var callBack: ItemPlayerObserverCallBack?
    // item observer
    fileprivate var playbackLikelyToKeepUpObserver: NSKeyValueObservation?
    
    fileprivate var steamProgressObserver: NSKeyValueObservation?
    
    fileprivate var totalDurationObserver: NSKeyValueObservation?
    
    fileprivate var presentationSizeObserver: NSKeyValueObservation?

    fileprivate var timeControllObserver: NSKeyValueObservation?
    fileprivate var timeObserver: Any?
    
    var hasTimeObserver: Bool {
        return timeObserver != nil
    }
    
    init() {
        
    }
    
    func addItemObserver(playerItem: AVPlayerItem) {
        addPlaybackLikelyToKeepUpObserver(playerItem: playerItem)
        addSteamProgressObserver(playerItem: playerItem)
        addTotalDurationObserver(playerItem: playerItem)
        addPresentationSizeObserver(playerItem: playerItem)
    }
    
    func removeItemObserver() {
        removePlaybackLikelyToKeepUpObserver()
        removeSteamProgressObserver()
        removeTotalDurationObserver()
        removePresentationSizeObserver()
    }
    
    func addPlayerObserver(player: AVPlayer) {
        videoPlayToEndHandle(player: player)
        addVideoPlayTime(player: player)
    }
    
    func removePlayerObserver(player: AVPlayer) {
        removeVideoPlayToEndHandle(player: player)
        removeVideoPlayTime(player: player)
    }
    
    fileprivate func addPlaybackLikelyToKeepUpObserver(playerItem: AVPlayerItem) {
        playbackLikelyToKeepUpObserver = playerItem.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp,
                                                    options: [.new, .old],
                                                    changeHandler: { [weak self] (item, keepUp) in
                                                        guard let strongSelf = self else {
                                                            return
                                                        }
                                                        let new = keepUp.newValue ?? false
                                                        let old = keepUp.oldValue ?? false
                                                        strongSelf.callBack?.itemPlayer(likelyToKeepUp: new, old: old)
        })
    }
    
    fileprivate func removePlaybackLikelyToKeepUpObserver() {
        playbackLikelyToKeepUpObserver?.invalidate()
        playbackLikelyToKeepUpObserver = nil
    }
    
    fileprivate func addSteamProgressObserver(playerItem: AVPlayerItem) {
        steamProgressObserver = playerItem.observe(\AVPlayerItem.loadedTimeRanges,
                                                   options: [.new],
                                                   changeHandler: { [weak self] (item, value) in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    let itemDuration = item.duration.seconds
                                                    let steamingTime = strongSelf.readOutSteamingTime(loadedTimeRanges: value.newValue)
                                                    strongSelf.callBack?.itemPlayer(steamAt: steamingTime,
                                                                                    totalDuration: itemDuration)
        })
    }
    
    fileprivate func readOutSteamingTime(loadedTimeRanges: [NSValue]?) -> TimeInterval {
        if let rangeValue = loadedTimeRanges?.first {
            let timeRange = rangeValue.timeRangeValue
            return timeRange.start.seconds+timeRange.duration.seconds
        }
        return 0
    }
    
    fileprivate func removeSteamProgressObserver() {
        steamProgressObserver?.invalidate()
        steamProgressObserver = nil
    }
    
    fileprivate func addTotalDurationObserver(playerItem: AVPlayerItem) {
        totalDurationObserver = playerItem.observe(\AVPlayerItem.duration,
                                                   options: [.new],
                                                   changeHandler: { [weak self] item, value in
                                                    guard let strongSelf = self,
                                                          let duration = value.newValue else {
                                                        return
                                                    }
                                                    strongSelf.callBack?.itemPlayer(totalDurationChanged: duration)
        })
    }
    
    fileprivate func removeTotalDurationObserver() {
        totalDurationObserver?.invalidate()
        totalDurationObserver = nil
    }
    
    fileprivate func addPresentationSizeObserver(playerItem: AVPlayerItem) {
        presentationSizeObserver = playerItem.observe(\AVPlayerItem.presentationSize,
                                                      options: [.new],
                                                      changeHandler: { [weak self] item, value in
                                                        guard let strongSelf = self,
                                                              let size = value.newValue else {
                                                            return
                                                        }
                                                        strongSelf.callBack?.itemPlayer(presentationSizeChanged: size)
        })
    }
    
    fileprivate func removePresentationSizeObserver() {
        presentationSizeObserver?.invalidate()
        presentationSizeObserver = nil
    }
    
    fileprivate func addTimeControllObserver(player: AVPlayer) {
        guard #available(iOS 10.0, *) else {
            return
        }
        timeControllObserver = player.observe(\AVPlayer.timeControlStatus,
                                              options: [.old, .new],
                                              changeHandler: { (player, value) in
                                                
        })
    }
    
    fileprivate func removeTimeControllObserver() {
        timeControllObserver?.invalidate()
        timeControllObserver = nil
    }
    
    fileprivate func videoPlayToEndHandle(player: AVPlayer) {
        guard let playerItem = player.currentItem else { return }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReachEnd),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
    }
    
    @objc fileprivate func didReachEnd() {
        callBack?.itemPlayerDidReachEnd()
    }
    
    fileprivate func removeVideoPlayToEndHandle(player: AVPlayer) {
        guard let playerItem = player.currentItem else { return }
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                  object: playerItem)
    }
    
    fileprivate func addVideoPlayTime(player: AVPlayer) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval,
                                                      queue: DispatchQueue.main,
                                                      using: { [weak self] (time) in
                                                        let playTime = time.seconds
                                                        guard let strongSelf = self, playTime.isNormal else {
                                                            return
                                                        }
                                                        strongSelf.callBack?.itemPlayer(playToTime: time)
        })
    }
    
    fileprivate func removeVideoPlayTime(player: AVPlayer) {
        guard let observer = timeObserver else {
            return
        }
        player.removeTimeObserver(observer)
        timeObserver = nil
    }
}
