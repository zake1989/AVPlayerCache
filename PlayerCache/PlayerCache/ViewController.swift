//
//  ViewController.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/1.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit
import AVFoundation

//- 0 : "https://cdn.palm-chat.com/V/c8fbd51b10714e6283966e879d1246af_z.mp4"
//- 1 : "https://cdn.palm-chat.com/V/140ea76d4a514c92ba67871466600313_z.mp4"
//- 2 : "https://cdn.palm-chat.com/V/2f53898f6d6e4e6785e18e7597bf9365_z.mp4"
//- 3 : "https://cdn.palm-chat.com/V/0be3e1cb1e02415e9443e8be34461845_z.mp4"
//- 4 : "https://cdn.palm-chat.com/V/45e0c55e55774685af55430047e0ed47_z.mp4"
//"https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4"

class ViewController: UIViewController {
    
    let urlString: String = "https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4"
    
    lazy var cacheFileHandler: CacheFileHandler = CacheFileHandler(videoUrl: urlString)
    
    lazy var itemPlayer: ItemPlayer? = {
        guard let item = item else {
            return nil
        }
        let itemPlayer = ItemPlayer(item: item)
        itemPlayer.itemPlayerDelegate = self
        itemPlayer.forcePlayModel = true
        return itemPlayer
    }()
    lazy var player: AVPlayer? = {
        return AVPlayer(playerItem: item)
    }()
    
    lazy var cachePlayerItem: CachePlayerItem = CachePlayerItem()
    
    lazy var item: AVPlayerItem? = cachePlayerItem.createPlayerItem(urlString)
//         cachePlayerItem.createPureOnlineItem(urlString)
    
    let loader = CachedItemResourceLoader()
    
    let slider = UISlider(frame: CGRect.zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        if let player = itemPlayer {
            let layer = player.playerLayer
            layer.frame = view.frame
            view.layer.addSublayer(layer)
            player.play()
        } else {
            let layer = AVPlayerLayer(player: player)
            layer.frame = view.frame
            view.layer.addSublayer(layer)
            player?.play()
        }
        slider.frame = CGRect(x: 10, y: view.frame.height-100, width: view.frame.width-20, height: 50)
        view.addSubview(slider)
        slider.addTarget(self, action: #selector(self.sliderValueChange), for: UIControl.Event.touchUpInside)
    }
    
    @objc func sliderValueChange() {
        guard let duration = item?.duration else {
            return
        }
        print(slider.value)
        if let player = itemPlayer {
            player.seek(Double(slider.value))
        } else {
            player?.seek(to: CMTime(seconds: duration.seconds*Double(slider.value), preferredTimescale: duration.timescale))
        }
    }
}

extension ViewController: ItemPlayerDelegate {
    func itemTotalDuration(_ duration: TimeInterval) {
//        print("item player: item duration -> \(duration)")
    }
    
    func playAtTime(_ currentTime: TimeInterval, itemDuration: TimeInterval, progress: Double) {
//        print("item player: play at -> \(currentTime) -> \(itemDuration) -> \(progress)")
    }
    
    func steamingAtTime(_ steamingDuration: TimeInterval, itemDuration: TimeInterval) {
//        print("item player: steam at -> \(steamingDuration) -> \(itemDuration)")
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
    
    func fileHandlerDidFinishFetchData(error: Error?) {
        print("test fetched end")
    }
    
    func testCache() {
        let range: Range<Int> = Range<Int>(uncheckedBounds: (0, 2000*1024))
        cacheFileHandler.delegate = self
        cacheFileHandler.fetchData(at: range)
        cacheFileHandler.perDownloadData()
        
        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 50, height: 50))
        button.backgroundColor = UIColor.yellow
        button.addTarget(self, action: #selector(self.stop), for: .touchUpInside)
        view.addSubview(button)
        
        let button2 = UIButton(frame: CGRect(x: 200, y: 100, width: 50, height: 50))
        button2.backgroundColor = UIColor.red
        button2.addTarget(self, action: #selector(self.start), for: .touchUpInside)
        view.addSubview(button2)
    }
    
    @objc func stop() {
        cacheFileHandler.forceStopCurrentProcess()
    }
    
    @objc func start() {
        let range: Range<Int> = Range<Int>(uncheckedBounds: (0, 2000*1024))
        cacheFileHandler.fetchData(at: range)
    }
}
