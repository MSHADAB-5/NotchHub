import SwiftUI

/// Full Pomodoro timer widget with work/short-rest/long-rest cycles.
/// Pauses between intervals and shows a confirm prompt before continuing.
struct TimerWidgetView: View {
    @ObservedObject var service: TimerService

    var body: some View {
        VStack(spacing: 10) {
            if service.phase == .idle {
                idleView
            } else if service.isWaiting {
                confirmView
            } else {
                activeView
            }
        }
        .glassCard(cornerRadius: 14, padding: 12)
    }

    // MARK: - Idle View (setup)

    @ViewBuilder
    private var idleView: some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                presetRow(label: "Focus", value: $service.workMinutes, options: [15, 20, 25, 30, 45, 60])
                presetRow(label: "Short Break", value: $service.shortRestMinutes, options: [3, 5, 10])
                presetRow(label: "Long Break", value: $service.longRestMinutes, options: [10, 15, 20, 30])
                presetRow(label: "Intervals", value: $service.intervalsBeforeLong, options: [2, 3, 4, 6])
            }

            Button(action: { service.start() }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Start Focus")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.29, green: 0.92, blue: 0.34), Color(red: 0.22, green: 0.79, blue: 0.30)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func presetRow(label: String, value: Binding<Int>, options: [Int]) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 80, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(options, id: \.self) { opt in
                    Button(action: { value.wrappedValue = opt }) {
                        Text("\(opt)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(value.wrappedValue == opt ? .white : .white.opacity(0.35))
                            .frame(width: 30, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(value.wrappedValue == opt ? Color(red: 0.27, green: 0.78, blue: 0.42).opacity(0.35) : .white.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Active View (running/paused)

    @ViewBuilder
    private var activeView: some View {
        VStack(spacing: 10) {
            // Phase indicator + interval dots
            HStack(spacing: 6) {
                Circle()
                    .fill(phaseColor)
                    .frame(width: 7, height: 7)

                Text(service.phase.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                // Interval dots
                HStack(spacing: 4) {
                    ForEach(0..<service.intervalsBeforeLong, id: \.self) { i in
                        let isCompleted = i < service.completedIntervals
                        let isActive = (i == service.completedIntervals) && service.phase == .work
                        Circle()
                            .fill(isCompleted ? phaseColor : (isActive ? phaseColor.opacity(0.6) : .white.opacity(0.12)))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            // Timer ring + controls
            HStack(spacing: 20) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.06), lineWidth: 4)

                    Circle()
                        .trim(from: 0, to: CGFloat(service.progress))
                        .stroke(
                            phaseColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: service.progress)
                }
                .frame(width: 72, height: 72)
                .overlay(
                    Text(service.displayTime)
                        .font(.system(size: 18, weight: .light, design: .monospaced))
                        .foregroundColor(.white)
                )

                // Controls
                VStack(spacing: 10) {
                    Button(action: { service.togglePause() }) {
                        Image(systemName: service.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(phaseColor))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        Button(action: { service.skip() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)

                        Button(action: { service.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Confirm View (waiting between intervals)

    @ViewBuilder
    private var confirmView: some View {
        VStack(spacing: 14) {
            // What just finished
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(phaseColor)

                Text("\(service.phase.rawValue) complete!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Interval dots
                HStack(spacing: 4) {
                    ForEach(0..<service.intervalsBeforeLong, id: \.self) { i in
                        Circle()
                            .fill(i < service.completedIntervals ? phaseColor : .white.opacity(0.12))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            // Next phase prompt
            let nextColor = colorForPhase(service.pendingNextPhase)

            VStack(spacing: 10) {
                Text("Up next:")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))

                Text(service.pendingNextPhase.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(nextColor)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { service.stop() }) {
                    Text("Stop")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button(action: { service.confirmNext() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("Start \(service.pendingNextPhase.rawValue)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(nextColor)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var phaseColor: Color {
        Color(red: service.phaseColor.r, green: service.phaseColor.g, blue: service.phaseColor.b)
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
