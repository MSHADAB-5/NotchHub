import AppKit
import Combine

/// Provides now-playing media info and playback controls.
/// Uses a helper Swift script run via /usr/bin/swift (Apple-signed) to access
/// the MediaRemote private framework, since ad-hoc signed apps can't call it directly.
final class NowPlayingService: ObservableObject {

    struct NowPlayingInfo {
        enum ShuffleMode: Int {
            case off = 1
            case albums = 2
            case songs = 3

            var label: String {
                switch self {
                case .off: return "Shuffle Off"
                case .albums: return "Shuffle Albums"
                case .songs: return "Shuffle Songs"
                }
            }
        }

        enum RepeatMode: Int {
            case off = 1
            case one = 2
            case all = 3

            var label: String {
                switch self {
                case .off: return "Repeat Off"
                case .one: return "Repeat One"
                case .all: return "Repeat All"
                }
            }
        }

        var title: String = ""
        var artist: String = ""
        var album: String = ""
        var artwork: NSImage?
        var duration: TimeInterval = 0
        var elapsedTime: TimeInterval = 0
        var isPlaying: Bool = false
        var playbackRate: Double = 0
        var lastTimestamp: TimeInterval = 0
        var sourceAppName: String = ""
        var sourceBundleIdentifier: String = ""
        var sourcePID: Int32 = 0
        var shuffleModeRawValue: Int = ShuffleMode.off.rawValue
        var repeatModeRawValue: Int = RepeatMode.off.rawValue
        var supportsBack15: Bool = false
        var supportsForward15: Bool = false
        var queueIndex: Int = -1
        var totalQueueCount: Int = 0
        var prohibitsSkip: Bool = false

        var hasContent: Bool { !title.isEmpty }

        /// Compute current elapsed time accounting for playback since last update.
        var currentElapsed: TimeInterval {
            guard duration > 0, playbackRate > 0, lastTimestamp > 0 else {
                return elapsedTime
            }
            let timeSinceUpdate = Date().timeIntervalSince1970 - lastTimestamp
            return min(elapsedTime + timeSinceUpdate * playbackRate, duration)
        }

        var canSeek: Bool {
            duration > 0
        }

        var shuffleMode: ShuffleMode? {
            ShuffleMode(rawValue: shuffleModeRawValue)
        }

        var repeatMode: RepeatMode? {
            RepeatMode(rawValue: repeatModeRawValue)
        }

        var queuePositionLabel: String? {
            guard totalQueueCount > 0, queueIndex >= 0 else { return nil }
            return "\(queueIndex + 1) of \(totalQueueCount)"
        }
    }

    @Published private(set) var nowPlaying = NowPlayingInfo()
    @Published private(set) var isAvailable = true

    private var refreshTimer: Timer?
    private var helperScriptPath: String?

    init() {
        locateHelperScript()
        if helperScriptPath != nil {
            fetchNowPlayingInfo()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.fetchNowPlayingInfo()
            }
            if let timer = refreshTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        } else {
            isAvailable = false
            NSLog("[NotchHub] nowplaying.swift helper not found")
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Helper Script Location

    private func locateHelperScript() {
        if let bundlePath = Bundle.main.path(forResource: "nowplaying", ofType: "swift", inDirectory: "Scripts") {
            helperScriptPath = bundlePath
            NSLog("[NotchHub] Helper found via Bundle.main: %@", bundlePath)
            return
        }

        let execPath = ProcessInfo.processInfo.arguments[0]
        let execURL = URL(fileURLWithPath: execPath)
        let candidates = [
            execURL.deletingLastPathComponent()
                .appendingPathComponent("../Resources/Scripts/nowplaying.swift"),
            execURL.deletingLastPathComponent()
                .appendingPathComponent("../../../../NotchHub/Resources/Scripts/nowplaying.swift"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("NotchHub/Resources/Scripts/nowplaying.swift"),
        ]

        for candidate in candidates {
            let resolved = candidate.standardized
            if FileManager.default.fileExists(atPath: resolved.path) {
                helperScriptPath = resolved.path
                NSLog("[NotchHub] Helper found via fallback: %@", resolved.path)
                return
            }
        }

        NSLog("[NotchHub] Helper NOT FOUND. Exec: %@, Bundle: %@",
              execPath, Bundle.main.bundlePath)
    }

    // MARK: - Fetch Info

    func fetchNowPlayingInfo() {
        guard let scriptPath = helperScriptPath else {
            NSLog("[NotchHub] fetchNowPlayingInfo: no script path")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.runHelper(scriptPath: scriptPath, command: "info")
            if let result {
                DispatchQueue.main.async {
                    self.parseInfoResult(result)
                }
            }
        }
    }

    private func parseInfoResult(_ json: [String: Any]) {
        if let error = json["error"] {
            NSLog("[NotchHub] Helper error: %@", "\(error)")
            return
        }

        var updated = nowPlaying
        let newTitle = json["title"] as? String ?? ""
        let newArtist = json["artist"] as? String ?? ""

        updated.title = newTitle
        updated.artist = newArtist
        updated.album = json["album"] as? String ?? ""
        updated.duration = doubleValue(json["duration"])
        updated.elapsedTime = doubleValue(json["elapsed"])
        updated.isPlaying = json["isPlaying"] as? Bool ?? false
        updated.playbackRate = doubleValue(json["rate"])
        updated.lastTimestamp = doubleValue(json["timestamp"])
        updated.shuffleModeRawValue = intValue(json["shuffleMode"], defaultValue: NowPlayingInfo.ShuffleMode.off.rawValue)
        updated.repeatModeRawValue = intValue(json["repeatMode"], defaultValue: NowPlayingInfo.RepeatMode.off.rawValue)
        updated.supportsBack15 = json["supportsBack15"] as? Bool ?? false
        updated.supportsForward15 = json["supportsForward15"] as? Bool ?? false
        updated.queueIndex = intValue(json["queueIndex"], defaultValue: -1)
        updated.totalQueueCount = intValue(json["totalQueueCount"], defaultValue: 0)
        updated.prohibitsSkip = json["prohibitsSkip"] as? Bool ?? false

        let sourcePID = intValue(json["sourcePID"], defaultValue: 0)
        updated.sourcePID = Int32(sourcePID)
        if sourcePID > 0,
           let app = NSRunningApplication(processIdentifier: pid_t(sourcePID)) {
            updated.sourceAppName = app.localizedName ?? ""
            updated.sourceBundleIdentifier = app.bundleIdentifier ?? ""
        } else {
            updated.sourceAppName = ""
            updated.sourceBundleIdentifier = ""
        }

        if newTitle != nowPlaying.title || newArtist != nowPlaying.artist {
            if let b64 = json["artworkBase64"] as? String,
               !b64.isEmpty,
               let data = Data(base64Encoded: b64) {
                updated.artwork = NSImage(data: data)
            } else {
                updated.artwork = nil
            }
        }

        nowPlaying = updated
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        sendCommand("play") { info in
            info.isPlaying.toggle()
            info.playbackRate = info.isPlaying ? max(info.playbackRate, 1) : 0
            info.lastTimestamp = Date().timeIntervalSince1970
        }
    }

    func nextTrack() {
        sendCommand("next")
    }

    func previousTrack() {
        sendCommand("prev")
    }

    func skipBackward15() {
        guard nowPlaying.supportsBack15 else { return }
        sendCommand("back15", refreshDelay: 0.25) { info in
            info.elapsedTime = max(info.currentElapsed - 15, 0)
            info.lastTimestamp = Date().timeIntervalSince1970
        }
    }

    func skipForward15() {
        guard nowPlaying.supportsForward15 else { return }
        sendCommand("fwd15", refreshDelay: 0.25) { info in
            info.elapsedTime = min(info.currentElapsed + 15, info.duration)
            info.lastTimestamp = Date().timeIntervalSince1970
        }
    }

    func toggleShuffleMode() {
        sendCommand("shuffle", refreshDelay: 0.25) { info in
            let next: Int
            switch info.shuffleMode ?? .off {
            case .off: next = NowPlayingInfo.ShuffleMode.songs.rawValue
            case .songs: next = NowPlayingInfo.ShuffleMode.albums.rawValue
            case .albums: next = NowPlayingInfo.ShuffleMode.off.rawValue
            }
            info.shuffleModeRawValue = next
        }
    }

    func toggleRepeatMode() {
        sendCommand("repeat", refreshDelay: 0.25) { info in
            let next: Int
            switch info.repeatMode ?? .off {
            case .off: next = NowPlayingInfo.RepeatMode.all.rawValue
            case .all: next = NowPlayingInfo.RepeatMode.one.rawValue
            case .one: next = NowPlayingInfo.RepeatMode.off.rawValue
            }
            info.repeatModeRawValue = next
        }
    }

    func seek(to seconds: TimeInterval) {
        let clamped = max(0, min(seconds, nowPlaying.duration))
        sendCommand("seek", argument: String(clamped), refreshDelay: 0.2) { info in
            info.elapsedTime = clamped
            info.lastTimestamp = Date().timeIntervalSince1970
        }
    }

    private func sendCommand(
        _ cmd: String,
        argument: String? = nil,
        refreshDelay: TimeInterval = 0.5,
        optimisticUpdate: ((inout NowPlayingInfo) -> Void)? = nil
    ) {
        guard let scriptPath = helperScriptPath else { return }
        if let optimisticUpdate {
            var updated = nowPlaying
            optimisticUpdate(&updated)
            nowPlaying = updated
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.runHelper(scriptPath: scriptPath, command: cmd, argument: argument)
            DispatchQueue.main.asyncAfter(deadline: .now() + refreshDelay) { [weak self] in
                self?.fetchNowPlayingInfo()
            }
        }
    }

    // MARK: - Helper Process

    private func runHelper(scriptPath: String, command: String, argument: String? = nil) -> [String: Any]? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        if let argument {
            task.arguments = [scriptPath, command, argument]
        } else {
            task.arguments = [scriptPath, command]
        }
        task.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
        } catch {
            NSLog("[NotchHub] Helper launch failed: %@", error.localizedDescription)
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard !data.isEmpty else {
            NSLog("[NotchHub] Helper returned no data (exit: %d)", task.terminationStatus)
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("[NotchHub] Helper JSON parse failed: %@",
                  String(data: data, encoding: .utf8) ?? "<binary>")
            return nil
        }

        return json
    }

    private func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String, let parsed = Double(value) { return parsed }
        return 0
    }

    private func intValue(_ value: Any?, defaultValue: Int) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String, let parsed = Int(value) { return parsed }
        return defaultValue
    }
}
