//
//  PartsTestViewController.swift
//  OnlinePlayerDemo
//
//  Created by zeng yukai on 2021/11/16.
//

import UIKit
import ItemPlayer
import AVFoundation

class PartsTestViewController: UIViewController {
    
    let urlString: String = "https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4"
    
    let downloader: NewCacheDownloader = NewCacheDownloader()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        downloader.outputDelegate = self
        
        let playButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        playButton.center = view.center
        playButton.backgroundColor = UIColor.yellow
        playButton.addTarget(self, action: #selector(self.startDownload), for: .touchUpInside)
        view.addSubview(playButton)
    }
    
    @objc func startDownload() {
        guard let url = URL(string: urlString) else {
            return
        }
        downloader.startDownload(from: url,
                                 at: DataRange(uncheckedBounds: (0, 0)))
    }
}

extension PartsTestViewController: NewSessionOutputDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        print("session data task => receive response \(response)")
    }
    
    func urlSession(endWithDuration: TimeInterval, dataSize: Int64, urlString: String?) {
        print("session data task => receive finish")
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("session data task => receive data")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("session data task => receive error \(String(describing: error))")
    }
    
    
}
