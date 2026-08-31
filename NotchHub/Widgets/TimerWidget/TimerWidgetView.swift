import SwiftUI

/// Full Pomodoro timer widget with work/short-rest/long-rest cycles.
/// Pauses between intervals and shows a confirm prompt before continuing.
struct TimerWidgetView: View {
    @ObservedObject var service: TimerService

    var body: some View {
        VStack(spacing: 10) {
            header

            if service.phase == .idle {
                idleView
            } else if service.isWaiting {
                confirmView
            } else {
                activeView
            }
        }
        .glassCard(cornerRadius: 16, padding: 12)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Label("TIMER", systemImage: "timer")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))

            Spacer(minLength: 8)

            headerStatusChip
        }
    }

    private var headerStatusChip: some View {
        let status = headerStatus

        return HStack(spacing: 5) {
            Circle()
                .fill(status.tint)
                .frame(width: 5, height: 5)
            Text(status.title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.65)
                .foregroundColor(status.tint)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            Capsule(style: .continuous)
                .fill(status.tint.opacity(0.11))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(status.tint.opacity(0.14), lineWidth: 0.5)
        )
    }

    private var headerStatus: (title: String, tint: Color) {
        switch service.timerState {
        case .idle:
            return ("SETUP", .white.opacity(0.42))
        case .running:
            return (service.phase.rawValue.uppercased(), phaseColor)
        case .paused:
            return ("PAUSED", Color(red: 1.0, green: 0.79, blue: 0.55))
        case .waitingConfirm:
            return ("COMPLETE", phaseColor)
        }
    }

    // MARK: - Idle View

    @ViewBuilder
    private var idleView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 11) {
                timerDial(
                    progress: 0,
                    time: formattedMinutes(service.workMinutes),
                    size: 62,
                    lineWidth: 4.5,
                    accent: focusColor
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to focus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Set a rhythm, then start one clean sprint.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.46))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(innerSurface)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    settingCard(
                        title: "Focus",
                        value: $service.workMinutes,
                        options: [15, 20, 25, 30, 45, 60],
                        suffix: "m",
                        accent: focusColor
                    )
                    settingCard(
                        title: "Short",
                        value: $service.shortRestMinutes,
                        options: [3, 5, 10],
                        suffix: "m",
                        accent: shortBreakColor
                    )
                }

                HStack(spacing: 6) {
                    settingCard(
                        title: "Long",
                        value: $service.longRestMinutes,
                        options: [10, 15, 20, 30],
                        suffix: "m",
                        accent: longBreakColor
                    )
                    settingCard(
                        title: "Cycle",
                        value: $service.intervalsBeforeLong,
                        options: [2, 3, 4, 6],
                        suffix: "x",
                        accent: .white.opacity(0.76)
                    )
                }
            }

            Button(action: { service.start() }) {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Start Focus")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    focusColor,
                                    Color(red: 0.55, green: 0.88, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func settingCard(
        title: String,
        value: Binding<Int>,
        options: [Int],
        suffix: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.4))

            HStack(spacing: 5) {
                settingStepperButton(symbol: "minus") {
                    value.wrappedValue = adjacentOption(
                        current: value.wrappedValue,
                        options: options,
                        direction: -1
                    )
                }

                Text("\(value.wrappedValue)\(suffix)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(accent)
                    .frame(maxWidth: .infinity)

                settingStepperButton(symbol: "plus") {
                    value.wrappedValue = adjacentOption(
                        current: value.wrappedValue,
                        options: options,
                        direction: 1
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(innerSurface)
    }

    @ViewBuilder
    private func settingStepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.58))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(.white.opacity(0.055))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active View

    @ViewBuilder
    private var activeView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                timerDial(
                    progress: service.progress,
                    time: service.displayTime,
                    size: 84,
                    lineWidth: 5.5,
                    accent: phaseColor
                )

                VStack(alignment: .leading, spacing: 7) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.phase.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text(activeSubtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.46))
                    }

                    HStack(spacing: 8) {
                        primaryControlButton(
                            symbol: service.isRunning ? "pause.fill" : "play.fill",
                            tint: phaseColor,
                            action: { service.togglePause() }
                        )

                        secondaryControlButton(symbol: "forward.fill", action: { service.skip() })
                        secondaryControlButton(symbol: "stop.fill", action: { service.stop() })
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(innerSurface)

            HStack(spacing: 8) {
                sessionDots

                Spacer(minLength: 8)

                Text(sessionSummary)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.42))
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func timerDial(
        progress: Double,
        time: String,
        size: CGFloat,
        lineWidth: CGFloat,
        accent: Color
    ) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.045))

            Circle()
                .stroke(.white.opacity(0.07), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(progress, 1))))
                .stroke(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.35), value: progress)

            VStack(spacing: 2) {
                Text(time)
                    .font(.system(size: size > 80 ? 19 : 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                if size > 80 {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.34))
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: accent.opacity(service.isRunning ? 0.14 : 0.06), radius: 10)
    }

    @ViewBuilder
    private func primaryControlButton(symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func secondaryControlButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.56))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.white.opacity(0.055))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Confirm View

    @ViewBuilder
    private var confirmView: some View {
        let nextColor = colorForPhase(service.pendingNextPhase)
        let isCycleComplete = service.phase == .longRest && service.pendingNextPhase == .work

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(phaseColor.opacity(0.13))
                    Image(systemName: isCycleComplete ? "checkmark.circle" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(phaseColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCycleComplete ? "Pomodoro cycle complete" : "\(service.phase.rawValue) complete")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(isCycleComplete ? "Do you want to repeat the session?" : "Your next block is ready.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.46))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)
                sessionDots
            }
            .padding(8)
            .background(innerSurface)

            VStack(spacing: 5) {
                Text(isCycleComplete ? "SESSION" : "UP NEXT")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.36))

                Text(isCycleComplete ? "Repeat or end" : service.pendingNextPhase.rawValue)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(nextColor)
            }

            HStack(spacing: 10) {
                Button(action: { service.stop() }) {
                    Text(isCycleComplete ? "End Session" : "Stop")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.52))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(0.055))
                        )
                }
                .buttonStyle(.plain)

                Button(action: { service.confirmNext() }) {
                    HStack(spacing: 6) {
                        Image(systemName: isCycleComplete ? "arrow.clockwise" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(isCycleComplete ? "Repeat Session" : "Start Next")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(nextColor)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shared Components

    private var innerSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.055), lineWidth: 0.5)
            )
    }

    private var sessionDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<service.intervalsBeforeLong, id: \.self) { index in
                let isCompleted = index < service.completedIntervals
                let isActive = index == service.completedIntervals && service.phase == .work

                Circle()
                    .fill(
                        isCompleted
                            ? phaseColor
                            : (isActive ? phaseColor.opacity(0.45) : .white.opacity(0.11))
                    )
                    .frame(width: isActive ? 7 : 6, height: isActive ? 7 : 6)
            }
        }
    }

    private var activeSubtitle: String {
        if service.isRunning {
            return "Running · \(service.totalSeconds / 60)m block"
        }
        return "Paused · \(service.totalSeconds / 60)m block"
    }

    private var sessionSummary: String {
        let current = min(service.completedIntervals + (service.phase == .work ? 1 : 0), service.intervalsBeforeLong)
        if service.phase == .work {
            return "Round \(current) of \(service.intervalsBeforeLong)"
        }
        return "Next round starts after this break"
    }

    private func adjacentOption(current: Int, options: [Int], direction: Int) -> Int {
        let sorted = options.sorted()
        guard let index = sorted.firstIndex(of: current) else {
            return sorted.first ?? current
        }
        let nextIndex = min(max(index + direction, 0), sorted.count - 1)
        return sorted[nextIndex]
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        String(format: "%02d:00", minutes)
    }

    private var phaseColor: Color {
        colorForPhase(service.phase)
    }

    private var focusColor: Color {
        colorForPhase(.work)
    }

    private var shortBreakColor: Color {
        colorForPhase(.shortRest)
    }

    private var longBreakColor: Color {
        colorForPhase(.longRest)
    }

    private func colorForPhase(_ phase: TimerService.Phase) -> Color {
        switch phase {
        case .idle:      return .white
        case .work:      return Color(red: 0.35, green: 0.78, blue: 0.48)
        case .shortRest: return Color(red: 0.40, green: 0.72, blue: 1.0)
        case .longRest:  return Color(red: 0.85, green: 0.55, blue: 1.0)
        }
    }
}
