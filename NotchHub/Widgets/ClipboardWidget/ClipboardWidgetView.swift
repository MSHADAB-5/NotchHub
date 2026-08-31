import SwiftUI

/// Clipboard history — tap to re-copy.
struct ClipboardWidgetView: View {
    @ObservedObject var service: ClipboardService
    @State private var filter: TrayFilter = .all

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Tray", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))

                Spacer()

                if !recentItems.isEmpty {
                    Button("Clear") { service.clearHistory() }
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                        .buttonStyle(.plain)
                }
            }

            if service.savedItems.isEmpty && service.history.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.15))
                    Text("Copy something to see it here")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    if !service.savedItems.isEmpty && filter != .recent {
                        savedSection
                    }

                    if !service.savedItems.isEmpty && !recentItems.isEmpty {
                        filterChips
                    }

                    if filter != .saved {
                        recentSection
                    }
                }
            }
        }
        .glassCard(cornerRadius: 14, padding: 12)
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SAVED")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.34))
                Spacer()
                Text("\(service.savedItems.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.24))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(service.savedItems.prefix(8))) { item in
                        savedChip(item)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            filterChip(.all, title: "All")
            filterChip(.saved, title: "Saved")
            filterChip(.recent, title: "Recent")
            Spacer(minLength: 0)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(filter == .recent ? "RECENT" : "STACK")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.34))
                Spacer()
                if remainingRecentCount > 0 {
                    Text("+\(remainingRecentCount) more")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.24))
                }
            }

            if displayedRecentItems.isEmpty {
                Text("No recent items")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.24))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(displayedRecentItems) { item in
                        recentRow(item)
                    }
                }
            }
        }
    }

    private func savedChip(_ item: ClipboardService.ClipboardItem) -> some View {
        HStack(spacing: 0) {
            Button(action: { service.copyToClipboard(item) }) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.yellow.opacity(0.9))
                    Text(savedChipLabel(for: item))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(1)
                }
                .padding(.leading, 10)
                .padding(.trailing, 8)
                .frame(height: 24)
                .background(
                    Capsule(style: .continuous)
                        .fill(.yellow.opacity(0.12))
                )
            }
            .buttonStyle(.plain)

            Button(action: { service.removeSavedItem(item) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.yellow.opacity(0.88))
                    .frame(width: 18, height: 24)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.yellow.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(.yellow.opacity(0.16), lineWidth: 0.5)
        )
    }

    private func filterChip(_ trayFilter: TrayFilter, title: String) -> some View {
        Button(action: { filter = trayFilter }) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(filter == trayFilter ? .white.opacity(0.82) : .white.opacity(0.45))
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    Capsule(style: .continuous)
                        .fill(filter == trayFilter ? .white.opacity(0.11) : .white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private func recentRow(_ item: ClipboardService.ClipboardItem) -> some View {
        HStack(spacing: 8) {
            Button(action: { service.copyToClipboard(item) }) {
                HStack(spacing: 8) {
                    Image(systemName: rowSymbol(for: item))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.36))
                        .frame(width: 12)

                    Text(item.preview)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(timeAgo(item.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.24))
                        .fixedSize()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.03), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: { service.toggleSaved(item) }) {
                Image(systemName: service.isSaved(item) ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(service.isSaved(item) ? .yellow.opacity(0.88) : .white.opacity(0.35))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.white.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .help(service.isSaved(item) ? "Remove from saved" : "Save in tray")
        }
    }

    private var recentItems: [ClipboardService.ClipboardItem] {
        service.history.filter { !service.isSaved($0) }
    }

    private var displayedRecentItems: [ClipboardService.ClipboardItem] {
        let limit = filter == .recent ? 5 : 3
        return Array(recentItems.prefix(limit))
    }

    private var remainingRecentCount: Int {
        max(0, recentItems.count - displayedRecentItems.count)
    }

    private func savedChipLabel(for item: ClipboardService.ClipboardItem) -> String {
        let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = text.components(separatedBy: .newlines).first, !firstLine.isEmpty {
            return String(firstLine.prefix(18))
        }
        return String(text.prefix(18))
    }

    private func rowSymbol(for item: ClipboardService.ClipboardItem) -> String {
        let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("http://") || text.contains("https://") {
            return "link"
        }
        if text.contains("{") || text.contains(";") || text.contains("</") || text.contains("func ") {
            return "chevron.left.forwardslash.chevron.right"
        }
        return "doc.text"
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }

    private enum TrayFilter {
        case all
        case saved
        case recent
    }
}
