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
"       if the version is not set, and 1 will be automatically added to the last of version components which separated by charater '.'.\n" +
"  Please contact if you have some special demmands."

var ipaPath: String?
var mobileprovisionPath: String?
var newVersion: String?

/// execute the command and get the result
///
/// - Parameters:
///   - launchPath: the full path of the command
///   - arguments: arguments
/// - Returns: command execute result
@discardableResult
func runCommand(launchPath: String, arguments: [String]) -> Data {
    let pipe = Pipe()
    let file = pipe.fileHandleForReading
    
    let task = Process()
    task.launchPath = launchPath
    task.arguments = arguments
    task.standardOutput = pipe
    task.launch()
    
    let data = file.readDataToEndOfFile()
    
    task.terminate()
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

/// config app version
///
/// - Parameter appPath: the path of the app
func configNewVersion(_ appPath: String) {
    
    //        let dict =
    let plistPath = appPath + "/Info.plist"
    let plistXML = FileManager.default.contents(atPath: plistPath)!
    do {
        //read plist file to dictionary
        var plistDict = try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: nil) as! [String: Any]
        
        if newVersion == nil,
            let shortVersion = plistDict["CFBundleShortVersionString"] as? String{
            
            var versionArray = shortVersion.components(separatedBy: ".")
            if versionArray.count > 0,
                let lastComponent = versionArray.last {
                versionArray[versionArray.count-1] = String(Int(lastComponent)! + 1)
                
                newVersion = versionArray.joined(separator: ".")
            }
        }
        
        if newVersion == nil {
            newVersion = "1.0.0"
        }
        
        plistDict["CFBundleShortVersionString"] = newVersion!
        plistDict["CFBundleVersion"] = newVersion!
        
        if let plistOutputStream = OutputStream.init(toFileAtPath: plistPath, append: false) {
            
            //should keep the outputstream open
            plistOutputStream.schedule(in: RunLoop.current, forMode: .default)
            plistOutputStream.open()
            
            //write the new plist content to file
            PropertyListSerialization.writePropertyList(plistDict, to: plistOutputStream, format: PropertyListSerialization.PropertyListFormat.xml, options: 0, error: nil)
        }
    } catch {
        print(error)
    }
}

/// print help
func showHelp() {
    print(help)
    terminate()
}

/// terminate process
func terminate() {
    exit(0)
}

let arguments = CommandLine.arguments

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
                ipaPath = arguments[i + 1]
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
if ipaPath == nil {
    print("The path of .ipa file doesnot exist, please point it out")
    terminate()
}

//clear payload directory
runCommand(launchPath: "/bin/rm", arguments: ["-rf", "Payload"])
runCommand(launchPath: "/bin/rm", arguments: ["-rf", "entitlements.plist"])

//unzip .ipa file
runCommand(launchPath: "/usr/bin/unzip", arguments: [ipaPath!])

//codesign -d --entitlements - SmartHeda.app

//abstract entitlement
let appPath = enumeratePayloadApp()
runCommand(launchPath: "/usr/bin/codesign", arguments: ["-d", "--entitlements", "entitlements.plist", appPath])

let manager = FileManager.default
let plistFilePath = manager.currentDirectoryPath + "/entitlements.plist"

do {
    let fileUrl = URL.init(fileURLWithPath: plistFilePath)
    var entitleData = try Data.init(contentsOf: fileUrl)
    entitleData.removeSubrange(0..<8) //前8个字节为未知无用字节，需截除
    
    try entitleData.write(to: fileUrl)
} catch {
    print(error)
}

//set the app version
configNewVersion(appPath)

//Remove old CodeSignature, can be ignored
//runCommand(launchPath: "/bin/rm", arguments: ["-rf", appPath + "_CodeSignature"])


var TeamName: String?
if mobileprovisionPath != nil {
    let mobileprovisionData = runCommand(launchPath: "/usr/bin/security", arguments: ["cms", "-D", "-i", mobileprovisionPath!])
    
    let datasourceDictionary = try PropertyListSerialization.propertyList(from: mobileprovisionData, options: [], format: nil)
    
    if let dict = datasourceDictionary as? Dictionary<String, Any> {
        TeamName = dict["TeamName"] as? String
    }
    
    //replace embedded.mobileprovision
    runCommand(launchPath: "/bin/cp", arguments: [mobileprovisionPath!, appPath + "/embedded.mobileprovision"])
    
} else {
    //if appPath + "/embedded.mobileprovision" doesnot exist, read team name from the app
    let mobileprovisionData = runCommand(launchPath: "/usr/bin/security", arguments: ["cms", "-D", "-i", appPath + "/embedded.mobileprovision"])
    
    let datasourceDictionary = try PropertyListSerialization.propertyList(from: mobileprovisionData, options: [], format: nil)
    
    if let dict = datasourceDictionary as? Dictionary<String, Any> {
        TeamName = dict["TeamName"] as? String
    }
}

//resign
let teamNameCombinedStr = "iPhone Distribution: " + TeamName!

runCommand(launchPath: "/usr/bin/codesign", arguments: ["-fs", teamNameCombinedStr, "--entitlements", plistFilePath, appPath])

//codesign -vv -d SmartHeda.app
runCommand(launchPath: "/usr/bin/codesign", arguments: ["-vv", "-d", appPath])

//repacked app
//zip -r SmartHeda.ipa Payload/
let ipaName = URL.init(fileURLWithPath: ipaPath!).lastPathComponent

try manager.createDirectory(atPath: manager.currentDirectoryPath + "/new App/", withIntermediateDirectories: true, attributes: [:])
runCommand(launchPath: "/usr/bin/zip", arguments: ["-r", manager.currentDirectoryPath + "/new App/" + ipaName , "Payload/"])

//remove middle files and directionary
runCommand(launchPath: "/bin/rm", arguments: ["-rf", "Payload"])
runCommand(launchPath: "/bin/rm", arguments: ["-rf", "entitlements.plist"])

print("Done!")

//2018/11/9 finished
