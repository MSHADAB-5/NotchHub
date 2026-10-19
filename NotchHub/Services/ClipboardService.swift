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
        let alias: String?

        init(
            id: UUID = UUID(),
            text: String,
            timestamp: Date,
            kind: ContentKind? = nil,
            sourceAppName: String? = nil,
            alias: String? = nil
        ) {
            self.id = id
            self.text = text
            self.timestamp = timestamp
            self.kind = kind ?? Self.detectKind(for: text)
            self.sourceAppName = sourceAppName
            self.alias = alias
        }

        var preview: String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count <= 80 { return trimmed }
            return String(trimmed.prefix(77)) + "..."
        }

        var displayTitle: String {
            if let alias, !alias.isEmpty { return alias }
            return preview
        }

        func matches(search: String) -> Bool {
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty || [alias ?? "", text, sourceAppName ?? "", kind.label].contains {
                $0.localizedCaseInsensitiveContains(query)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case text
            case timestamp
            case kind
            case sourceAppName
            case alias
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            text = try container.decode(String.self, forKey: .text)
            timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
            kind = try container.decodeIfPresent(ContentKind.self, forKey: .kind) ?? Self.detectKind(for: text)
            sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
            alias = try container.decodeIfPresent(String.self, forKey: .alias)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(text, forKey: .text)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(kind, forKey: .kind)
            try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
            try container.encodeIfPresent(alias, forKey: .alias)
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

    enum AliasError: LocalizedError {
        case tooLong
        case invalidCharacters
        case itemNotFound

        var errorDescription: String? {
            switch self {
            case .tooLong: return "Keep the name to 64 characters or fewer."
            case .invalidCharacters: return "Use a single line without tabs or control characters."
            case .itemNotFound: return "This item is no longer saved."
            }
        }
    }

    @Published private(set) var history: [ClipboardItem] = []
    @Published private(set) var savedItems: [ClipboardItem] = []

    private let maxItems = 20
    private let defaults: UserDefaults
    private let pasteboard: NSPasteboard
    private var pollingTimer: Timer?
    private var lastChangeCount: Int = 0

    init(
        defaults: UserDefaults = .standard,
        pasteboard: NSPasteboard = .general,
        startsMonitoring: Bool = true
    ) {
        self.defaults = defaults
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
        savedItems = loadSavedItems()
        guard startsMonitoring else { return }
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
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    func isSaved(_ item: ClipboardItem) -> Bool {
        savedItems.contains { $0.text == item.text }
    }

    func toggleSaved(_ item: ClipboardItem) {
        if isSaved(item) {
            removeSavedItem(item)
        } else {
            saveItem(item)
        }
    }

    @discardableResult
    func saveItem(_ item: ClipboardItem) -> ClipboardItem {
        if let existing = savedItems.first(where: { $0.text == item.text }) { return existing }
        let saved = ClipboardItem(
            text: item.text,
            timestamp: item.timestamp,
            kind: item.kind,
            sourceAppName: item.sourceAppName
        )
        savedItems.insert(saved, at: 0)
        persistSavedItems()
        return saved
    }

    func renameSavedItem(id: UUID, alias: String) throws {
        guard let index = savedItems.firstIndex(where: { $0.id == id }) else {
            throw AliasError.itemNotFound
        }
        let name = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count <= 64 else { throw AliasError.tooLong }
        guard !name.unicodeScalars.contains(where: {
            CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0)
        }) else { throw AliasError.invalidCharacters }
        let item = savedItems[index]
        savedItems[index] = ClipboardItem(
            id: item.id,
            text: item.text,
            timestamp: item.timestamp,
            kind: item.kind,
            sourceAppName: item.sourceAppName,
            alias: name.isEmpty ? nil : name
        )
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

    func checkClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string),
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
