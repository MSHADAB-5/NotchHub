import AppKit
import Combine

/// Detects which NSScreen has a physical notch and provides geometry information.
final class ScreenDetector: ObservableObject {

    struct NotchGeometry: Equatable {
        let notchWidth: CGFloat
        let notchHeight: CGFloat
        /// The rect of the notch area in screen coordinates (global).
        let notchRect: NSRect
        /// Whether this geometry came from a real notch or is a fallback.
        let isRealNotch: Bool
    }

    @Published private(set) var geometry: NotchGeometry?
    @Published private(set) var currentScreen: NSScreen?

    private var cancellables = Set<AnyCancellable>()

    init() {
        detectScreen()

        // Re-detect when displays change (plug/unplug monitor, lid open/close)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.detectScreen()
            }
            .store(in: &cancellables)
    }

    /// Scan all screens and pick the one with a notch (or fall back to main).
    func detectScreen() {
        if let notchScreen = NSScreen.screens.first(where: { Self.hasNotch($0) }) {
            currentScreen = notchScreen
            geometry = Self.computeGeometry(for: notchScreen)
        } else if let mainScreen = NSScreen.main {
            currentScreen = mainScreen
            geometry = Self.fallbackGeometry(for: mainScreen)
        }
    }

    // MARK: - Static helpers

    static func hasNotch(_ screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0
        }
        return false
    }

    /// Compute the notch bounds from auxiliary areas.
    static func computeGeometry(for screen: NSScreen) -> NotchGeometry {
        if #available(macOS 12.0, *) {
            let leftArea = screen.auxiliaryTopLeftArea
            let rightArea = screen.auxiliaryTopRightArea

            let leftWidth = leftArea?.width ?? 0
            let rightWidth = rightArea?.width ?? 0
            let notchHeight = screen.safeAreaInsets.top

            if leftWidth > 0 || rightWidth > 0 {
                let notchWidth = screen.frame.width - leftWidth - rightWidth
                // Position: centered at top of screen
                let notchX = screen.frame.origin.x + leftWidth
                let notchY = screen.frame.maxY - notchHeight

                return NotchGeometry(
                    notchWidth: notchWidth,
                    notchHeight: notchHeight,
                    notchRect: NSRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight),
                    isRealNotch: true
                )
            }
        }

        return fallbackGeometry(for: screen)
    }

    /// For non-notch Macs: simulate a notch area centered at the top of the screen.
    static func fallbackGeometry(for screen: NSScreen) -> NotchGeometry {
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let height = max(menuBarHeight, 24)
        let width: CGFloat = 200
        let x = screen.frame.origin.x + (screen.frame.width - width) / 2
        let y = screen.frame.maxY - height

        return NotchGeometry(
            notchWidth: width,
            notchHeight: height,
            notchRect: NSRect(x: x, y: y, width: width, height: height),
            isRealNotch: false
        )
    }
}
