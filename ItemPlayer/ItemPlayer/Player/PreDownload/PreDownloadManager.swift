//
//  PreDownloadManager.swift
//  Vskit
//
//  Created by Stephen zake on 2019/4/22.
//  Copyright © 2019 Transsnet. All rights reserved.
//

import UIKit
import AVFoundation

public class PreDownloadManager {
    public static let shared = PreDownloadManager()
    
    fileprivate var sourceList: [String] = []
    
    fileprivate var fullList: [String] = []
    
    fileprivate var cacheFileHandler: CacheFileHandler?
    
    fileprivate var isDownloading: Bool = false
    
    fileprivate var isOnFullyDownload: Bool = false
    
    private let StatusQueue = DispatchQueue(label: "Pre.Download.Status.Queue", qos: .utility ,attributes: .concurrent)
    
    public var canAdd: Bool {
        return sourceList.count == 0
    }
    
    private init() {
        
    }
    
    fileprivate func isDownload() -> Bool {
        var downloading: Bool = true
        StatusQueue.sync {
            downloading = self.isDownloading
        }
        return downloading
    }
    
    fileprivate func updateDownloadingStatus(_ downloading: Bool) {
        StatusQueue.async(flags: DispatchWorkItemFlags.barrier) {
            self.isDownloading = downloading
        }
    }
    
    public func addSource(_ list: [String]) {
        sourceList.append(contentsOf: list)
//        fullList.append(contentsOf: list)
    }
    
    public func removeSource(_ videoURL: String) {
        sourceList = sourceList.filter({ (urlString) -> Bool in
            return urlString != videoURL
        })
//        fullList = fullList.filter({ (urlString) -> Bool in
//            return urlString != videoURL
//        })
    }
    
    public func preloadImage(videoURL: String, completion: @escaping (String, UIImage?) -> Void) {
        let videoPath = CacheFilePathHelper.videoPath(from: videoURL)
        let size = CacheFilePathHelper.fileSizeAtPath(videoPath)
        guard size > 1024*200 else {
            return
        }
        imageFromVideo(urlString: videoURL, url: URL(fileURLWithPath: videoPath), at: 0.0, completion: completion)
    }
    
    fileprivate func imageFromVideo(urlString: String,
                                    url: URL,
                                    at time: TimeInterval,
                                    completion: @escaping (String, UIImage?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let asset = AVURLAsset(url: url)

            let assetIG = AVAssetImageGenerator(asset: asset)
            assetIG.appliesPreferredTrackTransform = true
            assetIG.apertureMode = AVAssetImageGenerator.ApertureMode.encodedPixels

            let cmTime = CMTime(seconds: time, preferredTimescale: 60)
            let thumbnailImageRef: CGImage
            do {
                thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
            } catch let error {
                print("Error: \(error)")
                DispatchQueue.main.async {
                    completion(urlString, nil)
                }
                return
            }

            DispatchQueue.main.async {
                completion(urlString, UIImage(cgImage: thumbnailImageRef))
            }
        }
    }
    
    public func clearAll() {
        stopProcessSource()
        sourceList = []
        fullList = []
    }
    
    public func stopProcessSource() {
//        VSPrint("process url force stop")
        updateDownloadingStatus(false)
        cacheFileHandler?.delegate = nil
        cacheFileHandler?.forceStopCurrentProcess()
        cacheFileHandler = nil
    }
    
    public func startProcessSource() {
        guard !isDownload() else {
            return
        }
        updateDownloadingStatus(true)
        downloadFirstSource()
    }
    
    fileprivate func downloadFirstSource() {
        guard let urlString = sourceList.first else {
            updateDownloadingStatus(false)
            fullyDownLoadSource()
            return
        }
        defer {
            sourceList = sourceList.filter({ (videoURL) -> Bool in
                return urlString != videoURL
            })
        }
        guard !CacheFileHandler.isFullyDownload(videoUrl: urlString) else {
            return
        }
        isOnFullyDownload = false
//        VSPrint("process url predownload \(urlString)")
        self.cacheFileHandler?.delegate = nil
        self.cacheFileHandler = CacheFileHandler(videoUrl: urlString)
        self.cacheFileHandler?.delegate = self
        self.cacheFileHandler?.preDownloadData()
    }
    
    fileprivate func fullyDownLoadSource() {
        guard sourceList.count == 0, let urlString = fullList.first else {
            isDownloading = false
            return
        }
        defer {
            fullList = fullList.filter({ (videoURL) -> Bool in
                return urlString != videoURL
            })
        }
        guard !CacheFileHandler.isFullyDownload(videoUrl: urlString) else {
            return
        }
        isOnFullyDownload = true
//        VSPrint("process url full download \(urlString)")
        self.cacheFileHandler?.delegate = nil
        self.cacheFileHandler = CacheFileHandler(videoUrl: urlString)
        self.cacheFileHandler?.delegate = self
        self.cacheFileHandler?.fullyPreDownloadData()
    }

}

extension PreDownloadManager: FileDataDelegate {
    func fileHandlerGetResponse(fileInfo info: CacheFileInfo, response: URLResponse?) {
        
    }
    
    func fileHandler(didFetch data: Data, at range: DataRange) {
        
    }
    
    func fileHandlerDidFinishFetchData(error: Error?) {
//        VSPrint("process url finish: \(String(describing: error))")
        downloadFirstSource()
    }
    
    func fileHandlerRequesetEnd(duration: TimeInterval, dataSize: Int64, urlString: String?) {
        
    }
}
