import AppKit
import Combine

/// Provides system-level quick actions (DND, dark mode, screenshot, lock, etc.).
/// Uses osascript/shell where NSAppleScript needs Automation permissions.
final class SystemActionsService: ObservableObject {

    enum Action: String, CaseIterable, Identifiable {
        case toggleDND = "Toggle Do Not Disturb"
        case toggleDarkMode = "Toggle Dark Mode"
        case lockScreen = "Lock Screen"
        case sleepDisplay = "Sleep Display"
        case screenshot = "Screenshot"
        case screenshotClipboard = "Screenshot to Clipboard"
        case emptyTrash = "Empty Trash"
        case toggleMute = "Toggle Mute"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .toggleDND: return "moon.fill"
            case .toggleDarkMode: return "circle.lefthalf.filled"
            case .lockScreen: return "lock.fill"
            case .sleepDisplay: return "display"
            case .screenshot: return "camera.fill"
            case .screenshotClipboard: return "camera.viewfinder"
            case .emptyTrash: return "trash.fill"
            case .toggleMute: return "speaker.slash.fill"
            }
        }

        var shortLabel: String {
            switch self {
            case .toggleDND: return "DND"
            case .toggleDarkMode: return "Dark"
            case .lockScreen: return "Lock"
            case .sleepDisplay: return "Sleep"
            case .screenshot: return "Screenshot"
            case .screenshotClipboard: return "Clipboard"
            case .emptyTrash: return "Trash"
            case .toggleMute: return "Mute"
            }
        }
    }

    @Published private(set) var isDarkMode: Bool = false
    @Published private(set) var lastActionFeedback: String?

    init() {
        isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    func perform(_ action: Action) {
        lastActionFeedback = action.shortLabel
        switch action {
        case .toggleDND:        toggleDND()
        case .toggleDarkMode:   toggleDarkMode()
        case .lockScreen:       lockScreen()
        case .sleepDisplay:     sleepDisplay()
        case .screenshot:       takeScreenshot(toClipboard: false)
        case .screenshotClipboard: takeScreenshot(toClipboard: true)
        case .emptyTrash:       emptyTrash()
        case .toggleMute:       toggleMute()
        }

        // Clear feedback after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.lastActionFeedback = nil
        }
    }

    // MARK: - Individual Actions

    private func toggleDND() {
        // Use osascript to toggle Focus/DND via System Events menu bar interaction
        runOsascript("""
            tell application "System Events"
                tell its application process "ControlCenter"
                    -- Click the Focus/DND item in Control Center
                    click menu bar item "Focus" of menu bar 1
                end tell
            end tell
        """)
    }

    private func toggleDarkMode() {
        runOsascript("""
            tell application "System Events"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
        """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    private func lockScreen() {
        // Cmd+Ctrl+Q via System Events is the most reliable lock method on modern macOS
        runOsascript("""
            tell application "System Events" to keystroke "q" using {command down, control down}
        """)
    }

    private func sleepDisplay() {
        // pmset displaysleepnow works without sudo
        runShell("/usr/bin/pmset", arguments: ["displaysleepnow"])
    }

    private func takeScreenshot(toClipboard: Bool) {
        if toClipboard {
            runShell("/usr/sbin/screencapture", arguments: ["-i", "-c"])
        } else {
            runShell("/usr/sbin/screencapture", arguments: ["-i"])
        }
    }

    private func emptyTrash() {
        runOsascript("""
            tell application "Finder"
                empty the trash
            end tell
        """)
    }

    private func toggleMute() {
        // This one uses basic AppleScript (no app targeting) — works without Automation permission
        let script = NSAppleScript(source: """
            if output muted of (get volume settings) then
                set volume without output muted
            else
                set volume with output muted
            end if
        """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
    }

    // MARK: - Helpers

    /// Run AppleScript via /usr/bin/osascript process — triggers proper Automation permission dialogs.
    @discardableResult
    private func runOsascript(_ source: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            NSLog("[NotchHub] osascript failed: %@", error.localizedDescription)
            return false
        }
    }

    /// Run a shell command.
    @discardableResult
    private func runShell(_ path: String, arguments: [String] = []) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            return true
        } catch {
            NSLog("[NotchHub] Shell command failed: %@", error.localizedDescription)
            return false
        }
    }
}
