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
//"http://v1-dy.ixigua.com/fb0fb3d40770ce9a690d95a4fde01951/5cb056dc/video/m/220341e36790cb34dbd82a64eed958fa9521161b88510000287a504d0444/?rc=ajptNXA1ZzZ2bDMzaWkzM0ApQHRAb0Y1OjQzNDozNDk2OTU3PDNAKXUpQGczdylAZmxkamV6aGhkZjs0QC02ZGRhNW9mYF8tLS8tL3NzLW8jbyNDLy02My0uLS0wLi4uLS4vaTpiLW8jOmAtbyNtbCtiK2p0OiMvLl4%3D"


class ViewController: UIViewController {
    
    let urlString: String = "http://v6-dy.ixigua.com/3f22d471eca52242da6aabc1ec0cfb02/5cb06dc7/video/m/220d12c52c4ae0c4a498be52a948fe078cd1161cf4ed00003699b11c273c/?rc=M21qNHRlbWx5bDMzN2kzM0ApQHRAbzdFPDQzNjszNDQ0OjU3PDNAKXUpQGczdylAZmxkamV6aGhkZjs0QGplM2xsL25wal8tLTAtL3NzLW8jbyMxNTM2MC0uLS0xMi4uLS4vaTpiLW8jOmAtbyNtbCtiK2p0OiMvLl4%3D"

    
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
//         cachePlayerItem.createPureOnlineItem(urlString)  cachePlayerItem.createPlayerItem(urlString)
    
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
            player.fastSeek(Double(slider.value))
//            player.seek(Double(slider.value))
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
    func fileHandlerGetResponse(fileInfo info: CacheFileInfo, response: URLResponse?) {
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
