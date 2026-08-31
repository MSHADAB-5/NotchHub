import SwiftUI
import Combine

/// Which widget "page" to show in the expanded panel.
enum WidgetPage: String, CaseIterable, Identifiable {
    case media = "Now Playing"
    case quickActions = "Quick Actions"
    case battery = "Battery"
    case clipboard = "Clipboard"
    case timer = "Timer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .media: return "music.note"
        case .quickActions: return "bolt.fill"
        case .battery: return "battery.100percent"
        case .clipboard: return "doc.on.clipboard"
        case .timer: return "timer"
        }
    }
}

/// Manages which widgets are available and their ordering.
final class WidgetRegistry: ObservableObject {
    @Published var currentPage: WidgetPage = .media
    @Published var enabledPages: [WidgetPage] = WidgetPage.allCases

    func nextPage() {
        guard let idx = enabledPages.firstIndex(of: currentPage) else { return }
        let nextIdx = (idx + 1) % enabledPages.count
        currentPage = enabledPages[nextIdx]
    }

    func previousPage() {
        guard let idx = enabledPages.firstIndex(of: currentPage) else { return }
        let prevIdx = (idx - 1 + enabledPages.count) % enabledPages.count
        currentPage = enabledPages[prevIdx]
    }
}
