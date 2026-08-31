import SwiftUI
import Combine

/// The possible states of the notch panel.
enum NotchState: Equatable {
    case collapsed
    case hovering
    case expanded
    case peeking(id: String)
    case pinned
}

/// Drives the expand/collapse state machine with Combine publishers.
final class NotchViewModel: ObservableObject {

    struct PeekContent {
        let id: String
        let systemImage: String
        let title: String
        let subtitle: String
        let tint: Color
    }

    @Published private(set) var state: NotchState = .collapsed
    @Published private(set) var peekContent: PeekContent?
    @Published var expandedWidth: CGFloat = 420
    @Published var expandedHeight: CGFloat = 200

    var hoverDelayMs: Int = 200
    var collapseDelayMs: Int = 400
    var animationSpeed: Double = 1.0

    private var hoverTimer: DispatchWorkItem?
    private var collapseTimer: DispatchWorkItem?
    private var peekTimer: DispatchWorkItem?

    var isExpanded: Bool {
        switch state {
        case .expanded, .pinned, .peeking:
            return true
        default:
            return false
        }
    }

    var isPinned: Bool {
        state == .pinned
    }

    var expandAnimation: Animation {
        .spring(response: 0.35 * animationSpeed, dampingFraction: 0.7, blendDuration: 0.1)
    }

    var collapseAnimation: Animation {
        .spring(response: 0.25 * animationSpeed, dampingFraction: 0.85, blendDuration: 0.05)
    }

    func mouseEntered() {
        cancelCollapseTimer()

        guard state == .collapsed else { return }

        state = .hovering

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .hovering else { return }
            withAnimation(self.expandAnimation) {
                self.state = .expanded
            }
        }
        hoverTimer = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(hoverDelayMs),
            execute: work
        )
    }

    func mouseExited() {
        cancelHoverTimer()

        switch state {
        case .hovering:
            withAnimation(collapseAnimation) {
                state = .collapsed
            }
        case .expanded:
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.state == .expanded else { return }
                withAnimation(self.collapseAnimation) {
                    self.state = .collapsed
                }
            }
            collapseTimer = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(collapseDelayMs),
                execute: work
            )
        case .pinned, .peeking:
            break
        case .collapsed:
            break
        }
    }

    func togglePin() {
        switch state {
        case .expanded:
            withAnimation(expandAnimation) {
                state = .pinned
            }
        case .pinned:
            withAnimation(collapseAnimation) {
                clearPeek()
                state = .collapsed
            }
        default:
            break
        }
    }

    func clickedOutside() {
        switch state {
        case .expanded, .pinned, .peeking:
            withAnimation(collapseAnimation) {
                clearPeek()
                state = .collapsed
            }
        default:
            break
        }
    }

    func dismiss() {
        cancelHoverTimer()
        cancelCollapseTimer()
        cancelPeekTimer()
        withAnimation(collapseAnimation) {
            clearPeek()
            state = .collapsed
        }
    }

    func showPeek(
        id: String,
        systemImage: String,
        title: String,
        subtitle: String = "",
        tint: Color = .white,
        duration: TimeInterval = 2.5
    ) {
        cancelPeekTimer()
        peekContent = PeekContent(id: id, systemImage: systemImage, title: title, subtitle: subtitle, tint: tint)
        withAnimation(expandAnimation) {
            state = .peeking(id: id)
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if case .peeking = self.state {
                withAnimation(self.collapseAnimation) {
                    self.clearPeek()
                    self.state = .collapsed
                }
            }
        }
        peekTimer = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + duration,
            execute: work
        )
    }

    private func clearPeek() {
        peekContent = nil
    }

    private func cancelHoverTimer() {
        hoverTimer?.cancel()
        hoverTimer = nil
    }

    private func cancelCollapseTimer() {
        collapseTimer?.cancel()
        collapseTimer = nil
    }

    private func cancelPeekTimer() {
        peekTimer?.cancel()
        peekTimer = nil
    }
}
