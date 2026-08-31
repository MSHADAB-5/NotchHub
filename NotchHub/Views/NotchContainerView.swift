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
    @ObservedObject var settingsService: SettingsService
    @ObservedObject var widgetRegistry: WidgetRegistry
    @State private var lastClipboardItemID: UUID?
    @State private var lastSavedItemCount = 0
    @State private var lastMutedState: Bool?
    @State private var lastTimerStateMarker = ""
    @State private var lastTrackSignature = ""
    var onOpenSettings: (() -> Void)?

    private let panelShape = NotchShape(topCornerRadius: 8, bottomCornerRadius: 32)

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                switch viewModel.state {
                case .peeking:
                    peekPanel
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                case .expanded, .pinned:
                    expandedPanel
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                case .collapsed, .hovering:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .onAppear(perform: seedPeekBaselines)
        .onReceive(clipboardService.$history, perform: handleClipboardHistory)
        .onReceive(clipboardService.$savedItems, perform: handleSavedItems)
        .onReceive(volumeService.$isMuted, perform: handleMuteState)
        .onReceive(timerService.$timerState) { _ in handleTimerStateChange() }
        .onReceive(nowPlayingService.$nowPlaying, perform: handleNowPlaying)
    }

    @ViewBuilder
    private var expandedPanel: some View {
        VStack(spacing: 0) {
            notchSpacer

            tabBar
                .padding(.horizontal, 16)
                .padding(.top, 2)

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 14)
                .padding(.top, 5)

            if let geometry = screenDetector.geometry, geometry.isRealNotch {
                Color.clear.frame(height: max(0, geometry.notchHeight - 10))
            }

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

    @ViewBuilder
    private var peekPanel: some View {
        let peek = viewModel.peekContent

        VStack(spacing: 0) {
            notchSpacer

            if let geometry = screenDetector.geometry, geometry.isRealNotch {
                Color.clear.frame(height: max(0, geometry.notchHeight - 8))
            } else {
                Color.clear.frame(height: 6)
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((peek?.tint ?? .white).opacity(0.18))
                    Image(systemName: peek?.systemImage ?? "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(peek?.tint ?? .white)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(peek?.title ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let subtitle = peek?.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.58))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

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

    @ViewBuilder
    private var notchSpacer: some View {
        if let geometry = screenDetector.geometry, geometry.isRealNotch {
            Color.clear.frame(height: 0)
        } else {
            Color.clear.frame(height: 6)
        }
    }

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

    @ViewBuilder
    private var widgetContent: some View {
        switch widgetRegistry.currentPage {
        case .media:
            MediaWidgetView(
                service: nowPlayingService,
                volumeService: volumeService,
                brightnessService: brightnessService,
                settingsService: settingsService
            )
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

    private func seedPeekBaselines() {
        lastClipboardItemID = clipboardService.history.first?.id
        lastSavedItemCount = clipboardService.savedItems.count
        lastMutedState = volumeService.isMuted
        lastTimerStateMarker = timerStateMarker()
        lastTrackSignature = trackSignature(for: nowPlayingService.nowPlaying)
    }

    private func handleClipboardHistory(_ history: [ClipboardService.ClipboardItem]) {
        guard let first = history.first else { return }
        guard first.id != lastClipboardItemID else { return }
        lastClipboardItemID = first.id
        presentPeek(
            id: "clipboard.copy.\(first.id.uuidString)",
            systemImage: first.kind.icon,
            title: "Copied to Tray",
            subtitle: first.preview,
            tint: peekTint(for: first.kind),
            duration: 2.2
        )
    }

    private func handleSavedItems(_ items: [ClipboardService.ClipboardItem]) {
        if items.count > lastSavedItemCount, let first = items.first {
            presentPeek(
                id: "clipboard.saved.\(first.id.uuidString)",
                systemImage: "star.fill",
                title: "Saved to Tray",
                subtitle: first.preview,
                tint: .yellow,
                duration: 2.0
            )
        }
        lastSavedItemCount = items.count
    }

    private func handleMuteState(_ isMuted: Bool) {
        guard let lastMutedState else {
            self.lastMutedState = isMuted
            return
        }
        guard isMuted != lastMutedState else { return }
        self.lastMutedState = isMuted
        presentPeek(
            id: "audio.mute.\(isMuted)",
            systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            title: isMuted ? "Audio muted" : "Audio restored",
            subtitle: volumeService.outputDeviceName,
            tint: .white,
            duration: 1.6
        )
    }

    private func handleTimerStateChange() {
        let marker = timerStateMarker()
        guard marker != lastTimerStateMarker else { return }
        lastTimerStateMarker = marker

        guard marker == "waitingConfirm" else { return }

        let isCycleComplete = timerService.phase == .longRest && timerService.pendingNextPhase == .work
        presentPeek(
            id: "timer.\(timerService.phase.rawValue).\(timerService.pendingNextPhase.rawValue)",
            systemImage: "timer",
            title: isCycleComplete ? "Pomodoro cycle complete" : "\(timerService.phase.rawValue) complete",
            subtitle: isCycleComplete ? "Repeat session or end it" : "Next: \(timerService.pendingNextPhase.rawValue)",
            tint: timerTint,
            duration: 3.0
        )
    }

    private func handleNowPlaying(_ info: NowPlayingService.NowPlayingInfo) {
        let signature = trackSignature(for: info)
        if signature.isEmpty {
            lastTrackSignature = ""
            return
        }
        if lastTrackSignature.isEmpty {
            lastTrackSignature = signature
            return
        }
        guard signature != lastTrackSignature else { return }
        lastTrackSignature = signature

        presentPeek(
            id: "media.\(signature)",
            systemImage: "music.note",
            title: info.title,
            subtitle: info.artist.isEmpty ? info.album : info.artist,
            tint: Color(red: 0.62, green: 0.9, blue: 1.0),
            duration: 2.6
        )
    }

    private func presentPeek(
        id: String,
        systemImage: String,
        title: String,
        subtitle: String,
        tint: Color,
        duration: TimeInterval
    ) {
        guard settingsService.peekNotificationsEnabled else { return }
        switch viewModel.state {
        case .expanded, .pinned:
            return
        default:
            break
        }
        viewModel.showPeek(
            id: id,
            systemImage: systemImage,
            title: title,
            subtitle: subtitle,
            tint: tint,
            duration: duration
        )
    }

    private func trackSignature(for info: NowPlayingService.NowPlayingInfo) -> String {
        let title = info.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = info.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "" }
        return title + "|" + artist
    }

    private func timerStateMarker() -> String {
        switch timerService.timerState {
        case .idle: return "idle"
        case .running: return "running"
        case .paused: return "paused"
        case .waitingConfirm: return "waitingConfirm"
        }
    }

    private var timerTint: Color {
        switch timerService.pendingNextPhase {
        case .work:
            return Color(red: 0.35, green: 0.78, blue: 0.48)
        case .shortRest:
            return Color(red: 0.4, green: 0.72, blue: 1.0)
        case .longRest:
            return Color(red: 0.85, green: 0.55, blue: 1.0)
        case .idle:
            return .white
        }
    }

    private func peekTint(for kind: ClipboardService.ClipboardItem.ContentKind) -> Color {
        switch kind {
        case .text:
            return .white
        case .link:
            return Color(red: 0.54, green: 0.86, blue: 1.0)
        case .code:
            return Color(red: 0.97, green: 0.77, blue: 0.49)
        }
    }
}
