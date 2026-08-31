import SwiftUI

/// Protocol that all notch widgets conform to.
/// Each widget provides its own SwiftUI view and lifecycle management.
protocol NotchWidgetProtocol: Identifiable, ObservableObject {
    var id: String { get }
    var displayName: String { get }
    /// SF Symbol name for the widget icon.
    var icon: String { get }
    var isEnabled: Bool { get set }
    var sortOrder: Int { get set }

    associatedtype WidgetBody: View
    @ViewBuilder @MainActor var widgetBody: WidgetBody { get }

    /// Called when the widget should start observing system state.
    func activate()
    /// Called when the widget should stop and release resources.
    func deactivate()
}
