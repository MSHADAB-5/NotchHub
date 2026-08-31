import AppKit
import Combine

/// Monitors the system pasteboard and maintains a clipboard history.
final class ClipboardService: ObservableObject {

    struct ClipboardItem: Identifiable, Equatable, Codable {
        enum ContentKind: String, Codable {
            case text
            case link
            case code

            var icon: String {
                switch self {
                case .text: return "doc.text"
                case .link: return "link"
                case .code: return "chevron.left.forwardslash.chevron.right"
                }
            }

            var label: String {
                switch self {
                case .text: return "Text"
                case .link: return "Link"
                case .code: return "Code"
                }
            }
        }

        let id: UUID
        let text: String
        let timestamp: Date
        let kind: ContentKind
        let sourceAppName: String?

        init(
            id: UUID = UUID(),
            text: String,
            timestamp: Date,
            kind: ContentKind? = nil,
            sourceAppName: String? = nil
        ) {
            self.id = id
            self.text = text
            self.timestamp = timestamp
            self.kind = kind ?? Self.detectKind(for: text)
            self.sourceAppName = sourceAppName
        }

        var preview: String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count <= 80 { return trimmed }
            return String(trimmed.prefix(77)) + "..."
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case text
            case timestamp
            case kind
            case sourceAppName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            text = try container.decode(String.self, forKey: .text)
            timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
            kind = try container.decodeIfPresent(ContentKind.self, forKey: .kind) ?? Self.detectKind(for: text)
            sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(text, forKey: .text)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(kind, forKey: .kind)
            try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        }

        static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
            lhs.id == rhs.id
        }

        private static func detectKind(for text: String) -> ContentKind {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()

            if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
                return .link
            }
            if trimmed.contains("\n") || trimmed.contains("{") || trimmed.contains(";") ||
                trimmed.contains("</") || lower.contains("func ") || lower.contains("let ") ||
                lower.contains("const ") || lower.contains("class ") {
                return .code
            }
            return .text
        }
    }

    @Published private(set) var history: [ClipboardItem] = []
    @Published private(set) var savedItems: [ClipboardItem] = []

    private let maxItems = 20
    private let defaults = UserDefaults.standard
    private var pollingTimer: Timer?
    private var lastChangeCount: Int = 0

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        savedItems = loadSavedItems()
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

    func copyToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        lastChangeCount = pb.changeCount
    }

    func isSaved(_ item: ClipboardItem) -> Bool {
        savedItems.contains { $0.text == item.text }
    }

    func toggleSaved(_ item: ClipboardItem) {
        if let index = savedItems.firstIndex(where: { $0.text == item.text }) {
            savedItems.remove(at: index)
        } else {
            savedItems.insert(
                ClipboardItem(
                    text: item.text,
                    timestamp: item.timestamp,
                    kind: item.kind,
                    sourceAppName: item.sourceAppName
                ),
                at: 0
            )
        }
        persistSavedItems()
    }

    func removeHistoryItem(_ item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
    }

    func removeSavedItem(_ item: ClipboardItem) {
        savedItems.removeAll { $0.id == item.id || $0.text == item.text }
        persistSavedItems()
    }

    func clearHistory() {
        history.removeAll()
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if let last = history.first, last.text == text { return }

        let item = ClipboardItem(
            text: text,
            timestamp: Date(),
            sourceAppName: NSWorkspace.shared.frontmostApplication?.localizedName
        )
        history.insert(item, at: 0)

        if history.count > maxItems {
            history = Array(history.prefix(maxItems))
        }
    }

    private func persistSavedItems() {
        guard let data = try? JSONEncoder().encode(savedItems) else { return }
        defaults.set(data, forKey: "savedClipboardItems")
    }

    private func loadSavedItems() -> [ClipboardItem] {
        guard let data = defaults.data(forKey: "savedClipboardItems"),
              let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
        }
        return items
    }
}
