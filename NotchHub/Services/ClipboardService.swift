import AppKit
import Combine

/// Monitors the system pasteboard and maintains a clipboard history.
final class ClipboardService: ObservableObject {

    struct ClipboardItem: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let timestamp: Date

        /// Truncated preview for display.
        var preview: String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count <= 80 { return trimmed }
            return String(trimmed.prefix(77)) + "..."
        }

        static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published private(set) var history: [ClipboardItem] = []

    private let maxItems = 20
    private var pollingTimer: Timer?
    private var lastChangeCount: Int = 0

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        // Check clipboard every 0.5s
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        if let timer = pollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    deinit {
        pollingTimer?.invalidate()
    }

    /// Copy a history item back to the clipboard.
    func copyToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        lastChangeCount = pb.changeCount
    }

    /// Remove a single item from history.
    func remove(_ item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
    }

    /// Clear all history.
    func clearHistory() {
        history.removeAll()
    }

    // MARK: - Polling

    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Avoid duplicating the most recent entry
        if let last = history.first, last.text == text { return }

        let item = ClipboardItem(text: text, timestamp: Date())
        history.insert(item, at: 0)

        // Trim to max
        if history.count > maxItems {
            history = Array(history.prefix(maxItems))
        }
    }
}
