import AppKit

extension NSScreen {
    /// Whether this screen has a physical camera housing notch.
    var hasTopNotchDesign: Bool {
        if #available(macOS 12, *) {
            return safeAreaInsets.top != 0
        }
        return false
    }
}
