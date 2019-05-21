//
//  CacheFileHandler.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/2.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit
import MobileCoreServices

protocol FileDataDelegate: class {
    func fileHandlerGetResponse(fileInfo info: CacheFileInfo, response: URLResponse?)
    func fileHandler(didFetch data: Data, at range: DataRange)
    func fileHandlerDidFinishFetchData(error: Error?)
}

class CacheFileHandler {
    
    deinit {
        Cache_Print("deinit cache file handler", level: LogLevel.dealloc)
        forceStopCurrentProcess()
        saveCachedData()
        fileReader?.closeFile()
        fileWriter?.closeFile()
    }
    
    weak var delegate: FileDataDelegate?
    
    var fullyDownloaded: Bool {
        if let firstRange = savedCacheData.chunkList.first {
            let range = firstRange.range.upperBound - firstRange.range.lowerBound
            return range == Int(savedCacheData.fileInfo.contentLength)
        }
        return false
    }
    
    var savedCacheData: SavedCacheData = {
        let info = CacheFileInfo(contentType: "",
                                 byteRangeAccessSupported: false,
                                 contentLength: 0,
                                 downloadedContentLength: 0,
                                 downloadedTotalTime: 0)
        return SavedCacheData(chunkList: [], fileInfo: info, downloadSpeed: 0)
    }()
    
    fileprivate let fileOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    fileprivate let semaphore = DispatchSemaphore(value: 1)
    
    fileprivate lazy var downloader: CacheDownloader = {
        let d = CacheDownloader()
        d.outputDelegate = self
        return d
    }()
    
    fileprivate lazy var fileReader: FileHandle? = {
        return FileHandle(forReadingAtPath: videoPath)
    }()
    
    fileprivate lazy var fileWriter: FileHandle? = {
        return FileHandle(forWritingAtPath: videoPath)
    }()
    
    fileprivate var videoPath: String
    fileprivate var metaDataFilePath: String
    
    fileprivate var startOffSet: Int64 = 0
    fileprivate var currentChunkList: [CacheMetaData] = []
    
    fileprivate var itemURL: ItemURL = ItemURL()
    
    fileprivate var lastTime: TimeInterval = 0
    
    fileprivate var timeTake: Int64 = 0
    
    fileprivate var onPredownload: Bool = false
    
    init(videoUrl: String) {
        itemURL.baseURLString = videoUrl
        videoPath = CacheFilePathHelper.videoPath(from: videoUrl)
        metaDataFilePath = CacheFilePathHelper.videoMetaDataFile(from: videoUrl)
        readSavedCacheData()
        _ = CacheFilePathHelper.createFileAtPath(videoPath)
    }
    
    static func isFullyDownload(videoUrl: String) -> Bool {
        let metaDataFilePath = CacheFilePathHelper.videoMetaDataFile(from: videoUrl)
        guard CacheFilePathHelper.fileExistsAtPath(metaDataFilePath) else {
            return false
        }
        if let data = try? Data(contentsOf: URL(fileURLWithPath: metaDataFilePath)),
            let savedData = try? JSONDecoder().decode(SavedCacheData.self, from: data),
            let firstRange = savedData.chunkList.first {
            let range = firstRange.range.upperBound - firstRange.range.lowerBound
            return range == Int(savedData.fileInfo.contentLength)
        }
        return false
    }
    
    func perDownloadData() {
        let fileLength = Int(savedCacheData.fileInfo.contentLength)
        if fileLength != 0 {
            fetchData(at: DataRange(uncheckedBounds: (0, Int64(BasicFileData.predownloadSize))))
        } else {
            guard !FileDownlaodingManager.shared.isDownloading(itemURL.baseURLString) else {
                return
            }
            FileDownlaodingManager.shared.startDownloading(itemURL.baseURLString)
            onPredownload = true
            startOffSet = 0
            downloadFileWithRange(DataRange(uncheckedBounds: (0, 0)))
        }
    }
    
    func startLoadFullData() {
        let fileLength = savedCacheData.fileInfo.contentLength
        if fileLength != 0 {
            startOffSet = 0
            fetchData(at: DataRange(uncheckedBounds: (0, fileLength)))
        } else {
            guard !FileDownlaodingManager.shared.isDownloading(itemURL.baseURLString) else {
                return
            }
            FileDownlaodingManager.shared.startDownloading(itemURL.baseURLString)
            startOffSet = 0
            downloadFileWithRange(DataRange(uncheckedBounds: (0, 0)))
        }
    }
    
    func fetchData(at range: DataRange) {
        guard range.lowerBound < range.upperBound,
            !FileDownlaodingManager.shared.isDownloading(itemURL.baseURLString) else {
                Cache_Print("loader data not fetched", level: LogLevel.resource)
                return
        }
        Cache_Print("loader data start fetched", level: LogLevel.resource)
        FileDownlaodingManager.shared.startDownloading(itemURL.baseURLString)
        onPredownload = false
        
        defer {
            if !savedCacheData.fileInfo.isEmptyInfo() {
                delegate?.fileHandlerGetResponse(fileInfo: savedCacheData.fileInfo, response: nil)
            }
            processChunk()
        }
        
        var endRange = range
        let fileLength = Int(savedCacheData.fileInfo.contentLength)
        //        if range.upperBound - range.lowerBound > 2 && range.lowerBound == 0 {
        //            endRange = DataRange.init(uncheckedBounds: (0, max(range.lowerBound, fileLength)))
        //        } else
        if fileLength != 0 && range.upperBound > fileLength {
            endRange = DataRange.init(uncheckedBounds: (range.lowerBound, Int64(fileLength)))
        }
        currentChunkList = savedCacheData.readChunkList(savedCacheData.chunkList, range: endRange)
        
    }
    
    func forceStopCurrentProcess() {
        currentChunkList = []
        downloader.stopDownload()
        saveCachedData()
        FileDownlaodingManager.shared.endDownloading(itemURL.baseURLString)
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil) as Error
        delegate?.fileHandlerDidFinishFetchData(error: error)
    }
    
    func stopAndFetch(at range: DataRange) {
        forceStopCurrentProcess()
        fetchData(at: range)
    }
    
    fileprivate func processChunk(_ error: Error? = nil) {
        guard let chunk = currentChunkList.first else {
            fileOperationQueue.addOperation { [weak self] in
                guard let strongSelf = self else { return }
                Cache_Print("data chunk process finish", level: LogLevel.file)
                strongSelf.saveCachedData()
                FileDownlaodingManager.shared.endDownloading(strongSelf.itemURL.baseURLString)
                Cache_Print("delegate can call \(String(describing: strongSelf.delegate))", level: LogLevel.file)
                strongSelf.delegate?.fileHandlerDidFinishFetchData(error: error)
            }
            return
        }
        startOffSet = chunk.range.lowerBound
        currentChunkList.removeFirst()
        if chunk.type == .local {
            readFileWithRange(chunk.range)
            processChunk()
        } else {
            downloadFileWithRange(chunk.range)
        }
    }
    
    fileprivate func downloadFileWithRange(_ range: DataRange) {
        guard let url = itemURL.url else {
            return
        }
        setStartTime()
        downloader.startDownload(from: url, at: range)
    }
    
    func readData(_ range: DataRange) -> Data? {
        guard let reader = fileReader else {
            return nil
        }
        reader.seek(toFileOffset: UInt64(range.lowerBound))
        return reader.readData(ofLength: Int(range.upperBound-range.lowerBound))
    }
    
    fileprivate func readFileWithRange(_ range: DataRange) {
        guard let reader = fileReader else {
            return
        }
        var data = Data()
        fileOperationQueue.addOperation { [weak self] in
            reader.seek(toFileOffset: UInt64(range.lowerBound))
            data = reader.readData(ofLength: Int(range.upperBound-range.lowerBound))
            Cache_Print("data fetched on local: \(data.count)", level: LogLevel.file)
            self?.delegate?.fileHandler(didFetch: data, at: range)
        }
    }
    
    fileprivate func writeData(_ data: Data, to range: DataRange) {
        guard let writer = fileWriter else {
            return
        }
        fileOperationQueue.addOperation { [weak self] in
            guard let strongSelf = self else {
                return
            }
            writer.seek(toFileOffset: UInt64(range.lowerBound))
            writer.write(data)
            strongSelf.countSpeed(Int64(data.count))
            strongSelf.savedCacheData.fileInfo.downloadedTotalTime += strongSelf.timeTake
            strongSelf.saveRange(range)
            strongSelf.delegate?.fileHandler(didFetch: data, at: range)
        }
    }
    
    fileprivate func saveRange(_ range: DataRange) {
        let metaData = CacheMetaData(type: .local, range: range)
        savedCacheData.inserRangeToList(&savedCacheData.chunkList, rr: metaData)
    }
    
    fileprivate func setStartTime() {
        lastTime = Date().timeIntervalSince1970
    }
    
    fileprivate func countSpeed(_ bytes: Int64) {
        let currentTime = Date().timeIntervalSince1970
        timeTake = Int64(max(currentTime - lastTime, 0)*1000)
        if timeTake > 0 {
            savedCacheData.downloadSpeed = Int(bytes/(timeTake))
            lastTime = currentTime
            Cache_Print("download speed: \(savedCacheData.downloadSpeed)", level: LogLevel.file)
        }
    }
    
}

extension CacheFileHandler: SessionOutputDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        let needResponse = savedCacheData.fileInfo.isEmptyInfo()
        readCacheFileInfo(from: response)
        if needResponse {
            delegate?.fileHandlerGetResponse(fileInfo: savedCacheData.fileInfo, response: response)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Cache_Print("data fetched on remote: \(data.count)", level: LogLevel.file)
        guard !(startOffSet == 0 && data.count <= 2) else {
            return
        }
        writeData(data, to: DataRange(uncheckedBounds: (startOffSet, startOffSet+Int64(data.count))))
        startOffSet = startOffSet+Int64(data.count)
        if startOffSet >= BasicFileData.predownloadSize && onPredownload {
            downloader.stopDownload()
            processChunk()
            onPredownload = false
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let e = error as NSError?, e.code == NSURLErrorCancelled {
            print(e)
            return
        }
        processChunk(error)
    }
}

// MARK: - meta data reader writer
extension CacheFileHandler {
    fileprivate func readCacheFileInfo(from response: URLResponse) {
        guard savedCacheData.fileInfo.isEmptyInfo(), let r = response as? HTTPURLResponse else {
            return
        }
        if let mimeType = r.mimeType,
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)?.takeRetainedValue() {
            savedCacheData.fileInfo.contentType = uti as String
        }
        if let accept = r.allHeaderFields["Accept-Ranges"] as? String, accept == "bytes" {
            savedCacheData.fileInfo.byteRangeAccessSupported = true
        }
        if let range = r.allHeaderFields["Content-Range"] as? String, range.contains("bytes") {
            savedCacheData.fileInfo.byteRangeAccessSupported = true
        }
        if let range = r.allHeaderFields["content-range"] as? String,
            let totalRange = range.split(separator: "/").last,
            let length = Int64(String(totalRange)) {
            savedCacheData.fileInfo.contentLength = length
        } else if let range = r.allHeaderFields["Content-Range"] as? String,
            let totalRange = range.split(separator: "/").last,
            let length = Int64(String(totalRange)) {
            savedCacheData.fileInfo.contentLength = length
        } else if let range = r.allHeaderFields["Content-Length"] as? String,
            let length = Int64(String(range)) {
            savedCacheData.fileInfo.contentLength = length
        }
    }
    
    fileprivate func readSavedCacheData() {
        guard CacheFilePathHelper.fileExistsAtPath(metaDataFilePath),
            CacheFilePathHelper.fileExistsAtPath(videoPath) else {
                return
        }
        let fileLength = CacheFilePathHelper.fileSizeAtPath(videoPath)
        if let data = try? Data(contentsOf: URL(fileURLWithPath: metaDataFilePath)),
            let savedData = try? JSONDecoder().decode(SavedCacheData.self, from: data),
            savedData.fileInfo.downloadedContentLength == fileLength {
            savedCacheData = savedData
        } else {
            _ = CacheFilePathHelper.removeFileAtPath(metaDataFilePath)
            _ = CacheFilePathHelper.removeFileAtPath(videoPath)
        }
    }
    
    fileprivate func saveCachedData() {
        do {
            let data = try JSONEncoder().encode(savedCacheData)
            if CacheFilePathHelper.fileExistsAtPath(metaDataFilePath) {
                _ = CacheFilePathHelper.removeFileAtPath(metaDataFilePath)
            }
            try data.write(to: URL(fileURLWithPath: metaDataFilePath))
        } catch let error {
            Cache_Print("\(error.localizedDescription)", level: LogLevel.file)
        }
    }
}
