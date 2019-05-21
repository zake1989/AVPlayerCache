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
//"https://cdn.palm-chat.com/V/da805946-94ec-4614-8e65-d2f25709ec83_z.mp4"
//"https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4"
//"https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200f340000bimvsiqj2boqo16ghjm0"
//"https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0300fc20000bik28jcif32phdckjgog"
//"https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200fc50000bierlad1mik4qf9714sg"
//"https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200f7e0000biirpudqg5b5btlhr6n0"
//"https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200f880000bii87pveqk816g9s7ql0"


class ViewController: UIViewController {
    
    let urlString: String = "https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200f340000bimvsiqj2boqo16ghjm0"

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
    
    lazy var cachePlayerItem: CachePlayerItem? = CachePlayerItem()
    
    lazy var item: AVPlayerItem? = cachePlayerItem?.createPlayerItem(urlString)
//         cachePlayerItem.createPureOnlineItem(urlString)  cachePlayerItem.createPlayerItem(urlString)
    
    let loader = CachedItemResourceLoader(false)
    
    let slider = UISlider(frame: CGRect.zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
//        testCache()
        playerTest()
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
        if playerStatus == .playing {
            print("play time: play start at \(Date().timeIntervalSince1970)")
        }
    }
    
    func didReachEnd() {
        print("reach end")
    }

}

extension ViewController: FileDataDelegate {
    func fileHandlerGetResponse(fileInfo info: CacheFileInfo, response: URLResponse?) {
        print("test file info get")
    }
    
    func fileHandler(didFetch data: Data, at range: DataRange) {
        print("test data get")
    }
    
    func fileHandlerDidFinishFetchData(error: Error?) {
        print("test fetched end")
    }
    
    func testCache() {
        let range: DataRange = DataRange(uncheckedBounds: (0, 2))
        cacheFileHandler.delegate = self
//        cacheFileHandler.fetchData(at: range)
//        cacheFileHandler.perDownloadData()
        
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
        let range: DataRange = DataRange(uncheckedBounds: (0, 2000*1000))
//        cacheFileHandler.fetchData(at: range)
    }
}

extension ViewController {
    func playerTest() {
        if let player = itemPlayer {
            let layer = player.playerLayer
            layer.frame = view.frame
            view.layer.addSublayer(layer)
            //            player.seek(0.5)
            player.play()
            print("play time: play call at \(Date().timeIntervalSince1970)")
        } else {
            let layer = AVPlayerLayer(player: player)
            layer.frame = view.frame
            view.layer.addSublayer(layer)
            player?.play()
        }
        slider.frame = CGRect(x: 10, y: view.frame.height-100, width: view.frame.width-20, height: 50)
        view.addSubview(slider)
        slider.addTarget(self, action: #selector(self.sliderValueChange), for: UIControl.Event.touchUpInside)
        
        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 50, height: 50))
        button.backgroundColor = UIColor.yellow
        button.addTarget(self, action: #selector(self.replaceItem), for: .touchUpInside)
        view.addSubview(button)
        
        let button2 = UIButton(frame: CGRect(x: 200, y: 100, width: 50, height: 50))
        button2.backgroundColor = UIColor.red
        button2.addTarget(self, action: #selector(self.clearAll), for: .touchUpInside)
        view.addSubview(button2)
    }
    
    @objc func replaceItem() {
        item = cachePlayerItem?.createPlayerItem("https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200f7e0000biirpudqg5b5btlhr6n0")
        if let item = item {
            itemPlayer?.changeItem(item,needRecreatePlayer: true)
            if let player = itemPlayer {
                let layer = player.playerLayer
                layer.frame = view.frame
                view.layer.insertSublayer(layer, below: slider.layer)
                player.play()
            }
        }
    }
    
    @objc func clearAll() {
        itemPlayer?.pause()
        itemPlayer?.stopPlayer()
        //        (item?.asset as? AVURLAsset)?.resourceLoader.setDelegate(nil, queue: nil)
        itemPlayer = nil
        item = nil
        cachePlayerItem = nil
    }
    
    @objc func sliderValueChange() {
        guard let duration = item?.duration else {
            return
        }
        print(slider.value)
        if let player = itemPlayer {
            player.fastSeek(Double(slider.value))
            //            player.seek(Double(slider.value))
        } else {
            player?.seek(to: CMTime(seconds: duration.seconds*Double(slider.value), preferredTimescale: duration.timescale))
        }
    }
}
