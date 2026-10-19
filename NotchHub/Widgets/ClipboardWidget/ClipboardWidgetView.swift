import SwiftUI

/// Clipboard history — tap to re-copy.
struct ClipboardWidgetView: View {
    @ObservedObject var service: ClipboardService
    var onAliasEditingChanged: (Bool) -> Void = { _ in }
    @State private var kindFilter: KindFilter = .all
    @State private var searchText = ""
    @State private var editingItemID: UUID?
    @State private var aliasDraft = ""
    @State private var aliasError: String?
    @State private var copiedItemID: UUID?
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isAliasFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            if service.savedItems.isEmpty && service.history.isEmpty {
                emptyState(
                    symbol: "doc.on.clipboard",
                    title: "Your clipboard, organized",
                    detail: "Copy text, a link, or code to get started."
                )
            } else {
                utilityBar

                GeometryReader { geometry in
                    HStack(alignment: .top, spacing: 10) {
                        savedSection
                            .frame(width: geometry.size.width * 0.4)
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 0.5)
                        recentSection
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .onDisappear(perform: finishRenaming)
        .task(id: copiedItemID) {
            guard copiedItemID != nil else { return }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            copiedItemID = nil
        }
    }

    private var utilityBar: some View {
        HStack(spacing: 8) {
            searchField
            filterChips

            if !service.history.isEmpty {
                Button(action: { service.clearHistory() }) {
                    Text("Clear recent")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                }
                .buttonStyle(
                    FlatNotchButtonStyle(
                        shape: .capsule,
                        strokeColor: .white.opacity(0.11),
                        strokeWidth: 0.5
                    )
                )
                .help("Clear recent history without removing saved items")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.white.opacity(isSearchFocused ? 0.58 : 0.34))

            TextField("Search content or aliases", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.86))
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.34))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    .white.opacity(isSearchFocused ? 0.24 : 0.11),
                    lineWidth: isSearchFocused ? 0.75 : 0.5
                )
        )
    }

    private var filterChips: some View {
        HStack(spacing: 4) {
            filterChip(.all)
            filterChip(.text)
            filterChip(.link)
            filterChip(.code)
        }
        .fixedSize()
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Saved", symbol: "star.fill", count: filteredSavedItems.count, tint: .yellow)

            if editingItemID != nil {
                aliasEditor
            }

            if filteredSavedItems.isEmpty {
                emptyState(
                    symbol: hasActiveFilter ? "magnifyingglass" : "star",
                    title: hasActiveFilter ? "No saved matches" : "Keep what matters",
                    detail: hasActiveFilter ? "Try another search or filter." : "Star a recent item and give it a name."
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSavedItems) { item in
                            clipboardRow(item, saved: true)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Recent", symbol: "clock", count: filteredRecentItems.count, tint: .white)

            if filteredRecentItems.isEmpty {
                emptyState(
                    symbol: hasActiveFilter ? "magnifyingglass" : "checkmark.circle",
                    title: hasActiveFilter ? "No recent matches" : "All caught up",
                    detail: hasActiveFilter ? "Try another search or filter." : "New copies will appear here."
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredRecentItems) { item in
                            clipboardRow(item, saved: false)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var aliasEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name this saved item")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.yellow.opacity(0.9))

            TextField("Optional name, e.g. PC_pass", text: $aliasDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isAliasFocused ? Color.yellow.opacity(0.34) : Color.white.opacity(0.14),
                            lineWidth: isAliasFocused ? 0.75 : 0.5
                        )
                )
                .focused($isAliasFocused)
                .onAppear { isAliasFocused = true }
                .onSubmit(saveAlias)
                .onExitCommand(perform: finishRenaming)
                .onChange(of: aliasDraft) { _ in aliasError = nil }
                .accessibilityLabel("Saved item alias")

            if let aliasError {
                Text(aliasError)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Text("Optional · 64 max")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
                Spacer(minLength: 0)
                Button(action: finishRenaming) {
                    Text("Cancel")
                        .foregroundColor(.white.opacity(0.62))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                }
                .buttonStyle(
                    FlatNotchButtonStyle(
                        shape: .capsule,
                        strokeColor: .white.opacity(0.12),
                        strokeWidth: 0.5
                    )
                )
                Button(action: saveAlias) {
                    Text("Save")
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 9)
                        .frame(height: 22)
                }
                .buttonStyle(
                    FlatNotchButtonStyle(
                        shape: .capsule,
                        strokeColor: .yellow.opacity(0.28),
                        strokeWidth: 0.5
                    )
                )
            }
            .font(.system(size: 10, weight: .medium))
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(.yellow.opacity(0.22), lineWidth: 0.5)
        )
    }

    private func filterChip(_ filter: KindFilter) -> some View {
        let isSelected = kindFilter == filter

        return Button(action: { kindFilter = filter }) {
            Text(filter.title)
                .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white.opacity(0.92) : .white.opacity(0.44))
                .padding(.horizontal, 8)
                .frame(height: 26)
        }
        .buttonStyle(
            FlatNotchButtonStyle(
                shape: .capsule,
                strokeColor: .white.opacity(isSelected ? 0.28 : 0.08),
                strokeWidth: isSelected ? 0.75 : 0.5
            )
        )
    }

    private func clipboardRow(_ item: ClipboardService.ClipboardItem, saved: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button(action: { copy(item) }) {
                    HStack(spacing: 7) {
                        Image(systemName: item.kind.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(color(for: item.kind))
                            .frame(width: 14)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayTitle)
                                .font(.system(size: 12, weight: saved ? .medium : .regular))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 4) {
                                Text(item.kind.label)
                                if let source = item.sourceAppName, !source.isEmpty {
                                    Text("·")
                                    Text(source)
                                }
                            }
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.42))
                            .lineLimit(1)
                        }

                        if copiedItemID == item.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                                .accessibilityLabel("Copied")
                        } else if !saved {
                            Text(timeAgo(item.timestamp))
                                .foregroundColor(.white.opacity(0.38))
                        }
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 7)
                }
                .buttonStyle(FlatNotchButtonStyle(shape: .rounded(7)))
                .help(copiedItemID == item.id ? "Copied original content" : "Copy original content")
                .accessibilityLabel("Copy \(item.alias ?? item.kind.label)")

                if saved {
                    rowAction(symbol: "pencil", label: "Rename saved item", tint: .white.opacity(0.58)) {
                        beginRenaming(item)
                    }
                }
                rowAction(
                    symbol: saved ? "star.fill" : "star",
                    label: saved ? "Remove from saved" : "Save and name item",
                    tint: saved ? .yellow.opacity(0.9) : .white.opacity(0.48)
                ) {
                    if saved {
                        if editingItemID == item.id { finishRenaming() }
                        service.removeSavedItem(item)
                    } else {
                        beginRenaming(service.saveItem(item))
                    }
                }
            }
            .padding(.vertical, 1)

            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 0.5)
                .padding(.leading, 27)
        }
    }

    private func rowAction(symbol: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(FlatNotchButtonStyle(shape: .rounded(6)))
        .help(label)
        .accessibilityLabel(label)
    }

    private func sectionHeading(_ title: String, symbol: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(tint.opacity(0.75))
            Text(title)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.38))
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.white.opacity(0.58))
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 21))
                .foregroundColor(.white.opacity(0.25))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .multilineTextAlignment(.center)
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copy(_ item: ClipboardService.ClipboardItem) {
        service.copyToClipboard(item)
        copiedItemID = item.id
    }

    private func beginRenaming(_ item: ClipboardService.ClipboardItem) {
        onAliasEditingChanged(true)
        editingItemID = item.id
        aliasDraft = item.alias ?? ""
        aliasError = nil
        isAliasFocused = true
    }

    private func finishRenaming() {
        editingItemID = nil
        aliasDraft = ""
        aliasError = nil
        isAliasFocused = false
        onAliasEditingChanged(false)
    }

    private func saveAlias() {
        guard let editingItemID else { return }
        do {
            try service.renameSavedItem(id: editingItemID, alias: aliasDraft)
            finishRenaming()
        } catch {
            aliasError = error.localizedDescription
            isAliasFocused = true
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
        return item.matches(search: searchText)
    }

    private var hasActiveFilter: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || kindFilter != .all
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
