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
    
    var cacheFileHandler: CacheFileHandler = CacheFileHandler(videoUrl: "https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4")
    
    var player: AVPlayer?
    var item: AVPlayerItem?
    
    let loader = CachedItemResourceLoader()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let us = CachedItemResourceLoader.createLocalURL("https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4")
//        let us = "https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4"
        let url = URL(string: us)!
//        let range: Range<Int> = Range<Int>(uncheckedBounds: (0, 2000*1024))
//        cacheFileHandler.delegate = self
//        cacheFileHandler.fetchData(at: range)
//        cacheFileHandler.perDownloadData()
        
        
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.main)
        item = AVPlayerItem(asset: asset)
        item?.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        player = AVPlayer(playerItem: item)
        let layer = AVPlayerLayer(player: player)
        layer.frame = view.frame
        view.layer.addSublayer(layer)
        player?.play()
        
//        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 50, height: 50))
//        button.backgroundColor = UIColor.yellow
//        button.addTarget(self, action: #selector(self.stop), for: .touchUpInside)
//        view.addSubview(button)
//
//        let button2 = UIButton(frame: CGRect(x: 200, y: 100, width: 50, height: 50))
//        button2.backgroundColor = UIColor.red
//        button2.addTarget(self, action: #selector(self.start), for: .touchUpInside)
//        view.addSubview(button2)
    }
    
    @objc func stop() {
        cacheFileHandler.forceStopCurrentProcess()
    }
    
    @objc func start() {
        let range: Range<Int> = Range<Int>(uncheckedBounds: (0, 2000*1024))
        cacheFileHandler.fetchData(at: range)
    }
}
