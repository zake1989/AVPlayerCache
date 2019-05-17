//
//  CacheFileHelper.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/1.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import Foundation
import UIKit

class CacheFilePathHelper: NSObject {
    
    private static var cachesDataStore: String = {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return paths[0]
    }()
    
    private class func cachesDataStoreWithRootFolder(_ folderName: String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return paths[0].appendingPathComponentOnFile(folderName)
    }
    
    public static var playerCacheStore: String = {
        let path = cachesDataStoreWithRootFolder("PlayerCacheFile")
        if !directoryExistAtPath(path) {
            _ = createDirectoryAtPath(path)
        }
        return path
    }()
    
    open class func videoPath(from url: String) -> String {
        return urlDirectory(url).appendingPathComponentOnFile("video.mp4")
    }
    
    open class func videoMetaDataFile(from url: String) -> String {
        return urlDirectory(url).appendingPathComponentOnFile("metadata.dmc")
    }
    
    open class func urlDirectory(_ url: String) -> String {
        let dirName: String = url.vmd5()
        let endDir = playerCacheStore.appendingPathComponentOnFile(dirName)
        if !directoryExistAtPath(endDir) {
            _ = createDirectoryAtPath(endDir)
            DispatchQueue.global().async {
                clearHalfCache()
            }
        }
        return endDir
    }
    
    open class func fileExistsAtPath(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    open class func directoryExistAtPath(_ path: String) -> Bool {
        var isDir : ObjCBool = false
        let fileExist: Bool = FileManager.default.fileExists(atPath: path, isDirectory:&isDir)
        return isDir.boolValue && fileExist
    }
    
    open class func removeVideoFile(_ url: String) -> Bool {
        let path = urlDirectory(url)
        return removeFileAtDirectory(path)
    }
    
    open class func removeFileAtPath(_ path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
        }
        catch let error as NSError {
            Cache_Print("\(error.localizedDescription)", level: LogLevel.error)
            return false
        }
        return true
    }
    
    open class func removeFileAtDirectory(_ directory: String) -> Bool {
        do {
            for path in try FileManager.default.contentsOfDirectory(atPath: directory) {
                try FileManager.default.removeItem(atPath: "\(directory)" + "/" + "\(path)")
            }
        } catch let error as NSError {
            Cache_Print("\(error.localizedDescription)", level: LogLevel.error)
            return false
        }
        return true
    }
    
    open class func createFileAtPath(_ path: String) -> Bool {
        if fileExistsAtPath(path) {
            return true
        }
        return FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
    }
    
    open class func createDirectoryAtPath(_ path: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        } catch let error as NSError {
            Cache_Print("\(error.localizedDescription)", level: LogLevel.error)
            return false
        }
        return true
    }
    
    open class func readDirectoriesAtPath(_ directory: String) -> [String] {
        guard directoryExistAtPath(directory) else {
            return []
        }
        do {
            var files: [String] = []
            for path in try FileManager.default.contentsOfDirectory(atPath: directory) {
                let p = "\(directory)" + "/" + "\(path)"
                if directoryExistAtPath(p) {
                    files.append(p)
                }
            }
            return files
        } catch let error as NSError {
            Cache_Print("Error: \(error)", level: LogLevel.error)
            return []
        }
    }
    
    open class func fileSizeAtPath(_ path: String) -> Int64 {
        var fileSize : Int64 = 0
        do {
            //return [FileAttributeKey : Any]
            let attr = try FileManager.default.attributesOfItem(atPath: path)
            if let size = attr[FileAttributeKey.size] as? UInt64 {
                fileSize = Int64(size)
            }
        } catch {
            Cache_Print("Error: \(error)", level: LogLevel.error)
        }
        return fileSize
    }
    
    open class func createdDateForFile(_ path: String) -> Date {
        var date: Date = Date()
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: path)
            if let d = attr[FileAttributeKey.creationDate] as? Date {
                date = d
            }
        } catch {
            Cache_Print("Error: \(error)", level: LogLevel.error)
        }
        return date
    }
    
    open class func clearHalfCache() {
        let paths = readDirectoriesAtPath(playerCacheStore)
        guard paths.count > BasicFileData.maxCacheSize else {
            return
        }
        let sortedPath = paths.sorted { (lPath, rPath) -> Bool in
            return createdDateForFile(lPath) < createdDateForFile(rPath)
        }
        
        for item in sortedPath.enumerated() {
            if item.offset > max(paths.count-10, 10) {
                return
            } else {
                _ = removeFileAtPath(item.element)
            }
        }
    }
}

extension String {
    func appendingPathComponentOnFile(_ string: String) -> String {
        return URL(fileURLWithPath: self).appendingPathComponent(string).path
    }
    
    func vmd5() -> String {
        let str = self.cString(using: String.Encoding.utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: String.Encoding.utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        
        CC_MD5(str!, strLen, result)
        
        let hash = NSMutableString()
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.deallocate()
        
        return String(format: hash as String)
    }
}
