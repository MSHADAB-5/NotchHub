import SwiftUI

/// Clipboard history — tap to re-copy.
struct ClipboardWidgetView: View {
    @ObservedObject var service: ClipboardService
    @State private var kindFilter: KindFilter = .all
    @State private var searchText = ""

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
                searchField
                filterChips
                savedSection
                recentSection
            }
        }
        .glassCard(cornerRadius: 14, padding: 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.3))

            TextField("Search clipboard", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.28))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 0.5)
                )
        )
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            filterChip(.all)
            filterChip(.text)
            filterChip(.link)
            filterChip(.code)
            Spacer(minLength: 0)
        }
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SAVED")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.34))
                Spacer()
                Text("\(filteredSavedItems.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.24))
            }

            if filteredSavedItems.isEmpty {
                Text(searchText.isEmpty ? "No saved items" : "No saved matches")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.24))
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(filteredSavedItems.prefix(8))) { item in
                            savedChip(item)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.34))
                Spacer()
                Text("\(filteredRecentItems.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.24))
            }

            if filteredRecentItems.isEmpty {
                Text(searchText.isEmpty ? "No recent items" : "No recent matches")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.24))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(filteredRecentItems) { item in
                            recentRow(item)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func savedChip(_ item: ClipboardService.ClipboardItem) -> some View {
        HStack(spacing: 0) {
            Button(action: { service.copyToClipboard(item) }) {
                HStack(spacing: 6) {
                    Image(systemName: item.kind.icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(color(for: item.kind).opacity(0.92))
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
                        .fill(color(for: item.kind).opacity(0.12))
                )
            }
            .buttonStyle(.plain)

            Button(action: { service.removeSavedItem(item) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color(for: item.kind).opacity(0.9))
                    .frame(width: 18, height: 24)
                    .background(
                        Capsule(style: .continuous)
                            .fill(color(for: item.kind).opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(color(for: item.kind).opacity(0.16), lineWidth: 0.5)
        )
    }

    private func filterChip(_ filter: KindFilter) -> some View {
        Button(action: { kindFilter = filter }) {
            Text(filter.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(kindFilter == filter ? .white.opacity(0.82) : .white.opacity(0.45))
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    Capsule(style: .continuous)
                        .fill(kindFilter == filter ? .white.opacity(0.11) : .white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private func recentRow(_ item: ClipboardService.ClipboardItem) -> some View {
        HStack(spacing: 8) {
            Button(action: { service.copyToClipboard(item) }) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.kind.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(color(for: item.kind).opacity(0.9))
                        .frame(width: 12)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.preview)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.72))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            Text(item.sourceAppName?.isEmpty == false ? item.sourceAppName! : "Clipboard")
                            Text("•")
                            Text(item.kind.label)
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.28))
                        .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(timeAgo(item.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.24))
                        .fixedSize()
                        .padding(.top, 1)
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

    private var filteredSavedItems: [ClipboardService.ClipboardItem] {
        service.savedItems.filter(matchesFilter)
    }

    private var filteredRecentItems: [ClipboardService.ClipboardItem] {
        recentItems.filter(matchesFilter)
    }

    private func matchesFilter(_ item: ClipboardService.ClipboardItem) -> Bool {
        if let kind = kindFilter.contentKind, item.kind != kind {
            return false
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystacks = [item.text, item.preview, item.sourceAppName ?? "", item.kind.label]
        return haystacks.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func savedChipLabel(for item: ClipboardService.ClipboardItem) -> String {
        let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = text.components(separatedBy: .newlines).first, !firstLine.isEmpty {
            return String(firstLine.prefix(18))
        }
        return String(text.prefix(18))
    }

    private func color(for kind: ClipboardService.ClipboardItem.ContentKind) -> Color {
        switch kind {
        case .text:
            return .yellow
        case .link:
            return Color(red: 0.54, green: 0.86, blue: 1.0)
        case .code:
            return Color(red: 1.0, green: 0.79, blue: 0.55)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }

    private enum KindFilter: Equatable {
        case all
        case text
        case link
        case code

        var title: String {
            switch self {
            case .all: return "All"
            case .text: return "Text"
            case .link: return "Links"
            case .code: return "Code"
            }
        }

        var contentKind: ClipboardService.ClipboardItem.ContentKind? {
            switch self {
            case .all:
                return nil
            case .text:
                return .text
            case .link:
                return .link
            case .code:
                return .code
            }
        }
    }
}
