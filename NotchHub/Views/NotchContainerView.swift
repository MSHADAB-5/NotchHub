import SwiftUI

/// The main container view that switches between collapsed and expanded states.
struct NotchContainerView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var screenDetector: ScreenDetector
    @ObservedObject var nowPlayingService: NowPlayingService
    @ObservedObject var systemActionsService: SystemActionsService
    @ObservedObject var volumeService: VolumeService
    @ObservedObject var brightnessService: BrightnessService
    @ObservedObject var batteryService: BatteryService
    @ObservedObject var clipboardService: ClipboardService
    @ObservedObject var timerService: TimerService
    @ObservedObject var widgetRegistry: WidgetRegistry
    var onOpenSettings: (() -> Void)?

    private let panelShape = NotchShape(topCornerRadius: 8, bottomCornerRadius: 32)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if viewModel.isExpanded {
                    expandedPanel(size: geo.size)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    // MARK: - Expanded Panel

    @ViewBuilder
    private func expandedPanel(size: CGSize) -> some View {
        // Matte black panel with masked profile. No translucent edges.
        VStack(spacing: 0) {
            notchSpacer

            tabBar
                .padding(.horizontal, 16)
                .padding(.top, 2)

            // Subtle divider
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 14)
                .padding(.top, 5)

            // Keep main widget content below the physical camera housing while
            // leaving top controls near the top edge on both sides of the notch.
            if let geometry = screenDetector.geometry, geometry.isRealNotch {
                Color.clear.frame(height: max(0, geometry.notchHeight - 10))
            }

            // Widget content
            widgetContent
                .padding(.horizontal, 16)
                .padding(.top, 7)
                .padding(.bottom, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.98))
        .compositingGroup()
        .clipShape(panelShape, style: FillStyle(eoFill: false, antialiased: false))
        .overlay {
            panelShape
                .stroke(.black.opacity(0.7), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 3)
    }

    // MARK: - Notch Spacer

    @ViewBuilder
    private var notchSpacer: some View {
        if let geometry = screenDetector.geometry, geometry.isRealNotch {
            // Keep top controls close to the screen edge.
            Color.clear.frame(height: 0)
        } else {
            Color.clear.frame(height: 6)
        }
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        if let geometry = screenDetector.geometry, geometry.isRealNotch {
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(widgetRegistry.enabledPages) { page in
                        tabButton(page)
                    }
                }
                .padding(.leading, 2)

                Spacer(minLength: centerGap(for: geometry))

                HStack(spacing: 6) {
                    Button(action: { viewModel.togglePin() }) {
                        Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(viewModel.isPinned ? .yellow : .white.opacity(0.4))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Button(action: { onOpenSettings?() }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 2)
            }
        } else {
            HStack(spacing: 0) {
                HStack(spacing: 3) {
                    ForEach(widgetRegistry.enabledPages) { page in
                        tabButton(page)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button(action: { viewModel.togglePin() }) {
                        Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(viewModel.isPinned ? .yellow : .white.opacity(0.4))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Button(action: { onOpenSettings?() }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func centerGap(for geometry: ScreenDetector.NotchGeometry) -> CGFloat {
        // Keep controls close to the notch edges with minimal dead space.
        let proposed = geometry.notchWidth - 118
        return min(108, max(56, proposed))
    }

    @ViewBuilder
    private func tabButton(_ page: WidgetPage) -> some View {
        let isSelected = widgetRegistry.currentPage == page

        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { widgetRegistry.currentPage = page } }) {
            HStack(spacing: 6) {
                Image(systemName: page.icon)
                    .font(.system(size: 13, weight: .semibold))
                if isSelected {
                    Text(tabLabel(page))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.45))
            .padding(.horizontal, isSelected ? 10 : 0)
            .frame(minWidth: 34)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? .white.opacity(0.13) : .clear)
            )
        }
        .buttonStyle(.plain)
        .help(page.rawValue)
    }

    private func tabLabel(_ page: WidgetPage) -> String {
        switch page {
        case .media: return "Nook"
        case .quickActions: return "Actions"
        case .battery: return "Power"
        case .clipboard: return "Tray"
        case .timer: return "Timer"
        }
    }

    // MARK: - Widget Content

    @ViewBuilder
    private var widgetContent: some View {
        switch widgetRegistry.currentPage {
        case .media:
            MediaWidgetView(service: nowPlayingService,
                            volumeService: volumeService,
                            brightnessService: brightnessService)
        case .quickActions:
            QuickActionsWidgetView(service: systemActionsService)
        case .battery:
            BatteryWidgetView(service: batteryService)
        case .clipboard:
            ClipboardWidgetView(service: clipboardService)
        case .timer:
            TimerWidgetView(service: timerService)
        }
    }
}
