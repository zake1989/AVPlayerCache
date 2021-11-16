//
//  ItemPlayer.swift
//  Vskit
//
//  Created by Stephen zake on 2019/1/19.
//  Copyright © 2019 Transsnet. All rights reserved.
//

import UIKit
import AVFoundation

public enum ItemPlayerStatus {
    case preparing
    case playing
    case seeking
    case paused
    case closed
}

public protocol ItemPlayerDelegate: AnyObject {
    func needRestartLoading()
    func itemSizeDecoded(_ videoSize: CGSize, playerLayer: AVPlayerLayer)
    func itemTotalDuration(_ duration: TimeInterval)
    func playAtTime(_ currentTime: TimeInterval, itemDuration: TimeInterval, progress: Double)
    func steamingAtTime(_ steamingDuration: TimeInterval, itemDuration: TimeInterval)
    func playStateChange(_ oldStatus: ItemPlayerStatus, playerStatus: ItemPlayerStatus)
    func didReachEnd()
}

public class ItemPlayer {
    
    static let needLog: Bool = false
    
    public var itemDuration: CMTime {
        guard let playerItem = player.currentItem, !playerItem.duration.isIndefinite else {
            return CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(30.0))
        }
        return playerItem.duration
    }
    
    public var currentTime: CMTime {
        guard let playerItem = player.currentItem, !playerItem.duration.isIndefinite else {
            return CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(30.0))
        }
        return playerItem.currentTime()
    }
    
    public var loopPlay: Bool = false
    
    public var forcePlayModel: Bool = false
    
    public var progress: Double {
        let duration = CMTimeGetSeconds(itemDuration)
        if duration == 0 || duration.isNaN {
            return 0.0
        }
        return CMTimeGetSeconds(currentTime)/duration
    }
    
    public var muted: Bool = false {
        didSet {
            player.isMuted = muted
        }
    }
    
    private var playerLayer: AVPlayerLayer = AVPlayerLayer()
    
    public weak var itemPlayerDelegate: ItemPlayerDelegate?
    
    public var expectedDuration: TimeInterval = 0.0
    
    public var itemAsset: AVAsset
    
    public var playStatus: ItemPlayerStatus = .preparing {
        didSet {
            logStatus()
            if oldValue != playStatus {
                itemPlayerDelegate?.playStateChange(oldValue ,playerStatus: playStatus)
            }
        }
    }
    
    fileprivate var observerControl: ItemPlayerObserverControl = ItemPlayerObserverControl()
    
    fileprivate var didOutputDisplaylayer: Bool = false
    
    fileprivate var failedDuration: TimeInterval = -1
    
    fileprivate var needForcePlay: Bool = false
    
    fileprivate var seekProgressAfterPrepare: Double = 0.0
    
    fileprivate var player: AVPlayer = AVPlayer()
    
    fileprivate var bufferDuration: TimeInterval = 1
    
    fileprivate var atEnd: Bool = false
    
    fileprivate var oldStatus: ItemPlayerStatus = .closed
    
    fileprivate var rate: Float = 1.0
    
    fileprivate var lastTimeControllNumber: Int = -1
    
    fileprivate var playOnNilKeepUpReason: Bool = true
    
    fileprivate var oldPlayTime: CMTime = CMTime.zero
    
    fileprivate var duringErrorHandle: Bool = false
    
    deinit {
//        Player_Print("deinit video player")
        observerControl.removeItemObserver()
        observerControl.removePlayerObserver(player: player)
        NotificationCenter.default.removeObserver(self)
    }
    
    public init(item: AVPlayerItem,
         needForceAudio: Bool = false,
         delegate: ItemPlayerDelegate? = nil) {
        itemPlayerDelegate = delegate
        itemAsset = item.asset
        observerControl.callBack = self
        readyPlayer(item: item, recreate: true)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.audioRouteChanged(note:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }
    
    public init(asset: AVAsset,
         needForceAudio: Bool = false,
         delegate: ItemPlayerDelegate? = nil) {
        itemPlayerDelegate = delegate
        itemAsset = asset
        observerControl.callBack = self
        readyPlayerItem()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.audioRouteChanged(note:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }
    
    public func clearItemObserver() {
        observerControl.removeItemObserver()
    }
    
    public func changeItem(_ playerItem: AVPlayerItem, needRecreatePlayer: Bool = false) {
        player.pause()
        playStatus = .preparing
        oldPlayTime = .zero
        lastTimeControllNumber = -1
        playOnNilKeepUpReason = true
        
        self.itemAsset = playerItem.asset
        readyPlayer(item: playerItem, recreate: needRecreatePlayer)
    }
    
    public func changeItemURL(_ itemAsset: AVAsset, needCallPlay: Bool = true) {
        player.pause()
        playStatus = .preparing
        oldPlayTime = .zero
        lastTimeControllNumber = -1
        playOnNilKeepUpReason = true
        
        self.itemAsset.cancelLoading()
        self.itemAsset = itemAsset
        
        readyPlayerItem()
        needForcePlay = needCallPlay
    }
    
    @objc fileprivate func audioRouteChanged(note: Notification) {
        if let userInfo = note.userInfo {
            if let reason = userInfo[AVAudioSessionRouteChangeReasonKey] as? Int {
                if reason == Int(AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue) {
                    pause()
                }
            }
        }
    }
    
    fileprivate func outPutDuration(_ duration: TimeInterval) {
        guard !duration.isNaN, duration > 0 else {
            return
        }
        itemPlayerDelegate?.itemTotalDuration(duration)
    }
    
    fileprivate func logStatus() {
        switch playStatus {
        case .closed:
            Player_Print(" call back -> status change: closed")
        case .playing:
            Player_Print(" call back -> status change: playing")
        case .paused:
            Player_Print(" call back -> status change: paused")
        case .preparing:
            Player_Print(" call back -> status change: preparing")
        case .seeking:
            Player_Print(" call back -> status change: seeking")
        }
    }
}

// MARK: - 基础播放功能
public extension ItemPlayer {
    func play() {
        if forcePlayModel {
            needForcePlay = true
        }
        if loopPlay && atEnd {
            playFromBegin()
            return
        }
        guard (playStatus != .playing && playStatus != .preparing) || player.rate == 0.0 else {
            return
        }
        Player_Print(" call back -> player called play ==> called play")
        checkPlayerErrorPlay()
    }
    
    func pause() {
        if forcePlayModel {
            needForcePlay = false
        }
        player.rate = 0
        player.pause()
        guard playStatus != .paused  && playStatus != .preparing  else {
            if playStatus == .preparing {
                oldStatus = .paused
            }
            return
        }
        playStatus = .paused
    }
    
    func playFromBegin(_ forcePlay: Bool = false) {
        atEnd = false
        player.pause()
        player.seek(to: CMTime.zero) { [weak self] (success) in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.playStatus == .playing || forcePlay {
                Player_Print(" call back -> player called play ==> from begin")
                strongSelf.checkPlayerErrorPlay()
            }
        }
    }
    
    func fastSeek(_ progress: Double) {
        let targetTime = progress*itemDuration.seconds
        atEnd = progress == 1.0
        player.seek(to: CMTimeMakeWithSeconds(targetTime, preferredTimescale: 1000),
                    toleranceBefore: CMTime.zero,
                    toleranceAfter: CMTime.zero)
    }
    
    func seek(_ progress: Double, complete: (() -> Void)? = nil) {
        
        if playStatus == .preparing {
            seekProgressAfterPrepare = progress
            return
        }
        
//        Player_Print("status change: +++++++++++++++++++++++++++++++++++ ")
        let targetTime = progress*itemDuration.seconds
        let seekingOldStatus = playStatus
        oldStatus = playStatus
//        Player_Print("status change: change on seeking \(seekingOldStatus)")
        player.pause()
        playStatus = .seeking
        player.seek(to: CMTimeMakeWithSeconds(targetTime, preferredTimescale: 1000),
                    toleranceBefore: CMTime.zero,
                    toleranceAfter: CMTime.zero) { [weak self] (success) in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.atEnd = progress == 1.0
                        if let c = complete {
                            strongSelf.playStatus = .paused
                            c()
                            return
                        }
                        if seekingOldStatus == .playing {
                            strongSelf.playStatus = .paused
                            strongSelf.play()
                        } else {
                            if ((strongSelf.player.rate == 0) || (strongSelf.player.error != nil)) {
                                strongSelf.playStatus = .paused
//                                Player_Print("status change: change after seeking pause")
                            }
                        }
        }
    }
    
    func setPlaySpeed(_ speed: Double) {
        rate = Float(speed)
    }
    
    func forceReloadLayer(_ size: CGSize) {
//        guard !didOutputDisplaylayer else {
//            return
//        }
//        guard !size.equalTo(CGSize.zero) else {
//            return
//        }
//        didOutputDisplaylayer = true
//        itemPlayerDelegate?.itemSizeDecoded(size, playerLayer: playerLayer)
    }
    
    func stopPlayer() {
        observerControl.removeItemObserver()
        observerControl.removePlayerObserver(player: player)
        lastTimeControllNumber = -1
        playOnNilKeepUpReason = true
        player.pause()
        player.replaceCurrentItem(with: nil)
        oldStatus = playStatus
        playStatus = .closed
    }
}

// MARK: - 播放器事件处理
extension ItemPlayer {
    fileprivate func checkPlayerErrorPlay() {
        guard checkPlayerNoError() else {
            player.pause()
            return
        }
        Player_Print(" call back -> player called play")
        player.play()
        if rate != 1.0 {
            player.rate = rate
        }
    }
    
    fileprivate func checkDecodeDuration() -> Bool {
        if expectedDuration == -2 {
            return true
        }
        var timeDone: Bool = false
        defer {
            if !timeDone {
                player.pause()
            }
        }
        guard observerControl.hasTimeObserver else {
            Player_Print(" call back -> time check fail")
            return timeDone
        }
        let duration = itemDuration.seconds
        if duration == Double.nan || duration <= 0 {
            Player_Print(" call back -> time check fail")
            return timeDone
        }
        if expectedDuration <= 0 ||
            (expectedDuration > 0 && duration > max(expectedDuration-2, 4)) ||
            (failedDuration == duration) {
            Player_Print(" call back -> time check success")
            timeDone = true
        } else {
            if duration > 3 {
                failedDuration = duration
            }
            observerControl.removePlayerObserver(player: player)
//            Player_Print("player error: duration wrong \(String(describing: player.error))")
            itemPlayerDelegate?.needRestartLoading()
        }
        return timeDone
    }
    
    fileprivate func seekOnPrepare() {
        guard seekProgressAfterPrepare > 0 && !itemDuration.seconds.isNaN else {
            if seekProgressAfterPrepare > 0 {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: {
                    self.seekOnPrepare()
                })
            }
            return
        }
//        Player_Print("status change: seek after perparing")
        fastSeek(seekProgressAfterPrepare)
        seekProgressAfterPrepare = 0
        if oldStatus == .playing || needForcePlay {
            Player_Print(" call back -> player called play ==> when seek finish")
            checkPlayerErrorPlay()
        } else {
            player.pause()
            playStatus = .paused
        }
    }
    
    fileprivate func actionWhenReadyToPlay() {
        // 可以开始播放的状态 如果开启强制播放 就强制播放 如果没有开启强制播放 就保持暂停
        if oldStatus == .playing || needForcePlay {
//            Player_Print("status change: force play")
            Player_Print(" call back -> player called play ==> when ready to play")
            checkPlayerErrorPlay()
        } else {
            player.pause()
            playStatus = .paused
//            Player_Print("status change: change after preparing pause")
        }
//        Player_Print("status change: change after preparing get old \(oldStatus)")
    }
    
    fileprivate func actionWhenPerparing() {
        if playStatus != .playing {
            oldStatus = .paused
        } else {
            oldStatus = .playing
        }
//        Player_Print("status change: change in preparing get old \(oldStatus)")
        playStatus = .preparing
    }
    
    func actionWhenBufferingRateReason() {
        guard needForcePlay, checkPlayerNoError() else {
            return
        }
//        Player_Print("call back -> player called force play")
        // 强制播放的时候不直接改变播放状态
        if #available(iOS 10.0, *) {
            player.playImmediately(atRate: rate)
        } else {
            player.play()
        }
    }
    
    fileprivate func checkPlayerNoError() -> Bool {
        guard player.error == nil else {
            if !duringErrorHandle {
                duringErrorHandle = true
                Player_Print("player error: \(String(describing: player.error))")
                itemPlayerDelegate?.needRestartLoading()
            }
            return false
        }
        return true
    }
    
    fileprivate func setGravity() {
        guard !didOutputDisplaylayer else {
            return
        }
        guard let size = player.currentItem?.presentationSize, !size.equalTo(CGSize.zero) else {
            return
        }
        didOutputDisplaylayer = true
        itemPlayerDelegate?.itemSizeDecoded(size, playerLayer: playerLayer)
    }
    
    fileprivate func outputSteamingProgress() -> Double {
        guard let playerItem = player.currentItem else {
            return 0
        }
        let steaming = playerItem.loadedTimeRanges
        if let rangeValue = steaming.first {
            let timeRange = rangeValue.timeRangeValue
            return timeRange.start.seconds+timeRange.duration.seconds
        }
        return 0
    }
    
    @objc fileprivate func didReachEnd() {
//        Player_Print("play at time: player reach end")
        itemPlayerDelegate?.didReachEnd()
        guard loopPlay else {
            var duration = itemDuration.seconds
            if !duration.isNormal {
                duration = 0
            }
            itemPlayerDelegate?.playAtTime(duration,
                                           itemDuration: duration,
                                           progress: 1.0)
            atEnd = true
            playStatus = .paused
            return
        }
        playFromBegin()
    }
}

// MARK: - 播放器关键状态监听控制回调
extension ItemPlayer: ItemPlayerObserverCallBack {
    func itemPlayer(likelyToKeepUp new: Bool, old: Bool) {
//        Player_Print(" call back -> likely to keep up -> \(new) -- \(old)")
        let isPlaybackLikelyToKeepUp = new
        if isPlaybackLikelyToKeepUp {
            guard checkDecodeDuration() else {
                return
            }
            if seekProgressAfterPrepare > 0 {
                seekOnPrepare()
            } else {
                actionWhenReadyToPlay()
            }
        } else {
            if #available(iOS 10.0, *) {
                if (player.reasonForWaitingToPlay == nil && playOnNilKeepUpReason) {
                    playOnNilKeepUpReason = false
                    actionWhenBufferingRateReason()
                } else if player.reasonForWaitingToPlay == AVPlayer.WaitingReason.toMinimizeStalls {
                    actionWhenBufferingRateReason()
                }
            }
            actionWhenPerparing()
        }
    }
    
    func itemPlayer(steamAt time: TimeInterval, totalDuration: TimeInterval) {
//        Player_Print(" call back -> steam at time -> \(time) -- \(totalDuration)")
        itemPlayerDelegate?.steamingAtTime(time,
                                           itemDuration: totalDuration)
    }
    
    func itemPlayer(totalDurationChanged duration: CMTime) {
        guard duration.seconds.isNormal, itemDuration.seconds > 0 else {
            return
        }
//        Player_Print(" call back -> total duration -> \(duration.seconds)")
        outPutDuration(duration.seconds)
    }
    
    func itemPlayer(presentationSizeChanged size: CGSize) {
//        Player_Print(" call back -> size get -> \(size)")
        setGravity()
    }
    
    func itemPlayerDidReachEnd() {
//        Player_Print(" call back -> player reach end")
        didReachEnd()
    }
    
    func itemPlayer(playToTime time: CMTime) {
        guard checkDecodeDuration(),
            checkPlayerNoError() else {
            return
        }
//        Player_Print(" call back -> player play to time \(time.seconds)")
        let itemDuration = itemDuration.seconds
        if oldPlayTime != time &&
            time.seconds > 0.0 &&
            player.rate != 0 &&
            playStatus != .playing &&
            playStatus != .seeking {
            playStatus = .playing
            // strongSelf.needForcePlay = false
        }
        oldPlayTime = time
        itemPlayerDelegate?.playAtTime(abs(time.seconds),
                                       itemDuration: abs(itemDuration),
                                       progress: abs(progress))
    }
    
}

// MARK: - 播放器帮助方法
extension ItemPlayer {
    fileprivate func readyPlayerItem() {
        let keys = ["duration" , "tracks"]
        itemAsset.loadValuesAsynchronously(forKeys: keys) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var loaded: Bool = true
            for key in keys {
                let status: AVKeyValueStatus = strongSelf.itemAsset.statusOfValue(forKey: key, error: nil)
                if status != AVKeyValueStatus.loaded {
                    loaded = false
                }
            }
            guard loaded else {
                return
            }
            let playerItem = AVPlayerItem(asset: strongSelf.itemAsset)
            if Thread.isMainThread {
                strongSelf.readyPlayer(item: playerItem, recreate: false)
            } else {
                DispatchQueue.main.async {
                    strongSelf.readyPlayer(item: playerItem, recreate: false)
                }
            }
        }
    }
    
    fileprivate func readyPlayer(item: AVPlayerItem, recreate: Bool) {
        /// 清空所有旧监听
        // item
        observerControl.removeItemObserver()
        // player
        observerControl.removePlayerObserver(player: player)
        /// item设置 添加item监听
        observerControl.addItemObserver(playerItem: item)
        /// 修改结束状态
        atEnd = false
        /// 准备播放器
        if recreate {
            player = AVPlayer(playerItem: item)
        } else {
            player.replaceCurrentItem(with: item)
        }
        if #available(iOS 10.0, *) {
            player.automaticallyWaitsToMinimizeStalling = false
        }
        didOutputDisplaylayer = false
        playerLayer = AVPlayerLayer(player: player)
        /// 添加播放器监听
        observerControl.addPlayerObserver(player: player)
    }
}

func Player_Print<T>(_ message: T,file: String = #file, method: StaticString = #function, line: UInt = #line) {
    #if RELEASE

    #else
        guard ItemPlayer.needLog else { return }
        print("Player Output : [\(line)], \(method): \(message) \n // --> at thread: \(Thread.current) \n  --> at time: \(Date()) \n")
    #endif
}

