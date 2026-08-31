#!/usr/bin/env swift
// nowplaying.swift — Helper script run via Apple-signed /usr/bin/swift
// to access MediaRemote private framework (which requires trusted code signing).
// Outputs JSON to stdout. Called by NowPlayingService.
//
// Usage:
//   swift nowplaying.swift info      — Get current now-playing info as JSON
//   swift nowplaying.swift play      — Toggle play/pause
//   swift nowplaying.swift next      — Next track
//   swift nowplaying.swift prev      — Previous track
//   swift nowplaying.swift back15    — Skip backward 15 seconds
//   swift nowplaying.swift fwd15     — Skip forward 15 seconds
//   swift nowplaying.swift shuffle   — Toggle shuffle mode
//   swift nowplaying.swift repeat    — Toggle repeat mode
//   swift nowplaying.swift seek 90   — Seek to 90 seconds

import Foundation

guard let bundle = CFBundleCreate(kCFAllocatorDefault,
    NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) else {
    fputs("{\"error\":\"framework_not_found\"}\n", stderr)
    exit(1)
}

func loadFunc<T>(_ name: String) -> T? {
    guard let ptr = CFBundleGetFunctionPointerForName(bundle, name as CFString) else { return nil }
    return unsafeBitCast(ptr, to: T.self)
}

func doubleValue(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? NSNumber { return value.doubleValue }
    if let value = value as? String { return Double(value) }
    return nil
}

func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? NSNumber { return value.intValue }
    if let value = value as? String { return Int(value) }
    return nil
}

func boolValue(_ value: Any?) -> Bool? {
    if let value = value as? Bool { return value }
    if let value = value as? NSNumber { return value.boolValue }
    if let value = value as? String {
        switch value.lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default: return nil
        }
    }
    return nil
}

typealias GetInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
typealias SendCmdFunc = @convention(c) (UInt32, NSDictionary?) -> Bool
typealias GetPlayingFunc = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
typealias GetPIDFunc = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
typealias SetElapsedTimeFunc = @convention(c) (Double) -> Void

let getInfo: GetInfoFunc? = loadFunc("MRMediaRemoteGetNowPlayingInfo")
let sendCmd: SendCmdFunc? = loadFunc("MRMediaRemoteSendCommand")
let getPlaying: GetPlayingFunc? = loadFunc("MRMediaRemoteGetNowPlayingApplicationIsPlaying")
let getPID: GetPIDFunc? = loadFunc("MRMediaRemoteGetNowPlayingApplicationPID")
let setElapsedTime: SetElapsedTimeFunc? = loadFunc("MRMediaRemoteSetElapsedTime")

let command = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "info"

switch command {
case "play":
    let r = sendCmd?(2, nil) ?? false
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "next":
    let r = sendCmd?(4, nil) ?? false
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "prev":
    let r = sendCmd?(5, nil) ?? false
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "back15":
    let r = sendCmd?(12, nil) ?? false
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "fwd15":
    let r = sendCmd?(13, nil) ?? false
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "shuffle":
    let r = sendCmd?(6, nil) ?? false
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "repeat":
    let r = sendCmd?(7, nil) ?? false
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "seek":
    guard let setElapsedTime else {
        print("{\"error\":\"seek_unavailable\"}")
        exit(1)
    }
    guard CommandLine.arguments.count > 2,
          let seconds = Double(CommandLine.arguments[2]),
          seconds >= 0 else {
        print("{\"error\":\"invalid_seek_time\"}")
        exit(1)
    }
    setElapsedTime(seconds)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":true}")
    exit(0)

case "info":
    guard let getInfo else {
        print("{\"error\":\"function_not_found\"}")
        exit(1)
    }

    var gotPlaying = false
    var isPlaying = false
    var gotPID = false
    var sourcePID: Int32 = 0

    getPlaying?(DispatchQueue.main) { playing in
        isPlaying = playing
        gotPlaying = true
    }

    getPID?(DispatchQueue.main) { pid in
        sourcePID = pid
        gotPID = true
    }

    getInfo(DispatchQueue.main) { info in
        if !gotPlaying || !gotPID {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        var out: [String: Any] = [:]
        out["title"] = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        out["artist"] = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        out["album"] = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        out["duration"] = doubleValue(info["kMRMediaRemoteNowPlayingInfoDuration"]) ?? 0
        out["elapsed"] = doubleValue(info["kMRMediaRemoteNowPlayingInfoElapsedTime"]) ?? 0
        out["rate"] = doubleValue(info["kMRMediaRemoteNowPlayingInfoPlaybackRate"]) ?? 0
        out["repeatMode"] = intValue(info["kMRMediaRemoteNowPlayingInfoRepeatMode"]) ?? 1
        out["shuffleMode"] = intValue(info["kMRMediaRemoteNowPlayingInfoShuffleMode"]) ?? 1
        out["supportsBack15"] = boolValue(info["kMRMediaRemoteNowPlayingInfoSupportsRewind15Seconds"]) ?? false
        out["supportsForward15"] = boolValue(info["kMRMediaRemoteNowPlayingInfoSupportsFastForward15Seconds"]) ?? false
        out["queueIndex"] = intValue(info["kMRMediaRemoteNowPlayingInfoQueueIndex"]) ?? -1
        out["totalQueueCount"] = intValue(info["kMRMediaRemoteNowPlayingInfoTotalQueueCount"]) ?? 0
        out["prohibitsSkip"] = boolValue(info["kMRMediaRemoteNowPlayingInfoProhibitsSkip"]) ?? false
        out["isPlaying"] = isPlaying
        if gotPID {
            out["sourcePID"] = Int(sourcePID)
        }

        if let ts = info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
            out["timestamp"] = ts.timeIntervalSince1970
        }
        if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
            out["artworkBase64"] = data.base64EncodedString()
        }

        if let json = try? JSONSerialization.data(withJSONObject: out, options: []),
           let str = String(data: json, encoding: .utf8) {
            print(str)
        } else {
            print("{\"error\":\"json_encode_failed\"}")
        }
        exit(0)
    }

    RunLoop.main.run(until: Date(timeIntervalSinceNow: 3))
    print("{\"error\":\"timeout\"}")
    exit(1)

default:
    print("{\"error\":\"unknown_command: \(command)\"}")
    exit(1)
}
