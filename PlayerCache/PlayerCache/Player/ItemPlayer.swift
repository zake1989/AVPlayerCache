//
//  ItemPlayer.swift
//  Vskit
//
//  Created by Stephen zake on 2019/1/19.
//  Copyright © 2019 Transsnet. All rights reserved.
//

import UIKit
import AVFoundation

enum ItemPlayerStatus {
    case preparing
    case playing
    case seeking
    case paused
    case closed
}

protocol ItemPlayerDelegate: class {
    func needRestartLoading()
    func didSetLayerGravity()
    func itemTotalDuration(_ duration: TimeInterval)
    func playAtTime(_ currentTime: TimeInterval, itemDuration: TimeInterval, progress: Double)
    func steamingAtTime(_ steamingDuration: TimeInterval, itemDuration: TimeInterval)
    func playStateChange(_ oldStatus: ItemPlayerStatus, playerStatus: ItemPlayerStatus)
    func didReachEnd()
}

class ItemPlayer {
    
    static let needLog: Bool = false
    
    var itemDuration: CMTime {
        guard let playerItem = player.currentItem, !playerItem.duration.isIndefinite else {
            return CMTime.init(seconds: 0.0, preferredTimescale: CMTimeScale(30.0))
        }
        return playerItem.duration
    }
    
    var currentTime: CMTime {
        guard let playerItem = player.currentItem, !playerItem.duration.isIndefinite else {
            return CMTime.init(seconds: 0.0, preferredTimescale: CMTimeScale(30.0))
        }
        return playerItem.currentTime()
    }
    
    var loopPlay: Bool = false
    
    var forcePlayModel: Bool = false
    
    var playArea: CGRect = CGRect.zero {
        didSet {
            playerLayer.frame = playArea
            playerLayer.speed = 999
        }
    }
    
    var progress: Double {
        let duration = CMTimeGetSeconds(itemDuration)
        if duration == 0 || duration.isNaN {
            return 0.0
        }
        return CMTimeGetSeconds(currentTime)/duration
    }
    
    var muted: Bool = false {
        didSet {
            player.isMuted = muted
        }
    }
    
    var playerLayer: AVPlayerLayer
    
    weak var itemPlayerDelegate: ItemPlayerDelegate?
    
    var expectedDuration: TimeInterval = 0.0
    
    fileprivate var failedDuration: TimeInterval = -1
    
    fileprivate(set) var playStatus: ItemPlayerStatus = .preparing {
        didSet {
            switch playStatus {
            case .closed:
                Player_Print("status change: closed")
            case .playing:
                Player_Print("status change: playing")
            case .paused:
                Player_Print("status change: paused")
            case .preparing:
                Player_Print("status change: preparing")
            case .seeking:
                Player_Print("status change: seeking")
            }
            
            if oldValue != playStatus {
                itemPlayerDelegate?.playStateChange(oldValue ,playerStatus: playStatus)
            }
        }
    }
    
    fileprivate var needForcePlay: Bool = false
    
    fileprivate var seekProgressAfterPrepare: Double = 0.0
    
    fileprivate var player: AVPlayer
    
    fileprivate(set) var itemAsset: AVAsset
    
    fileprivate var timeObserver: Any?
    
    fileprivate var bufferDuration: TimeInterval = 1
    
    fileprivate var playBackStatusObserver: NSKeyValueObservation?
    
    fileprivate var steamProgressObserver: NSKeyValueObservation?
    
    fileprivate var timeControllObserver: NSKeyValueObservation?
    
    fileprivate var atEnd: Bool = false
    
    fileprivate var oldStatus: ItemPlayerStatus = .closed
    
    fileprivate var rate: Float = 1.0
    
    fileprivate var lastTimeControllNumber: Int = -1
    
    fileprivate var playOnNilKeepUpReason: Bool = true
    
    fileprivate var oldPlayTime: CMTime = CMTime.zero
    
    fileprivate var duringErrorHandle: Bool = false
    
    deinit {
        Player_Print("deinit video player")
        if let item = player.currentItem {
            NotificationCenter.default.removeObserver(self,
                                                      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                      object: item)
        }
        NotificationCenter.default.removeObserver(self)
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
    
    init(item: AVPlayerItem,
         needForceAudio: Bool = false,
         area: CGRect = .zero,
         delegate: ItemPlayerDelegate? = nil) {
        itemPlayerDelegate = delegate
        playArea = area
        itemAsset = item.asset
        if #available(iOS 10.0, *) {
            item.preferredForwardBufferDuration = bufferDuration
        }
        player = AVPlayer(playerItem: item)
        playerLayer = AVPlayerLayer(player: player)
        initOnPlayer(needForceAudio)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.audioRouteChanged(note:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }
    
    init(asset: AVAsset,
         needForceAudio: Bool = false,
         area: CGRect = .zero,
         delegate: ItemPlayerDelegate? = nil) {
        itemPlayerDelegate = delegate
        playArea = area
        itemAsset = asset
        let playerItem = AVPlayerItem(asset: itemAsset)
        if #available(iOS 10.0, *) {
            playerItem.preferredForwardBufferDuration = bufferDuration
        }
        player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        initOnPlayer(needForceAudio)
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
    
    fileprivate func initOnPlayer(_ needForceAudio: Bool) {
        playerLayer.backgroundColor = UIColor.clear.cgColor
        if #available(iOS 10.0, *) {
            player.automaticallyWaitsToMinimizeStalling = false
        }
        // 添加事件机制
        addVideoEventHandle()
        addVideoProgressHandle()
        // 输出总时间
        outPutTime()
//        if needForceAudio {
//            MPAudioSessionManager.default.openAudioSession()
//        }
    }
    
    fileprivate func outPutTime() {
        guard !itemDuration.seconds.isNaN else {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                self.outPutTime()
            }
            return
        }
        outPutDuration(itemDuration.seconds)
    }
    
    fileprivate func outPutDuration(_ duration: TimeInterval) {
        guard !duration.isNaN else {
            return
        }
        itemPlayerDelegate?.itemTotalDuration(duration)
    }
    
    func stopPlayer() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        resetPlayerItemInfo()
    }
}


// MARK: - 基础播放功能
extension ItemPlayer {
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
                strongSelf.checkPlayerErrorPlay()
            }
        }
    }
    
    func changeItem(_ playerItem: AVPlayerItem, needRecreatePlayer: Bool = false) {
        player.pause()
        playStatus = .preparing
        oldPlayTime = .zero
        self.itemAsset = playerItem.asset
        resetPlayerItemInfo()
        if needRecreatePlayer {
            recreatePlayer(playerItem)
        } else {
            replaceItemAndStartPlay(playerItem)
        }
    }
    
    func changeItemURL(_ itemAsset: AVAsset, needCallPlay: Bool = true) {
        player.pause()
        playStatus = .preparing
        clearItem()
        self.itemAsset.cancelLoading()
        self.itemAsset = itemAsset
        readyPlayerItem()
        needForcePlay = needCallPlay
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
        
        Player_Print("status change: +++++++++++++++++++++++++++++++++++ ")
        let targetTime = progress*itemDuration.seconds
        let seekingOldStatus = playStatus
        oldStatus = playStatus
        Player_Print("status change: change on seeking \(seekingOldStatus)")
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
                                Player_Print("status change: change after seeking pause")
                            }
                        }
        }
    }
    
    func setPlaySpeed(_ speed: Double) {
        rate = Float(speed)
    }
    
    func setGravityWith(_ size: CGSize) {
        var targetGravity: AVLayerVideoGravity = .resizeAspect
        if size.width > 0,
            size.height > 0,
            playArea.width > 0,
            playArea.height > 0,
            size.height/size.width > 15/10 {
            targetGravity = .resizeAspectFill
        }
        if playerLayer.videoGravity != targetGravity || playerLayer.frame != playArea  {
            playerLayer.videoGravity = targetGravity
            playerLayer.frame = playArea
            playerLayer.speed = 999
            itemPlayerDelegate?.didSetLayerGravity()
        }
    }
}

// MARK: - 播放器事件处理
extension ItemPlayer {
    
    fileprivate func addVideoEventHandle() {
        startSteamingHandler()
        bufferStatusObserver()
        videoPlayToEndHandle()
    }
    // 播放器缓冲进度输出
    fileprivate func startSteamingHandler() {
        guard let playerItem = player.currentItem else { return }
        steamProgressObserver = playerItem.observe(\AVPlayerItem.loadedTimeRanges,
                                                   options: [.new],
                                                   changeHandler: { [weak self] (item, value) in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    let itemDuration = strongSelf.itemDuration.seconds
                                                    let steamingTime = strongSelf.outputSteamingProgress()
                                                    strongSelf.itemPlayerDelegate?.steamingAtTime(steamingTime,
                                                                                                  itemDuration: itemDuration)
        })
    }
    
    // 播放器到最后
    fileprivate func videoPlayToEndHandle() {
        guard let playerItem = player.currentItem else { return }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReachEnd),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
    }
    
    fileprivate func checkPlayerErrorPlay() {
        guard checkPlayerNoError() else {
            player.pause()
            return
        }
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
        guard timeObserver != nil else {
            return timeDone
        }
        let duration = itemDuration.seconds
        if duration == Double.nan || duration <= 0 {
            return timeDone
        }
        if expectedDuration <= 0 ||
            (expectedDuration > 0 && duration > max(expectedDuration-2, 4)) ||
            (failedDuration == duration) {
            timeDone = true
        } else {
            if duration > 3 {
                failedDuration = duration
            }
            if let observer = timeObserver {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }
            itemPlayerDelegate?.needRestartLoading()
        }
        return timeDone
    }
    
    // 播放器进度输出
    fileprivate func addVideoProgressHandle() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval,
                                                      queue: DispatchQueue.main,
                                                      using: { [weak self] (time) in
                                                        guard let strongSelf = self,
                                                            strongSelf.checkDecodeDuration(),
                                                            strongSelf.checkPlayerNoError() else {
                                                            return
                                                        }
                                                        let itemDuration = strongSelf.itemDuration.seconds
                                                        if strongSelf.oldPlayTime != time &&
                                                            time.seconds > 0.0 &&
                                                            strongSelf.player.rate != 0 &&
                                                            strongSelf.playStatus != .playing &&
                                                            strongSelf.playStatus != .seeking {
                                                            strongSelf.playStatus = .playing
//                                                            strongSelf.needForcePlay = false
                                                        }
                                                        strongSelf.oldPlayTime = time
                                                        strongSelf.itemPlayerDelegate?.playAtTime(abs(time.seconds),
                                                                                                  itemDuration: abs(itemDuration),
                                                                                                  progress: abs(strongSelf.progress))
        })
    }
    
    // 播放器状态输出
    fileprivate func bufferStatusObserver() {
        guard let playerItem = player.currentItem else { return }
        playBackStatusObserver = playerItem.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp,
                                                    options: [.new, .old],
                                                    changeHandler: { [weak self] (item, keepUp) in
                                                        guard let strongSelf = self else {
                                                            return
                                                        }
                                                        strongSelf.setGravity()
                                                        if item.isPlaybackLikelyToKeepUp {
                                                            guard strongSelf.checkDecodeDuration() else {
                                                                return
                                                            }
                                                            if strongSelf.seekProgressAfterPrepare > 0 {
                                                                strongSelf.seekOnPrepare()
                                                            } else {
                                                                strongSelf.actionWhenReadyToPlay()
                                                            }
                                                        } else {
                                                            if #available(iOS 10.0, *) {
                                                                if (strongSelf.player.reasonForWaitingToPlay == nil && strongSelf.playOnNilKeepUpReason) {
                                                                    strongSelf.playOnNilKeepUpReason = false
                                                                    strongSelf.actionWhenBufferingRateReason()
                                                                } else if strongSelf.player.reasonForWaitingToPlay == AVPlayer.WaitingReason.toMinimizeStalls {
                                                                    strongSelf.actionWhenBufferingRateReason()
                                                                }
                                                            }
                                                            strongSelf.actionWhenPerparing()
                                                        }
        })
    }
    
    fileprivate func addTimeControllObserver() {
        guard #available(iOS 10.0, *) else {
            return
        }
        timeControllObserver = player.observe(\AVPlayer.timeControlStatus,
                                              options: [.old, .new],
                                              changeHandler: { [weak self] (player, value) in
                                                guard self?.lastTimeControllNumber == player.timeControlStatus.rawValue else {
                                                    self?.lastTimeControllNumber = player.timeControlStatus.rawValue
                                                    return
                                                }
                                                self?.lastTimeControllNumber = player.timeControlStatus.rawValue
        })
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
        Player_Print("status change: seek after perparing")
        fastSeek(seekProgressAfterPrepare)
        seekProgressAfterPrepare = 0
        if oldStatus == .playing || needForcePlay {
            checkPlayerErrorPlay()
        } else {
            player.pause()
            playStatus = .paused
        }
    }
    
    fileprivate func actionWhenReadyToPlay() {
        // 可以开始播放的状态 如果开启强制播放 就强制播放 如果没有开启强制播放 就保持暂停
        if oldStatus == .playing || needForcePlay {
            checkPlayerErrorPlay()
        } else {
            player.pause()
            playStatus = .paused
            Player_Print("status change: change after preparing pause")
        }
        Player_Print("status change: change after preparing get old \(oldStatus)")
    }
    
    fileprivate func actionWhenPerparing() {
        if playStatus != .playing {
            oldStatus = .paused
        } else {
            oldStatus = .playing
        }
        Player_Print("status change: change in preparing get old \(oldStatus)")
        playStatus = .preparing
    }
    
    func actionWhenBufferingRateReason() {
        guard needForcePlay, checkPlayerNoError() else {
            return
        }
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
                itemPlayerDelegate?.needRestartLoading()
            }
            return false
        }
        return true
    }
    
    fileprivate func setGravity() {
        guard let item = player.currentItem else {
            return
        }
        let size = item.presentationSize
        guard !size.equalTo(CGSize.zero) else {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                self.setGravity()
            }
            return
        }
        setGravityWith(size)
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
        itemPlayerDelegate?.didReachEnd()
        guard loopPlay else {
            var duration = itemDuration.seconds
            if duration == Double.nan {
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

// MARK: - 播放器帮助方法
extension ItemPlayer {
    
    fileprivate func resetPlayerItemInfo() {
        playBackStatusObserver = nil
        steamProgressObserver = nil
        timeControllObserver = nil
        lastTimeControllNumber = -1
        playOnNilKeepUpReason = true
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                  object: player.currentItem)
    }
    
    fileprivate func readyPlayerItem() {
        let keys = ["duration" , "tracks"]
        itemAsset.loadValuesAsynchronously(forKeys: keys) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var loaded: Bool = true
            for key in keys {
                var error: NSError?
                let status: AVKeyValueStatus = strongSelf.itemAsset.statusOfValue(forKey: key, error: &error)
                if status != AVKeyValueStatus.loaded {
                    loaded = false
                }
            }
            guard loaded else {
                return
            }
            let playerItem = AVPlayerItem(asset: strongSelf.itemAsset)
            DispatchQueue.main.async {
                strongSelf.replaceItemAndStartPlay(playerItem)
            }
        }
    }
    
    fileprivate func recreatePlayer(_ item: AVPlayerItem) {
        if #available(iOS 10.0, *) {
            item.preferredForwardBufferDuration = bufferDuration
        }
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        player.replaceCurrentItem(with: nil)
        atEnd = false
        player = AVPlayer(playerItem: item)
        playerLayer = AVPlayerLayer(player: player)
        initOnPlayer(true)
        // 输出总时间
        let totalTime = item.duration.seconds
        outPutDuration(totalTime)
        duringErrorHandle = false
    }
    
    fileprivate func replaceItemAndStartPlay(_ item: AVPlayerItem) {
        if #available(iOS 10.0, *) {
            item.preferredForwardBufferDuration = bufferDuration
        }
        resetPlayerItemInfo()
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        player.replaceCurrentItem(with: nil)
        atEnd = false
        player.replaceCurrentItem(with: item)
        playerLayer = AVPlayerLayer(player: player)
        // 输出总时间
        let totalTime = item.duration.seconds
        outPutDuration(totalTime)
        if timeObserver == nil {
            initOnPlayer(false)
        } else {
            addVideoEventHandle()
        }
    }
    
    fileprivate func clearItem() {
        resetPlayerItemInfo()
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        player.replaceCurrentItem(with: nil)
        atEnd = false
    }
}

func Player_Print<T>(_ message: T,file: String = #file, method: StaticString = #function, line: UInt = #line) {
    guard ItemPlayer.needLog else { return }
    print("Player Output : [\(line)], \(method): \(message) \n // --> at thread: \(Thread.current) \n  --> at time: \(Date()) \n")
}

