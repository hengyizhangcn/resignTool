//
//  main.swift
//  resignTool
//
//  Created by zhy on 2018/11/6.
//  Copyright © 2018 zhy. All rights reserved.
//

import Foundation

/// 执行命令行
///
/// - Parameters:
///   - launchPath: 命令行启动路径
///   - arguments: 命令行参数
/// - Returns: 命令行执行结果
func runCommand(launchPath: String, arguments: [String]) -> String {
    let pipe = Pipe()
    let file = pipe.fileHandleForReading
    
    let task = Process()
    task.launchPath = launchPath
    task.arguments = arguments
    task.standardOutput = pipe
    task.launch()
    
    let data = file.readDataToEndOfFile()
    return String(data: data, encoding: String.Encoding.utf8)!
}

let arguments = CommandLine.arguments

if arguments.count > 0 {
    
    let mobileprovisionPath = arguments[1]
    
    let s = runCommand(launchPath: "/usr/bin/security", arguments: ["cms", "-D", "-i", mobileprovisionPath])

    let mobileprovisionData = s.data(using: String.Encoding.utf8)!
    
    let datasourceDictionary = try PropertyListSerialization.propertyList(from: mobileprovisionData, options: [], format: nil)
    
    print(datasourceDictionary)
}

print(arguments)
