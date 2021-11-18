//
//  ViewController.swift
//  OnlinePlayerDemo
//
//  Created by zeng yukai on 2021/11/15.
//
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
//http://a.vskitcdn.com/V/fb853a5b-b565-49a8-b2d5-5f3077898bd2_z.mp4
//http://a.vskitcdn.com/V/820d926c-2290-47fb-a4c5-a41f4b3f0284_z.mp4
//http://a.vskitcdn.com/V/e9dcaf99-a869-4761-a198-5a1c63e8dce2_z.mp4
//http://a.vskitcdn.com/V/ed88830c-9530-4c53-b851-73edf1d0f499_z.mp4
//http://a.vskitcdn.com/V/8f39f332-1589-44da-871f-676894d55755_z.mp4
//http://a.vskitcdn.com/V/jiale_3s.mp4
//http://a.vskitcdn.com/V/jiale_1.mp4
//http://a.vskitcnd.com/V/jiale_2.mp4
//http://a.vskitcnd.com/V/jiale_3.mp4
//http://a.vskitcnd.com/V/jiale_4.mp4
//http://a.vskitcnd.com/V/jiale_5.mp4

import UIKit
import ItemPlayer
import AVFoundation

class ViewController: UIViewController {
    
    let urlString: String = "https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4"
    let subURLString: String = "https://aweme.snssdk.com/aweme/v1/playwm/?video_id=v0200f7e0000biirpudqg5b5btlhr6n0"
    
    lazy var cachePlayerItem: CachePlayerItem? = CachePlayerItem()
    
    lazy var item: AVPlayerItem? = cachePlayerItem?.createPlayerItem(urlString).0
    
    lazy var itemPlayer: ItemPlayer? = {
        guard let item = item else {
            return nil
        }
        let itemPlayer = ItemPlayer(item: item)
        itemPlayer.itemPlayerDelegate = self
        itemPlayer.forcePlayModel = true
        itemPlayer.expectedDuration = -2
        return itemPlayer
    }()
    
    var playerLayer: AVPlayerLayer?
    
    let slider = UISlider(frame: CGRect.zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        // Do any additional setup after loading the view.
        itemPlayer?.loopPlay = true
        itemPlayer?.play()
        
        let playButton = UIButton(frame: CGRect(x: 100, y: 100, width: 50, height: 50))
        playButton.backgroundColor = UIColor.yellow
        playButton.addTarget(self, action: #selector(self.playAction), for: .touchUpInside)
        view.addSubview(playButton)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @objc func playAction() {
        
    }
}

extension ViewController: ItemPlayerDelegate {
    func needRestartLoading() {
        
    }
    
    func itemSizeDecoded(_ videoSize: CGSize, playerLayer: AVPlayerLayer) {
        guard self.playerLayer == nil else {
            return
        }
        playerLayer.contentsGravity = .resizeAspect
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(playerLayer)
        self.playerLayer = playerLayer
    }
    
    func itemTotalDuration(_ duration: TimeInterval) {
        
    }
    
    func playAtTime(_ currentTime: TimeInterval, itemDuration: TimeInterval, progress: Double) {
        
    }
    
    func steamingAtTime(_ steamingDuration: TimeInterval, itemDuration: TimeInterval) {
        
    }
    
    func playStateChange(_ oldStatus: ItemPlayerStatus, playerStatus: ItemPlayerStatus) {
        
    }
    
    func didReachEnd() {
        
    }
}

extension ViewController {
    func playerTest() {
//        if let player = itemPlayer {
//            let layer = player.playerLayer
//            layer.frame = view.frame
//            view.layer.addSublayer(layer)
//            //            player.seek(0.5)
//            player.play()
//            print("play time: play call at \(Date().timeIntervalSince1970)")
//        } else {
//            let layer = AVPlayerLayer(player: player)
//            layer.frame = view.frame
//            view.layer.addSublayer(layer)
//            player?.play()
//        }
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
        item = cachePlayerItem?.createPlayerItem(subURLString).0
        if let item = item {
            itemPlayer?.changeItem(item,needRecreatePlayer: true)
            if let player = itemPlayer {
//                let layer = player.playerLayer
//                layer.frame = view.frame
//                view.layer.insertSublayer(layer, below: slider.layer)
//                player.play()
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
//            player?.seek(to: CMTime(seconds: duration.seconds*Double(slider.value), preferredTimescale: duration.timescale))
        }
    }
}

