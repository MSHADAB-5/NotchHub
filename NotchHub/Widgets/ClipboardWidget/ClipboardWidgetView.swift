import SwiftUI

/// Clipboard history — tap to re-copy.
struct ClipboardWidgetView: View {
    @ObservedObject var service: ClipboardService

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Label("Tray", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))

                Spacer()

                if !service.history.isEmpty {
                    Button("Clear") { service.clearHistory() }
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                        .buttonStyle(.plain)
                }
            }

            if service.history.isEmpty {
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
                VStack(spacing: 4) {
                    ForEach(service.history.prefix(5)) { item in
                        clipboardRow(item)
                    }
                }
            }
        }
        .glassCard(cornerRadius: 14, padding: 12)
    }

    @ViewBuilder
    private func clipboardRow(_ item: ClipboardService.ClipboardItem) -> some View {
        Button(action: { service.copyToClipboard(item) }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.36))
                    .frame(width: 12)

                Text(item.preview)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(timeAgo(item.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.25))
                    .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}
