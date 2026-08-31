import SwiftUI

/// Grid of quick-action buttons.
struct QuickActionsWidgetView: View {
    @ObservedObject var service: SystemActionsService

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SystemActionsService.Action.allCases) { action in
                actionButton(action)
            }
        }
        .glassCard(cornerRadius: 14, padding: 12)
    }

    @ViewBuilder
    private func actionButton(_ action: SystemActionsService.Action) -> some View {
        let isFeedback = service.lastActionFeedback == action.shortLabel

        Button(action: { service.perform(action) }) {
            VStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isFeedback ? .green : .white.opacity(0.75))

                Text(action.shortLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(isFeedback ? 0.14 : 0.07))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isFeedback)
    }
}
