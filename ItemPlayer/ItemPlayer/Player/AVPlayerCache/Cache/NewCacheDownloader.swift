//
//  NewCacheDownloader.swift
//  OnlinePlayerDemo
//
//  Created by zeng yukai on 2021/11/16.
//

import UIKit

public protocol NewSessionOutputDelegate: AnyObject {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data)

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?)
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse)

    func urlSession(endWithDuration: TimeInterval,
                    dataSize: Int64,
                    urlString: String?)
}

class NewCacheDownloader: NSObject {
    public weak var outputDelegate: NewSessionOutputDelegate?

    public var sessionIsRuning: Bool = false

    fileprivate var session: URLSession?
    fileprivate var task: URLSessionDataTask?
    fileprivate var url: URL?

    fileprivate var date: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    fileprivate let sessionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = BasicFileData.sessionOperationQueueName
        return queue
    }()
    
    override init() {
        super.init()
        
    }
    
    fileprivate func downLoad(from url: URL, at range: DataRange) {
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
        let configuration = URLSessionConfiguration.default
        if #available(iOS 11.0, *) {
            configuration.waitsForConnectivity = false
        }
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 60
        session = URLSession(configuration: configuration,
                             delegate: self,
                             delegateQueue: sessionQueue)
        //        print("session -> created \(self) -- \(session)")
    }

    fileprivate func resetSession() {
        //        print("session -> reset \(self) -- \(session)")
        session?.invalidateAndCancel()
        session = nil
        task = nil
        url = nil
    }
}

extension NewCacheDownloader: URLSessionDelegate {
    
}


//public protocol SessionBaseOutputDelegate: AnyObject {
//}
//
//public protocol SessionForwordDelegate: SessionBaseOutputDelegate {
//    func urlSession(_ session: URLSession,
//                    didReceive challenge: URLAuthenticationChallenge,
//                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
//
//    func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didReceive response: URLResponse,
//                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
//}
//

//
//class SessionDataForworder: NSObject, URLSessionDataDelegate {
//
//    deinit {
//        Cache_Print("deinit session data forworder", level: LogLevel.dealloc)
//    }
//
//    weak var forwordDelegate: SessionForwordDelegate?
//
//    fileprivate var bufferData: Data = Data()
//
//    fileprivate let dataHandleQueue = DispatchQueue(label: BasicFileData.dataHandleQueueLabel, qos: .userInteractive)
//
//    func urlSession(_ session: URLSession,
//                    didReceive challenge: URLAuthenticationChallenge,
//                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//        forwordDelegate?.urlSession(session,
//                                    didReceive: challenge,
//                                    completionHandler: completionHandler)
//    }
//
//    func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didReceive response: URLResponse,
//                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        dataHandleQueue.async {
//            self.forwordDelegate?.urlSession(session,
//                                             dataTask: dataTask,
//                                             didReceive: response,
//                                             completionHandler: completionHandler)
//        }
//    }
//
//    func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didReceive data: Data) {
//        dataHandleQueue.async {
//            Cache_Print("session data receive: \(data.count)", level: LogLevel.net)
//            self.bufferData.append(data)
//            guard self.bufferData.count > BasicFileData.bufferSize else {
//                return
//            }
//            Cache_Print("buffer data size: \(self.bufferData.count)", level: LogLevel.net)
//            let forwordData = self.bufferData
//            let range = Range<Data.Index>.init(uncheckedBounds: (0, self.bufferData.count))
//            self.bufferData.replaceSubrange(range, with: Data())
//            Cache_Print("after clear buffer data size: \(self.bufferData.count)", level: LogLevel.net)
//            self.forwordDelegate?.urlSession(session, dataTask: dataTask, didReceive: forwordData)
//        }
//    }
//
//    func urlSession(_ session: URLSession,
//                    task: URLSessionTask,
//                    didCompleteWithError error: Error?) {
//        dataHandleQueue.async {
//            Cache_Print("session data finish receive", level: LogLevel.net)
//            guard self.bufferData.count > 0 else {
//                self.forwordDelegate?.urlSession(session, task: task, didCompleteWithError: error)
//                return
//            }
//            Cache_Print("buffer data size: \(self.bufferData.count)", level: LogLevel.net)
//            let forwordData = self.bufferData
//            let range = Range<Data.Index>.init(uncheckedBounds: (0, self.bufferData.count))
//            self.bufferData.replaceSubrange(range, with: Data())
//            Cache_Print("after clear buffer data size: \(self.bufferData.count)", level: LogLevel.net)
//            self.forwordDelegate?.urlSession(session, dataTask: task as! URLSessionDataTask, didReceive: forwordData)
//            self.forwordDelegate?.urlSession(session, task: task, didCompleteWithError: error)
//        }
//    }
//
//    func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    willCacheResponse proposedResponse: CachedURLResponse,
//                    completionHandler: @escaping (CachedURLResponse?) -> Void) {
//        completionHandler(proposedResponse)
//    }
//
//    func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didBecome downloadTask: URLSessionDownloadTask) {
//        print("data task become download task")
//    }
//
//    func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didBecome streamTask: URLSessionStreamTask) {
//
//    }
//
//}
//
//extension Notification.Name {
//    // 预加载控制
//    static let PauseDownload = Notification.Name("PauseDownloadOnVSKitDownloadVideo")
//    static let ResumeDownload = Notification.Name("ResumeDownloadOnVSKitDownloadVideo")
//}
//
//public class CacheDownloader: NSObject {
//    deinit {
//        resetSession()
//        NotificationCenter.default.removeObserver(self)
//        Cache_Print("deinit cache downloader", level: LogLevel.dealloc)
//    }
//

//
//    fileprivate lazy var sessionDataForworder: SessionDataForworder = {
//        let forworder = SessionDataForworder()
//        forworder.forwordDelegate = self
//        return forworder
//    }()
//

//
//    fileprivate let SessionStatusQueue = DispatchQueue(label: "Session.Status.Queue",
//                                                       qos: .userInteractive)
//
//    fileprivate var cancel: Bool = false
//
//    public override init() {
//        super.init()
//        NotificationCenter.default.addObserver(self, selector: #selector(self.pauseCurrentTask), name: .PauseDownload, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(self.resumeCurrentTask), name: .ResumeDownload, object: nil)
//    }
//
//    public func stopDownload() {
//        SessionStatusQueue.async {
//            self.resetSession()
//        }
//    }
//
//    public func startDownload(from url: URL, at range: DataRange) {
//        SessionStatusQueue.async {
//            self.resetSession()
//            self.createSession()
//            self.downLoad(from: url, at: range)
//        }
//    }
//
//    @objc fileprivate func pauseCurrentTask() {
//        SessionStatusQueue.async {
//            self.task?.suspend()
//        }
//    }
//
//    @objc fileprivate func resumeCurrentTask() {
//        SessionStatusQueue.async {
//            self.task?.resume()
//        }
//    }
//

//
//    fileprivate func checkMimeType(_ type: String) -> Bool {
//        if type.contains("video/") || type.contains("audio/") || type.contains("application") {
//            return true
//        } else {
//            return false
//        }
//    }
//
//}
//
//extension CacheDownloader: SessionForwordDelegate {
//    public func urlSession(_ session: URLSession,
//                    didReceive challenge: URLAuthenticationChallenge,
//                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//        if let trust = challenge.protectionSpace.serverTrust {
//            let card = URLCredential(trust: trust)
//            completionHandler(URLSession.AuthChallengeDisposition.useCredential, card)
//        } else {
//            Cache_Print("authentication fail on request", level: LogLevel.net)
//            completionHandler(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
//        }
//    }
//
//    public func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didReceive response: URLResponse,
//                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        if let mimeType = response.mimeType, checkMimeType(mimeType) {
//            completionHandler(URLSession.ResponseDisposition.allow)
//            outputDelegate?.urlSession(session, dataTask: dataTask, didReceive: response)
//        } else {
//            Cache_Print("response cancel on mime type: \(String(describing: response.mimeType))", level: LogLevel.net)
//            completionHandler(URLSession.ResponseDisposition.cancel)
//        }
//    }
//
//    public func urlSession(_ session: URLSession,
//                    dataTask: URLSessionDataTask,
//                    didReceive data: Data) {
//        outputDelegate?.urlSession(session,
//                                   dataTask: dataTask,
//                                   didReceive: data)
//    }
//
//    public func urlSession(_ session: URLSession,
//                    task: URLSessionTask,
//                    didCompleteWithError error: Error?) {
//        Cache_Print("finish download: \(error?.localizedDescription ?? "no error")", level: LogLevel.net)
//        outputDelegate?.urlSession(session, task: task, didCompleteWithError: error)
//        let endTime = CFAbsoluteTimeGetCurrent()
//        let duration = round((endTime-self.date)*1000)/1000
//        let data = task.countOfBytesReceived/1024
//        outputDelegate?.urlSession(endWithDuration: duration,
//                                   dataSize: data,
//                                   urlString: task.currentRequest?.url?.absoluteString)
//    }
//}

