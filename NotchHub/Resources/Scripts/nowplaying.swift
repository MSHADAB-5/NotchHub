#!/usr/bin/env swift
// nowplaying.swift — Helper script run via Apple-signed /usr/bin/swift
// to access MediaRemote private framework (which requires trusted code signing).
// Outputs JSON to stdout. Called by NowPlayingService.
//
// Usage:
//   swift nowplaying.swift info     — Get current now-playing info as JSON
//   swift nowplaying.swift play     — Toggle play/pause
//   swift nowplaying.swift next     — Next track
//   swift nowplaying.swift prev     — Previous track

import Foundation

guard let bundle = CFBundleCreate(kCFAllocatorDefault,
    NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) else {
    fputs("{\"error\":\"framework_not_found\"}\n", stderr)
    exit(1)
}

// Load function pointers
func loadFunc<T>(_ name: String) -> T? {
    guard let ptr = CFBundleGetFunctionPointerForName(bundle, name as CFString) else { return nil }
    return unsafeBitCast(ptr, to: T.self)
}

typealias GetInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
typealias SendCmdFunc = @convention(c) (UInt32, NSDictionary?) -> Bool
typealias GetPlayingFunc = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void

let getInfo: GetInfoFunc? = loadFunc("MRMediaRemoteGetNowPlayingInfo")
let sendCmd: SendCmdFunc? = loadFunc("MRMediaRemoteSendCommand")
let getPlaying: GetPlayingFunc? = loadFunc("MRMediaRemoteGetNowPlayingApplicationIsPlaying")

let command = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "info"

switch command {
case "play":
    let r = sendCmd?(2, nil) ?? false // togglePlayPause
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "next":
    let r = sendCmd?(4, nil) ?? false // nextTrack
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "prev":
    let r = sendCmd?(5, nil) ?? false // previousTrack
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("{\"ok\":\(r)}")
    exit(0)

case "info":
    guard let getInfo else {
        print("{\"error\":\"function_not_found\"}")
        exit(1)
    }

    var gotPlaying = false
    var isPlaying = false

    getPlaying?(DispatchQueue.main) { playing in
        isPlaying = playing
        gotPlaying = true
    }

    getInfo(DispatchQueue.main) { info in
        // Wait briefly for isPlaying callback
        if !gotPlaying {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        var out: [String: Any] = [:]
        out["title"] = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        out["artist"] = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        out["album"] = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        out["duration"] = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
        out["elapsed"] = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
        out["rate"] = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
        out["isPlaying"] = isPlaying

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
