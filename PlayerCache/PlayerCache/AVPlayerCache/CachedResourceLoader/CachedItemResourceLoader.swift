//
//  ResourceLoader.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/10.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit
import AVFoundation

protocol CachedItemHandleDelegate: class {
    func needRecoverFromError()
    func noMoreRequestCheck()
    func canTryForcePlay()
}

class CachedItemResourceLoader: NSObject {
    deinit {
        Cache_Print("deinit cached item resource loader", level: LogLevel.resource)
    }
    
    weak var delegate: CachedItemHandleDelegate?
    
    var loadingRequestList: [AVAssetResourceLoadingRequest] = []
    
    var seekingRequestList: [AVAssetResourceLoadingRequest] = []
    
    var currentLoadingRequest: AVAssetResourceLoadingRequest?
    
    var cacheFileHandler: CacheFileHandler?
    var onSeeking: Bool = false
    
    fileprivate var onSingleRequestModel: Bool = false
    
    fileprivate var task: DispatchWorkItem?
    
    fileprivate var dataReceiveCountOnPreparing: Int = 0
    fileprivate var bufferDataRange: DataRange = DataRange(uncheckedBounds: (lower: 0, upper: 0))
    fileprivate var bufferData: Data = Data()
    
    convenience init(_ singleRequestModel: Bool) {
        self.init()
        onSingleRequestModel = singleRequestModel
    }
    
    private override init() {
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
            checkNoMorePandingRequestStatus()
        }
    }
    
    fileprivate func checkNoMorePandingRequestStatus() {
        task?.cancel()
        task = DispatchWorkItem { [weak self] in
            self?.delegate?.noMoreRequestCheck()
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.4, execute: task!)
    }
    
    fileprivate func processCurrentRequest(loadingRequest: AVAssetResourceLoadingRequest) {
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
    
    fileprivate func requsetData(_ dataRequest: AVAssetResourceLoadingDataRequest) {
        let range = DataRange(uncheckedBounds: (Int64(dataRequest.requestedOffset), upper: Int64(dataRequest.requestedOffset)+Int64(dataRequest.requestedLength)))
        Cache_Print("loader Data requested at range : \(range)", level: LogLevel.resource)
        cacheFileHandler?.fetchData(at: range)
        Cache_Print("play time: data start fetch at \(Date().timeIntervalSince1970)", level: LogLevel.resource)
    }
    
    fileprivate func createFileHandler(_ loadingRequest: AVAssetResourceLoadingRequest) {
        guard let localUrlString = loadingRequest.request.url?.absoluteString else {
            Cache_Print("loader not process request: request error", level: LogLevel.resource)
            return
        }
        Cache_Print("loader start load full data", level: LogLevel.resource)
        let urlString = ItemURL.onlineUrl(localUrlString)
        createFileHandler(urlString)
    }
    
    fileprivate func createFileHandler(_ urlString: String) {
        guard cacheFileHandler == nil else {
            return
        }
        cacheFileHandler = CacheFileHandler(videoUrl: urlString)
        cacheFileHandler?.delegate = self
    }
    
}

extension CachedItemResourceLoader: FileDataDelegate {
    func fileHandlerGetResponse(fileInfo info: CacheFileInfo, response: URLResponse?) {
        print("get response")
        DispatchQueue.main.async {
            print(info)
            guard let infoRequest = self.fetchInfoRequest(),
                infoRequest.contentInformationRequest != nil else {
                return
            }
            Cache_Print("loader loading request response : \(info)", level: LogLevel.resource)
            infoRequest.contentInformationRequest?.contentType = info.contentType
            infoRequest.contentInformationRequest?.contentLength = Int64(info.contentLength)
            infoRequest.contentInformationRequest?.isByteRangeAccessSupported = info.byteRangeAccessSupported
            if self.onSingleRequestModel {
                infoRequest.finishLoading()
                self.removeRequest()
            }
            Cache_Print("play time: header fetch at \(Date().timeIntervalSince1970)", level: LogLevel.resource)
        }
    }
    
    fileprivate func fetchInfoRequest() -> AVAssetResourceLoadingRequest? {
        if onSingleRequestModel {
            return loadingRequestList.filter({ (request) -> Bool in
                return request.contentInformationRequest != nil
            }).first
        } else {
            return currentLoadingRequest
        }
    }
    
    func fileHandler(didFetch data: Data, at range: DataRange) {
        print(range)
        DispatchQueue.main.async {
            if self.onSingleRequestModel {
                self.handleFetchedData(data, at: range)
            } else {
                Cache_Print("loader fetched Data: \(data.count)", level: LogLevel.resource)
                if self.currentLoadingRequest?.contentInformationRequest == nil {
                    self.currentLoadingRequest?.dataRequest?.respond(with: data)
                }
            }
            self.dataReceiveCountOnPreparing += 1
            if self.dataReceiveCountOnPreparing >= BasicFileData.tryForcePlayBufferCount {
                self.dataReceiveCountOnPreparing = 0
                self.delegate?.canTryForcePlay()
            }
        }
    }
    
    func fileHandlerDidFinishFetchData(error: Error?) {
        print("finish request")
        DispatchQueue.main.async {
            if let e = error, (e as NSError).code != NSURLErrorCancelled {
                Cache_Print("loader finish fetch data with error", level: LogLevel.resource)
                self.currentLoadingRequest?.finishLoading(with: e)
                self.delegate?.needRecoverFromError()
            } else {
                 print("finish")
                if self.onSingleRequestModel {
                    self.handleRequestAfterFullyDownloaded()
                } else {
                    Cache_Print("loader finish fetch data", level: LogLevel.resource)
                    self.currentLoadingRequest?.finishLoading()
                    Cache_Print("play time: fetch finish at \(Date().timeIntervalSince1970)", level: LogLevel.resource)
                    self.processPendingRequests()
                }
            }
        }
    }
    
    fileprivate func filterCurrentRequest(_ startDataRange: DataRange) -> [AVAssetResourceLoadingRequest] {
        return loadingRequestList.filter { (request) -> Bool in
            return request.dataRequest != nil && !request.isCancelled && !request.isFinished
            }.filter { (request) -> Bool in
                if let dataRequest = request.dataRequest {
                    let dataRange = DataRange(uncheckedBounds: (Int64(dataRequest.requestedOffset),
                                                                upper: Int64(dataRequest.requestedOffset)+Int64(dataRequest.requestedLength)))
                    if dataRange.contains(startDataRange.lowerBound) {
                        return true
                    }
                }
                return false
        }
    }
    
    fileprivate func handleFetchedData(_ data: Data, at range: DataRange) {
        var startDataRange = range
        var startData = data
        if !bufferDataRange.isEmpty {
            startDataRange = bufferDataRange.rangeAdd(range)
            startData = bufferData
            startData.append(data)
        }
        let startLowerBound: Int64 = startDataRange.lowerBound
        var rangeTaken: DataRange = DataRange(uncheckedBounds: (lower: 0, upper: 0))
        print("start range: \(startDataRange)")
        
        let rangeRequestList = filterCurrentRequest(startDataRange)
        
        for request in rangeRequestList {
            if let dataRequest = request.dataRequest {
                let dataRange = DataRange(uncheckedBounds: (Int64(dataRequest.requestedOffset), upper: Int64(dataRequest.requestedOffset)+Int64(dataRequest.requestedLength)))
                if let neededRange = dataRange.rangeClamped(startDataRange) {
                    print("needed range: \(neededRange) -- \(dataRange)")
                    dataRequest.respond(with: startData.subdata(in: neededRange.rangeStartFrom(Int(startLowerBound))))
                    if neededRange.upperBound == dataRange.upperBound {
                        request.finishLoading()
                    }
                    removeRequest()
                    if rangeTaken.isEmpty {
                        rangeTaken = neededRange
                    } else {
                        rangeTaken = rangeTaken.rangeAdd(neededRange)
                    }
                    if !startDataRange.isEmpty {
                        print("range left: \(startDataRange)")
                    }
                }
            }
        }
        startDataRange = startDataRange.rangeDecrease(rangeTaken)
        if !startDataRange.isEmpty {
            bufferData = startData.subdata(in: startDataRange.rangeStartFrom(Int(startLowerBound)))
            bufferDataRange = startDataRange
        } else {
            bufferData = Data()
            bufferDataRange = DataRange(uncheckedBounds: (lower: 0, upper: 0))
        }
    }
    
    fileprivate func handleRequestAfterFullyDownloaded() {
        for request in loadingRequestList {
            if let infoRequest = request.contentInformationRequest, let info = cacheFileHandler?.savedCacheData.fileInfo {
                infoRequest.contentType = info.contentType
                infoRequest.contentLength = Int64(info.contentLength)
                infoRequest.isByteRangeAccessSupported = info.byteRangeAccessSupported
                request.finishLoading()
            } else if let dataRequest = request.dataRequest, request.contentInformationRequest == nil {
                let dataRange = DataRange(uncheckedBounds: (Int64(dataRequest.currentOffset), upper: Int64(dataRequest.currentOffset)+Int64(dataRequest.requestedLength)))
                if let data = cacheFileHandler?.readData(dataRange) {
                    dataRequest.respond(with: data)
                    request.finishLoading()
                }
            }
        }
        removeRequest()
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
        if onSingleRequestModel {
            createFileHandler(loadingRequest)
            loadingRequestList.append(loadingRequest)
            guard let fileHandler = cacheFileHandler else {
                return false
            }
            if !fileHandler.fullyDownloaded {
                if loadingRequest.contentInformationRequest != nil {
                    cacheFileHandler?.startLoadFullData()
                }
            } else {
                handleRequestAfterFullyDownloaded()
            }
        } else {
            if currentLoadingRequest == nil {
                Cache_Print("loader loading request direcly", level: LogLevel.resource)
                processCurrentRequest(loadingRequest: loadingRequest)
            }
            if onSeeking {
                seekingRequestList.append(loadingRequest)
            } else {
                loadingRequestList.append(loadingRequest)
            }
        }

        task?.cancel()
        print("__________________________________")
        print(loadingRequestList.count)
        if let dataRequest = loadingRequest.dataRequest {
            print("\(dataRequest.requestedOffset) ==== \(Int64(dataRequest.requestedLength)+dataRequest.requestedOffset)")
        }
        print("__________________________________")
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

