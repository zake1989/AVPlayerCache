//
//  ResourceLoader.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/10.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit
import AVFoundation

class CachedItemResourceLoader: NSObject {
    
    var loadingRequestList: [AVAssetResourceLoadingRequest] = []
    
    var currentLoadingRequest: AVAssetResourceLoadingRequest?
    
    var cacheFileHandler: CacheFileHandler?
    
    override init() {
        super.init()
        
    }
    
    static func createLocalURL(_ urlString: String) -> String {
        return urlString.replacingOccurrences(of: "http", with: BasicFileData.localURLPrefix)
    }
    
    func onlineUrl(_ urlString: String) -> String {
        return urlString.replacingOccurrences(of: BasicFileData.localURLPrefix, with: "http")
    }
    
    fileprivate func createFileHandler(_ urlString: String) {
        guard cacheFileHandler == nil else {
            return
        }
        cacheFileHandler = CacheFileHandler(videoUrl: urlString)
        cacheFileHandler?.delegate = self
    }
    
    fileprivate func requsetData(_ dataRequest: AVAssetResourceLoadingDataRequest) {
        let range = Range<Int>.init(uncheckedBounds: (Int(dataRequest.requestedOffset), upper: Int(dataRequest.requestedOffset)+dataRequest.requestedLength))
        Cache_Print("loader Data requested at range : \(range)", level: LogLevel.resource)
        
        cacheFileHandler?.fetchData(at: range)
    }
    
    fileprivate func processPendingRequests() {
        if let request = currentLoadingRequest, request.isFinished {
            Cache_Print("loader process pending request on begin", level: LogLevel.resource)
            removeRequest(loadingRequest: request)
        } else {
            Cache_Print("loader not process pending request on begin", level: LogLevel.resource)
            return
        }
        currentLoadingRequest = nil
        if let request = loadingRequestList.last {
            processCurrentRequest(loadingRequest: request)
        }
    }
    
    func processCurrentRequest(loadingRequest: AVAssetResourceLoadingRequest) {
        guard currentLoadingRequest == nil else {
            Cache_Print("loader not process request", level: LogLevel.resource)
            return
        }
        Cache_Print("loader start process request", level: LogLevel.resource)
        currentLoadingRequest = loadingRequest
        guard let localUrlString = loadingRequest.request.url?.absoluteString,
            let request = loadingRequest.dataRequest else {
                return
        }
        let urlString = onlineUrl(localUrlString)
        createFileHandler(urlString)
        requsetData(request)
    }
    
}

extension CachedItemResourceLoader: FileDataDelegate {
    func fileHandlerGetResponse(fileInfo info: CacheFileInfo) {
        DispatchQueue.main.async {
            Cache_Print("loader loading request response : \(info)", level: LogLevel.resource)
            self.currentLoadingRequest?.contentInformationRequest?.contentType = info.contentType
            self.currentLoadingRequest?.contentInformationRequest?.contentLength = Int64(info.contentLength)
            self.currentLoadingRequest?.contentInformationRequest?.isByteRangeAccessSupported = info.byteRangeAccessSupported
        }
    }
    
    func fileHandler(didFetch data: Data, at range: Range<Int>) {
        DispatchQueue.main.async {
            Cache_Print("loader fetched Data: \(data.count)", level: LogLevel.resource)
            self.currentLoadingRequest?.dataRequest?.respond(with: data)
        }
    }
    
    func fileHandlerDidFinishFetchData() {
        DispatchQueue.main.async {
            Cache_Print("loader finish fetch data", level: LogLevel.resource)
            self.currentLoadingRequest?.finishLoading()
            self.processPendingRequests()
        }
    }
}

extension CachedItemResourceLoader: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        let isContentInfo = loadingRequest.contentInformationRequest == nil ? "is not content info" : "is content info"
        let isData = loadingRequest.dataRequest == nil ? "is not data" : "is data"
        Cache_Print("loader loading request : \(loadingRequest.request.url?.absoluteString ?? "")  \n \(isContentInfo) \n \(isData)", level: LogLevel.resource)
        if currentLoadingRequest == nil {
            Cache_Print("loader loading request direcly", level: LogLevel.resource)
            processCurrentRequest(loadingRequest: loadingRequest)
        }
        loadingRequestList.append(loadingRequest)
//        processPendingRequests()
        Cache_Print("loader pending request : \(loadingRequestList.count)", level: LogLevel.resource)
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        print("loader need cancel")
        currentLoadingRequest?.finishLoading()
        cacheFileHandler?.forceStopCurrentProcess()
    }
    
    func removeRequest(loadingRequest: AVAssetResourceLoadingRequest) {
        guard let index = loadingRequestList.enumerated().filter({ (content) -> Bool in
            return content.element == loadingRequest
        }).first?.offset else {
                return
        }
        loadingRequestList.remove(at: index)
    }
}

