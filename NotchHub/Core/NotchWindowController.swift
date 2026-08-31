import AppKit
import SwiftUI
import Combine

/// Manages the borderless NSPanel that overlays the notch area.
/// Handles positioning, hover tracking, and hosting the SwiftUI content.
final class NotchWindowController: NSObject, ObservableObject {

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var mousePollingTimer: Timer?
    private var isMouseInside = false

    let screenDetector: ScreenDetector
    let viewModel: NotchViewModel
    let settingsService: SettingsService

    private let minimumExpandedWidth: CGFloat = 420

    init(screenDetector: ScreenDetector, viewModel: NotchViewModel, settingsService: SettingsService) {
        self.screenDetector = screenDetector
        self.viewModel = viewModel
        self.settingsService = settingsService
        super.init()

        viewModel.$state
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updatePanelFrame(for: state)
            }
            .store(in: &cancellables)

        screenDetector.$geometry
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.repositionPanel()
            }
            .store(in: &cancellables)

        settingsService.$panelSizePreset
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updatePanelFrame(for: self.viewModel.state)
            }
            .store(in: &cancellables)
    }

    func setupPanel<Content: View>(@ViewBuilder content: () -> Content) {
        guard let geometry = screenDetector.geometry else { return }

        let wrappedView = AnyView(content())

        let panel = NSPanel(
            contentRect: collapsedRect(for: geometry),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar + 1
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false

        let hosting = NSHostingView(rootView: wrappedView)
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting

        setupMouseTracking()
        setupClickOutsideMonitor()

        panel.orderFrontRegardless()
    }

    private func setupMouseTracking() {
        mousePollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
        if let timer = mousePollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func checkMousePosition() {
        guard let panel else { return }

        let mouseLocation = NSEvent.mouseLocation
        let panelFrame = panel.frame

        let hoverRect: NSRect
        if viewModel.state == .collapsed || viewModel.state == .hovering {
            let expandBy: CGFloat = 8
            hoverRect = panelFrame.insetBy(dx: -expandBy, dy: -expandBy)
        } else {
            hoverRect = panelFrame
        }

        let mouseIsNowInside = hoverRect.contains(mouseLocation)

        if mouseIsNowInside && !isMouseInside {
            isMouseInside = true
            viewModel.mouseEntered()
        } else if !mouseIsNowInside && isMouseInside {
            isMouseInside = false
            viewModel.mouseExited()
        }
    }

    private func setupClickOutsideMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.viewModel.isExpanded else { return }
            if let panel = self.panel {
                let clickLocation = NSEvent.mouseLocation
                if !panel.frame.contains(clickLocation) {
                    self.viewModel.clickedOutside()
                }
            }
        }
    }

    private func updatePanelFrame(for state: NotchState) {
        guard let geometry = screenDetector.geometry else { return }

        let targetRect: NSRect

        switch state {
        case .collapsed, .hovering:
            targetRect = collapsedRect(for: geometry)
        case .expanded, .pinned:
            targetRect = expandedRect(for: geometry)
        case .peeking:
            targetRect = peekRect(for: geometry)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = state == .collapsed ? 0.2 : 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true

            panel?.animator().setFrame(targetRect, display: true)
        }
    }

    private func repositionPanel() {
        guard let geometry = screenDetector.geometry else { return }

        let rect: NSRect
        switch viewModel.state {
        case .collapsed, .hovering:
            rect = collapsedRect(for: geometry)
        case .expanded, .pinned:
            rect = expandedRect(for: geometry)
        case .peeking:
            rect = peekRect(for: geometry)
        }

        panel?.setFrame(rect, display: true)
    }

    private func collapsedRect(for geometry: ScreenDetector.NotchGeometry) -> NSRect {
        NSRect(
            x: geometry.notchRect.origin.x,
            y: geometry.notchRect.origin.y,
            width: geometry.notchWidth,
            height: geometry.notchHeight
        )
    }

    private func expandedRect(for geometry: ScreenDetector.NotchGeometry) -> NSRect {
        let size = expandedSize
        let maxAllowedWidth = (screenDetector.currentScreen?.frame.width ?? size.width) - 80
        let width = max(minimumExpandedWidth, min(size.width, maxAllowedWidth))
        let height = size.height
        let centerX = geometry.notchRect.midX - width / 2
        let topY = geometry.notchRect.maxY - height

        return NSRect(x: centerX, y: topY, width: width, height: height)
    }

    private func peekRect(for geometry: ScreenDetector.NotchGeometry) -> NSRect {
        let width: CGFloat = 360
        let height: CGFloat = 102
        let centerX = geometry.notchRect.midX - width / 2
        let topY = geometry.notchRect.maxY - height

        return NSRect(x: centerX, y: topY, width: width, height: height)
    }

    private var expandedSize: CGSize {
        switch settingsService.panelSizePreset {
        case "compact":
            return CGSize(width: 580, height: 352)
        case "roomy":
            return CGSize(width: 660, height: 404)
        default:
            return CGSize(width: 620, height: 376)
        }
    }

    func tearDown() {
        mousePollingTimer?.invalidate()
        mousePollingTimer = nil
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    deinit {
        tearDown()
    }
}
