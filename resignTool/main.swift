//
//  main.swift
//  resignTool
//
//  Created by zhy on 2018/11/6.
//  Copyright © 2018 zhy. All rights reserved.
//

import Foundation

//
let help =
"  version: 1.0\n" +
"  usage: resignTool [-h] [-i <path>] [-m <path>] [-v <version>]\n" +
"  -h   this help.\n" +
"  -i   the path of .ipa file.\n" +
"  -m   the path of .mobileprovision file.\n" +
"  -v   the new version of the app.\n" +
"       if the version is not set, and 0.0.1 will be automatically added to the origin version.\n" +
"  Please contact if you have some special demmands."


/// execute the command
///
/// - Parameters:
///   - launchPath: the full path of the command
///   - arguments: arguments
func runCommandWithoutResult(launchPath: String, arguments: [String], pipe: Pipe?) {
    let task = Process()
    task.launchPath = launchPath
    task.arguments = arguments
    task.standardOutput = pipe
    task.launch()
}

/// execute the command and get the result
///
/// - Parameters:
///   - launchPath: the full path of the command
///   - arguments: arguments
/// - Returns: command execute result
func runCommand(launchPath: String, arguments: [String]) -> Data {
    let pipe = Pipe()
    let file = pipe.fileHandleForReading
    
    runCommandWithoutResult(launchPath: launchPath, arguments: arguments, pipe: pipe)
    
    let data = file.readDataToEndOfFile()
    return data
}

/// enumerate Payload directory, find out the .app file
///
/// - Returns: .app file name
func enumeratePayloadApp() -> String {
    let manager = FileManager.default
    do {
        let contents = try manager.contentsOfDirectory(atPath: "Payload")
        for fileName in contents {
            if fileName.contains(".app") {
                return manager.currentDirectoryPath + "/Payload/" + fileName
            }
        }
        print("The .app file not exist!")
        terminate()
    } catch {
        print("Error occurs")
        terminate()
    }
    return ""
}

/// print help
func showHelp() {
    print(help)
}

/// terminate process
func terminate() {
    exit(0)
}

let arguments = CommandLine.arguments

var appPath: String?
var mobileprovisionPath: String?
var newVersion: String?

//analysize user's input
for i in 1..<arguments.count {
    
    let arg = arguments[i]
    
    switch (arg) {
        case "-m":
            if arguments.count > i {
                mobileprovisionPath = arguments[i + 1]
            }
            break
        case "-i":
            if arguments.count > i {
                appPath = arguments[i + 1]
            }
            break
        case "-v":
            if arguments.count > i {
                newVersion = arguments[i + 1]
            }
            break
        case "-h":
            showHelp()
        case "-":
            print("bad option:"+arg)
            terminate()
        default:
            break;
    }
}

//check user's input
if appPath == nil {
    print("The path of .ipa file doesnot exist, please point it out")
    terminate()
} else if mobileprovisionPath == nil &&  newVersion == nil{
    print("I don't know what to do, Commander! Confusing....")
    terminate()
}

//clear payload directory
runCommandWithoutResult(launchPath: "/bin/rm", arguments: ["-rf", "Payload"], pipe: nil)
runCommandWithoutResult(launchPath: "/bin/rm", arguments: ["-rf", "tmp_entitlements.plist"], pipe: nil)

//unzip .ipa file
runCommandWithoutResult(launchPath: "/usr/bin/unzip", arguments: [appPath!], pipe: nil)

//codesign -d --entitlements - SmartHeda.app

//abstract entitlement
runCommandWithoutResult(launchPath: "/usr/bin/codesign", arguments: ["-d", "--entitlements", "tmp_entitlements.plist", enumeratePayloadApp()], pipe: nil)

if mobileprovisionPath != nil {
    let mobileprovisionData = runCommand(launchPath: "/usr/bin/security", arguments: ["cms", "-D", "-i", mobileprovisionPath!])
    
    let datasourceDictionary = try PropertyListSerialization.propertyList(from: mobileprovisionData, options: [], format: nil)
    
    print(datasourceDictionary)
}

//print(arguments)
