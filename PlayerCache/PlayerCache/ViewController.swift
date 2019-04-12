//
//  ViewController.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/1.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    let urlString: String = "https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4"
    
    var cacheFileHandler: CacheFileHandler = CacheFileHandler(videoUrl: "https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4")
    
    var itemPlayer: ItemPlayer?
    var player: AVPlayer?
    var item: AVPlayerItem?
    
    let loader = CachedItemResourceLoader()
    
    let slider = UISlider(frame: CGRect.zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
//        let range: Range<Int> = Range<Int>(uncheckedBounds: (0, 2000*1024))
//        cacheFileHandler.delegate = self
//        cacheFileHandler.fetchData(at: range)
//        cacheFileHandler.perDownloadData()
        
        item = CachePlayerItem.createPlayerItem(urlString)
        
        if let item = item {
            itemPlayer = ItemPlayer(item: item)
            itemPlayer?.itemPlayerDelegate = self
            let layer = itemPlayer?.playerLayer
            layer?.frame = view.frame
            view.layer.addSublayer(layer!)
            itemPlayer?.forcePlayModel = true
            itemPlayer?.play()
        } else {
            player = AVPlayer(playerItem: item)
            let layer = AVPlayerLayer(player: player)
            layer.frame = view.frame
            view.layer.addSublayer(layer)
            player?.play()
        }

        slider.frame = CGRect(x: 10, y: view.frame.height-100, width: view.frame.width-20, height: 50)
        view.addSubview(slider)
        slider.addTarget(self, action: #selector(self.sliderValueChange), for: UIControl.Event.touchUpInside)
        
//        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 50, height: 50))
//        button.backgroundColor = UIColor.yellow
//        button.addTarget(self, action: #selector(self.stop), for: .touchUpInside)
//        view.addSubview(button)

//        let button2 = UIButton(frame: CGRect(x: 200, y: 100, width: 50, height: 50))
//        button2.backgroundColor = UIColor.red
//        button2.addTarget(self, action: #selector(self.start), for: .touchUpInside)
//        view.addSubview(button2)
    }
    
    @objc func sliderValueChange() {
        guard let duration = item?.duration else {
            return
        }
        print(slider.value)
        itemPlayer?.seek(Double(slider.value))
        player?.seek(to: CMTime(seconds: duration.seconds*Double(slider.value), preferredTimescale: duration.timescale))
        
    }
    
    @objc func stop() {
        cacheFileHandler.forceStopCurrentProcess()
    }
    
    @objc func start() {
        let range: Range<Int> = Range<Int>(uncheckedBounds: (0, 2000*1024))
        cacheFileHandler.fetchData(at: range)
    }
}

extension ViewController: ItemPlayerDelegate {
    func itemTotalDuration(_ duration: TimeInterval) {
        print("item player: item duration -> \(duration)")
    }
    
    func playAtTime(_ currentTime: TimeInterval, itemDuration: TimeInterval, progress: Double) {
        print("item player: play at -> \(currentTime) -> \(itemDuration) -> \(progress)")
    }
    
    func steamingAtTime(_ steamingDuration: TimeInterval, itemDuration: TimeInterval) {
        print("item player: steam at -> \(steamingDuration) -> \(itemDuration)")
    }
    
    func playStateChange(_ oldStatus: ItemPlayerStatus, playerStatus: ItemPlayerStatus) {
        
    }
    
    func didReachEnd() {
        print("reach end")
    }
    
    
}

extension ViewController: FileDataDelegate {
    func fileHandlerGetResponse(fileInfo info: CacheFileInfo) {
        print("test file info get")
    }
    
    func fileHandler(didFetch data: Data, at range: Range<Int>) {
        print("test data get")
    }
    
    func fileHandlerDidFinishFetchData() {
        print("test fetched end")
    }
    
    
}
