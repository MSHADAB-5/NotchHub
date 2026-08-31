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

    @Published private(set) var state: NotchState = .collapsed
    @Published var expandedWidth: CGFloat = 420
    @Published var expandedHeight: CGFloat = 200

    /// How long the mouse must dwell before we expand (ms).
    var hoverDelayMs: Int = 200
    /// How long after mouse-exit before we collapse (ms).
    var collapseDelayMs: Int = 400
    /// Multiplier for animation durations.
    var animationSpeed: Double = 1.0

    private var hoverTimer: DispatchWorkItem?
    private var collapseTimer: DispatchWorkItem?
    private var peekTimer: DispatchWorkItem?

    // MARK: - Computed Properties

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

    // MARK: - Animation

    var expandAnimation: Animation {
        .spring(response: 0.35 * animationSpeed, dampingFraction: 0.7, blendDuration: 0.1)
    }

    var collapseAnimation: Animation {
        .spring(response: 0.25 * animationSpeed, dampingFraction: 0.85, blendDuration: 0.05)
    }

    // MARK: - State Transitions

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
            break // Don't auto-collapse when pinned or peeking
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
                state = .collapsed
            }
        default:
            break
        }
    }

    func clickedOutside() {
        switch state {
        case .expanded:
            withAnimation(collapseAnimation) {
                state = .collapsed
            }
        case .pinned:
            withAnimation(collapseAnimation) {
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
            state = .collapsed
        }
    }

    /// Show a transient peek notification, auto-collapses after a duration.
    func showPeek(id: String, duration: TimeInterval = 2.5) {
        cancelPeekTimer()
        withAnimation(expandAnimation) {
            state = .peeking(id: id)
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if case .peeking = self.state {
                withAnimation(self.collapseAnimation) {
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

    // MARK: - Timer Management

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
