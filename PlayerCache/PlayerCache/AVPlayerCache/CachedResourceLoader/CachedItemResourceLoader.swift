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
    deinit {
        Cache_Print("deinit cached item resource loader", level: LogLevel.resource)
    }
    
    var loadingRequestList: [AVAssetResourceLoadingRequest] = []

    var seekingRequestList: [AVAssetResourceLoadingRequest] = []
    
    var currentLoadingRequest: AVAssetResourceLoadingRequest?
    
    var cacheFileHandler: CacheFileHandler?
    
    var onSeeking: Bool = false
    
    override init() {
        super.init()
    }
    
    fileprivate func processPendingRequests() {
        if let request = currentLoadingRequest, request.isFinished {
            Cache_Print("loader process pending request on begin", level: LogLevel.resource)
            removeRequest()
        } else {
            Cache_Print("loader not process pending request on begin", level: LogLevel.resource)
            return
        }
        currentLoadingRequest = nil
        if let request = seekingRequestList.first {
            processCurrentRequest(loadingRequest: request)
        } else if let request = loadingRequestList.first {
            processCurrentRequest(loadingRequest: request)
        } else {
            Cache_Print("loader process no more pending request", level: LogLevel.resource)
        }
    }
    
    func processCurrentRequest(loadingRequest: AVAssetResourceLoadingRequest) {
        guard currentLoadingRequest == nil else {
            Cache_Print("loader not process request: request empty", level: LogLevel.resource)
            return
        }
        Cache_Print("loader start process request", level: LogLevel.resource)
        currentLoadingRequest = loadingRequest
        guard let localUrlString = loadingRequest.request.url?.absoluteString,
            let request = loadingRequest.dataRequest else {
                Cache_Print("loader not process request: request error", level: LogLevel.resource)
                return
        }
        let urlString = ItemURL.onlineUrl(localUrlString)
        createFileHandler(urlString)
        requsetData(request)
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
    
}

extension CachedItemResourceLoader: FileDataDelegate {
    func fileHandlerGetResponse(fileInfo info: CacheFileInfo, response: URLResponse?) {
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
    
    func fileHandlerDidFinishFetchData(error: Error?) {
        DispatchQueue.main.async {
            if let e = error, (e as NSError).code != NSURLErrorCancelled {
                Cache_Print("loader finish fetch data with error", level: LogLevel.resource)
                self.currentLoadingRequest?.finishLoading(with: e)
            } else {
                Cache_Print("loader finish fetch data", level: LogLevel.resource)
                self.currentLoadingRequest?.finishLoading()
            }
            self.processPendingRequests()
        }
    }
}

extension CachedItemResourceLoader: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        Cache_Print("loader renew request", level: LogLevel.resource)
        return false
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        let isContentInfo = loadingRequest.contentInformationRequest == nil ? "is not content info" : "is content info"
        let isData = loadingRequest.dataRequest == nil ? "is not data" : "is data"
        Cache_Print("loader loading request : \n \(isContentInfo) \n \(isData)", level: LogLevel.resource)
        if currentLoadingRequest == nil {
            Cache_Print("loader loading request direcly", level: LogLevel.resource)
            processCurrentRequest(loadingRequest: loadingRequest)
        }
        if onSeeking {
            seekingRequestList.append(loadingRequest)
        } else {
            loadingRequestList.append(loadingRequest)
        }
        Cache_Print("loader pending request : \(loadingRequestList.count+seekingRequestList.count)", level: LogLevel.resource)
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        Cache_Print("loader cancel need", level: LogLevel.resource)
        cacheFileHandler?.forceStopCurrentProcess()
        onSeeking = true
    }
    
    func removeRequest() {
        loadingRequestList = loadingRequestList.filter { (request) -> Bool in
            return !(request.isFinished || request.isCancelled)
        }
        seekingRequestList = seekingRequestList.filter { (request) -> Bool in
            return !(request.isFinished || request.isCancelled)
        }
    }
}

