import SwiftUI

/// The collapsed state view — nearly invisible, just provides the hover target.
struct CollapsedNotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    var body: some View {
        // Essentially invisible — just a clear hit target
        Rectangle()
            .fill(.clear)
            .frame(width: notchWidth, height: notchHeight)
    }
}
