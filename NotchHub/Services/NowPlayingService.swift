import AppKit
import Combine

/// Provides now-playing media info and playback controls.
/// Uses a helper Swift script run via /usr/bin/swift (Apple-signed) to access
/// the MediaRemote private framework, since ad-hoc signed apps can't call it directly.
final class NowPlayingService: ObservableObject {

    struct NowPlayingInfo {
        var title: String = ""
        var artist: String = ""
        var album: String = ""
        var artwork: NSImage?
        var duration: TimeInterval = 0
        var elapsedTime: TimeInterval = 0
        var isPlaying: Bool = false
        var playbackRate: Double = 0
        var lastTimestamp: TimeInterval = 0

        var hasContent: Bool { !title.isEmpty }

        /// Compute current elapsed time accounting for playback since last update.
        var currentElapsed: TimeInterval {
            guard duration > 0, playbackRate > 0, lastTimestamp > 0 else {
                return elapsedTime
            }
            let timeSinceUpdate = Date().timeIntervalSince1970 - lastTimestamp
            return min(elapsedTime + timeSinceUpdate * playbackRate, duration)
        }
    }

    @Published private(set) var nowPlaying = NowPlayingInfo()
    @Published private(set) var isAvailable = true

    private var refreshTimer: Timer?
    private var helperScriptPath: String?

    init() {
        locateHelperScript()
        if helperScriptPath != nil {
            // Initial fetch
            fetchNowPlayingInfo()
            // Periodic refresh every 2 seconds (script invocation has overhead)
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
        // Check inside .app bundle first
        if let bundlePath = Bundle.main.path(forResource: "nowplaying", ofType: "swift", inDirectory: "Scripts") {
            helperScriptPath = bundlePath
            NSLog("[NotchHub] Helper found via Bundle.main: %@", bundlePath)
            return
        }

        // Fallback: look relative to the executable
        let execPath = ProcessInfo.processInfo.arguments[0]
        let execURL = URL(fileURLWithPath: execPath)
        let candidates = [
            // Inside .app bundle: Contents/MacOS/../Resources/Scripts/
            execURL.deletingLastPathComponent()
                .appendingPathComponent("../Resources/Scripts/nowplaying.swift"),
            // SPM build directory: look up to source tree
            execURL.deletingLastPathComponent()
                .appendingPathComponent("../../../../NotchHub/Resources/Scripts/nowplaying.swift"),
            // Development: look in source tree relative to cwd
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
        updated.duration = json["duration"] as? Double ?? 0
        updated.elapsedTime = json["elapsed"] as? Double ?? 0
        updated.isPlaying = json["isPlaying"] as? Bool ?? false
        updated.playbackRate = json["rate"] as? Double ?? 0
        updated.lastTimestamp = json["timestamp"] as? Double ?? 0

        // Decode artwork if track changed
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
        sendCommand("play")
        // Optimistically toggle state
        nowPlaying.isPlaying.toggle()
    }

    func nextTrack() {
        sendCommand("next")
    }

    func previousTrack() {
        sendCommand("prev")
    }

    private func sendCommand(_ cmd: String) {
        guard let scriptPath = helperScriptPath else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.runHelper(scriptPath: scriptPath, command: cmd)
            // Refresh info after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.fetchNowPlayingInfo()
            }
        }
    }

    // MARK: - Helper Process

    private func runHelper(scriptPath: String, command: String) -> [String: Any]? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        task.arguments = [scriptPath, command]
        task.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
        } catch {
            NSLog("[NotchHub] Helper launch failed: %@", error.localizedDescription)
            return nil
        }

        // Read data first (before waitUntilExit to avoid pipe deadlock with large output)
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
}
