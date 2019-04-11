//
//  CachePrinter.swift
//  PlayerCache
//
//  Created by Stephen zake on 2019/4/1.
//  Copyright © 2019 Stephen.Zeng. All rights reserved.
//

import Foundation

func Cache_Print<T>(_ message: T, level: LogLevel,file: String = #file, method: StaticString = #function, line: UInt = #line) {
    #if DEBUG
    guard BasicFileData.logLevel.rawValue >= level.rawValue else { return }
    print("Cache output : \n[\(line)], \(method): \(message) \n ")// --> at thread: \(Thread.current) \n  --> at time: \(Date()) \n")
    #endif
}


func Cache_Warning<T>(_ message: T, level: LogLevel, file: String = #file, method: StaticString = #function, line: UInt = #line) {
    #if DEBUG
    guard BasicFileData.logLevel.rawValue >= level.rawValue else { return }
    print("Cache warning : \n!!!WARNING!!! \n  -->\(URL(fileURLWithPath: file).lastPathComponent) \n  -->[\(line)], \(method): \(message)")
    #endif
}

