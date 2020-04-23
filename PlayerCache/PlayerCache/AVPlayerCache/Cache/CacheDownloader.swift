//
//  CacheDownloader.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/2.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import UIKit

protocol SessionBaseOutputDelegate: class {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data)
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?)
}

protocol SessionForwordDelegate: SessionBaseOutputDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
}

protocol SessionOutputDelegate: SessionBaseOutputDelegate {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse)
}

class SessionDataForworder: NSObject, URLSessionDataDelegate {
    
    deinit {
        Cache_Print("deinit session data forworder", level: LogLevel.dealloc)
    }
    
    weak var forwordDelegate: SessionForwordDelegate?
    
    fileprivate var bufferData: Data = Data()
    
    fileprivate let dataHandleQueue = DispatchQueue(label: BasicFileData.dataHandleQueueLabel, qos: .userInteractive)
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        forwordDelegate?.urlSession(session,
                                    didReceive: challenge,
                                    completionHandler: completionHandler)
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        dataHandleQueue.async {
            self.forwordDelegate?.urlSession(session,
                                             dataTask: dataTask,
                                             didReceive: response,
                                             completionHandler: completionHandler)
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        dataHandleQueue.async {
            Cache_Print("session data receive: \(data.count)", level: LogLevel.net)
            self.bufferData.append(data)
            guard self.bufferData.count > BasicFileData.bufferSize else {
                return
            }
            Cache_Print("buffer data size: \(self.bufferData.count)", level: LogLevel.net)
            let forwordData = self.bufferData
            let range = Range<Data.Index>.init(uncheckedBounds: (0, self.bufferData.count))
            self.bufferData.replaceSubrange(range, with: Data())
            Cache_Print("after clear buffer data size: \(self.bufferData.count)", level: LogLevel.net)
            self.forwordDelegate?.urlSession(session, dataTask: dataTask, didReceive: forwordData)
        }
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        dataHandleQueue.async {
            Cache_Print("session data finish receive", level: LogLevel.net)
            guard self.bufferData.count > 0 else {
                self.forwordDelegate?.urlSession(session, task: task, didCompleteWithError: error)
                return
            }
            Cache_Print("buffer data size: \(self.bufferData.count)", level: LogLevel.net)
            let forwordData = self.bufferData
            let range = Range<Data.Index>.init(uncheckedBounds: (0, self.bufferData.count))
            self.bufferData.replaceSubrange(range, with: Data())
            Cache_Print("after clear buffer data size: \(self.bufferData.count)", level: LogLevel.net)
            self.forwordDelegate?.urlSession(session, dataTask: task as! URLSessionDataTask, didReceive: forwordData)
            self.forwordDelegate?.urlSession(session, task: task, didCompleteWithError: error)
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    willCacheResponse proposedResponse: CachedURLResponse,
                    completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(proposedResponse)
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didBecome downloadTask: URLSessionDownloadTask) {
        
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didBecome streamTask: URLSessionStreamTask) {
        
    }
    
}

class CacheDownloader: NSObject {
    deinit {
        NotificationCenter.default.removeObserver(self)
        Cache_Print("deinit cache downloader", level: LogLevel.dealloc)
    }
    
    weak var outputDelegate: SessionOutputDelegate?
    
    fileprivate var session: URLSession?
    fileprivate var task: URLSessionDataTask?
    fileprivate var url: URL?
    
    fileprivate var date: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    fileprivate lazy var sessionDataForworder: SessionDataForworder = {
        let forworder = SessionDataForworder()
        forworder.forwordDelegate = self
        return forworder
    }()
    
    fileprivate let sessionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = BasicFileData.sessionOperationQueueName
        return queue
    }()
    
    fileprivate var cancel: Bool = false
    
    override init() {
        super.init()
//        NotificationCenter.default.addObserver(self, selector: #selector(self.pauseCurrentTask), name: .PauseDownload, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(self.resumeCurrentTask), name: .ResumeDownload, object: nil)
    }
    
    @objc fileprivate func pauseCurrentTask() {
        task?.suspend()
    }
    
    @objc fileprivate func resumeCurrentTask() {
        task?.resume()
    }
    
    func stopDownload() {
        let operation = BlockOperation { [weak self] in
            self?.cancel = true
            self?.resetSession()
        }
        operation.queuePriority = .veryHigh
        sessionQueue.addOperation(operation)
    }
    
    func startDownload(from url: URL, at range: DataRange) {
        resetSession()
        createSession()
        self.url = url
        var request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 20)
        if !range.isEmpty {
            let rangeString = "bytes=\(range.lowerBound)-\(range.upperBound-1)"
            request.setValue(rangeString, forHTTPHeaderField: "Range")
        }
        task = session?.dataTask(with: request)
        task?.resume()
        date = CFAbsoluteTimeGetCurrent()
    }
    
    fileprivate func createSession() {
        cancel = false
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 60
        session = URLSession(configuration: configuration, delegate: sessionDataForworder, delegateQueue: sessionQueue)
    }
    
    fileprivate func resetSession() {
        session?.invalidateAndCancel()
        session = nil
        task = nil
        url = nil
    }
    
    fileprivate func checkMimeType(_ type: String) -> Bool {
        if type.contains("video/") || type.contains("audio/") || type.contains("application") {
            return true
        } else {
            return false
        }
    }
    
}

extension CacheDownloader: SessionForwordDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            let card = URLCredential(trust: trust)
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, card)
        } else {
            Cache_Print("authentication fail on request", level: LogLevel.net)
            completionHandler(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let mimeType = response.mimeType, checkMimeType(mimeType) {
            completionHandler(URLSession.ResponseDisposition.allow)
            outputDelegate?.urlSession(session, dataTask: dataTask, didReceive: response)
        } else {
            Cache_Print("response cancel on mime type: \(String(describing: response.mimeType))", level: LogLevel.net)
            completionHandler(URLSession.ResponseDisposition.cancel)
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        guard !cancel else {
            return
        }
        outputDelegate?.urlSession(session,
                                   dataTask: dataTask,
                                   didReceive: data)
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        outputDelegate?.urlSession(session, task: task, didCompleteWithError: error)
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = round((endTime-date)*1000)
        Cache_Print("finish download: \(error?.localizedDescription ?? "no error")", level: LogLevel.net)
        Cache_Print("finish download: duration \(duration)ms bytes \(task.countOfBytesReceived)", level: LogLevel.net)
    }
}
