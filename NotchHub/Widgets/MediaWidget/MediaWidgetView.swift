import SwiftUI

/// Now-playing media controls with artwork, track info, playback controls,
/// plus volume and brightness sliders. Compact layout — no scrolling.
struct MediaWidgetView: View {
    @ObservedObject var service: NowPlayingService
    @ObservedObject var volumeService: VolumeService
    @ObservedObject var brightnessService: BrightnessService
    @ObservedObject var settingsService: SettingsService
    @State private var scrubbingElapsed: TimeInterval?

    var body: some View {
        VStack(spacing: 8) {
            if service.nowPlaying.hasContent {
                nowPlayingContent
            } else {
                emptyState
            }

            hudSliders
            clocksRow
        }
    }

    // MARK: - Now Playing

    @ViewBuilder
    private var nowPlayingContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                artworkView
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(service.nowPlaying.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(secondaryMetadata)
                        .font(.system(size: 12.5))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        statusChip(service.nowPlaying.isPlaying ? "Playing" : "Paused")

                        if !outputDeviceChipLabel.isEmpty {
                            statusChip(outputDeviceChipLabel)
                        } else if !service.nowPlaying.album.isEmpty {
                            statusChip("Album")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    transportButton(symbol: "backward.fill", size: 13, prominence: .secondary) {
                        service.previousTrack()
                    }

                    transportButton(
                        symbol: service.nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                        size: 16,
                        prominence: .primary
                    ) {
                        service.togglePlayPause()
                    }

                    transportButton(symbol: "forward.fill", size: 13, prominence: .secondary) {
                        service.nextTrack()
                    }
                }
            }

            if service.nowPlaying.duration > 0 {
                progressBar
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.05),
                                    .white.opacity(0.015),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
                }
                .overlay(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .purple.opacity(0.16),
                                    .orange.opacity(0.09)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blur(radius: 8)
                }
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.2))
            Text("Nothing playing")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 14, padding: 12)
    }

    // MARK: - HUD Sliders

    @ViewBuilder
    private var hudSliders: some View {
        HStack(spacing: 8) {
            compactHudTile(
                title: "Audio",
                icon: volumeIcon,
                value: volumeService.volume,
                onChanged: { volumeService.setVolume($0) },
                tint: .white,
                iconAction: { volumeService.toggleMute() }
            )

            if brightnessService.isAvailable {
                compactHudTile(
                    title: "Brightness",
                    icon: brightnessService.brightness < 0.5 ? "sun.min.fill" : "sun.max.fill",
                    value: brightnessService.brightness,
                    onChanged: { brightnessService.setBrightness($0) },
                    tint: .yellow
                )
            }
        }
    }

    @ViewBuilder
    private func compactHudTile(
        title: String,
        icon: String,
        value: Float,
        onChanged: @escaping (Float) -> Void,
        tint: Color,
        iconAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let iconAction {
                    Button(action: iconAction) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(tint.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .help("Mute / Unmute")
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(tint.opacity(0.72))
                }
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.62))
                Spacer(minLength: 4)
                Text("\(Int(value * 100))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.36))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.6), tint.opacity(0.35)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(value)))
                }
                .frame(height: 5)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let ratio = Float(drag.location.x / geo.size.width)
                            onChanged(max(0, min(1, ratio)))
                        }
                )
            }
            .frame(height: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Dual Clock

    @ViewBuilder
    private var clocksRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let localZone = TimeZone.current
            let targetZone = configuredReferenceTimeZone
            let localPlace = placeName(for: localZone)
            let targetPlace = placeName(for: targetZone)

            HStack(spacing: 8) {
                compactClockCard(
                    title: localPlace,
                    snapshot: clockSnapshot(for: now, timeZone: localZone),
                    accent: Color(red: 0.61, green: 0.91, blue: 0.76),
                    utcOffset: compactUTCOffsetString(for: localZone, at: now)
                )

                compactClockCard(
                    title: targetPlace,
                    snapshot: clockSnapshot(for: now, timeZone: targetZone),
                    accent: Color(red: 1.0, green: 0.79, blue: 0.55),
                    utcOffset: compactUTCOffsetString(for: targetZone, at: now)
                )
            }
        }
    }

    @ViewBuilder
    private func compactClockCard(
        title: String,
        snapshot: ClockSnapshot,
        accent: Color,
        utcOffset: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(snapshot.hoursMinutes)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(snapshot.seconds)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.54))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.bottom, 1)

            Text(snapshot.dateLabel)
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text(utcOffset)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .font(.system(size: 9.5))
            .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private var configuredReferenceTimeZone: TimeZone {
        TimeZone(identifier: settingsService.referenceClockTimeZoneIdentifier)
            ?? TimeZone(identifier: "Europe/Paris")
            ?? .current
    }

    private struct ClockSnapshot {
        let hoursMinutes: String
        let seconds: String
        let dateLabel: String
    }

    private enum TransportProminence {
        case primary
        case secondary
    }

    private static let hoursMinutesFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let secondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "ss"
        return formatter
    }()

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private var secondaryMetadata: String {
        let artist = service.nowPlaying.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let album = service.nowPlaying.album.trimmingCharacters(in: .whitespacesAndNewlines)

        if !artist.isEmpty && !album.isEmpty {
            return "\(artist) · \(album)"
        }
        if !artist.isEmpty {
            return artist
        }
        if !album.isEmpty {
            return album
        }
        return "Unknown source"
    }

    private var outputDeviceChipLabel: String {
        let name = volumeService.outputDeviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "" }
        if name.count <= 18 { return name }
        return String(name.prefix(17)) + "…"
    }

    @ViewBuilder
    private func statusChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.68))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.08))
            )
    }

    @ViewBuilder
    private func transportButton(
        symbol: String,
        size: CGFloat,
        prominence: TransportProminence,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(prominence == .primary ? .white : .white.opacity(0.78))
                .frame(width: prominence == .primary ? 34 : 30, height: prominence == .primary ? 34 : 30)
                .background(
                    Circle()
                        .fill(prominence == .primary ? .white.opacity(0.15) : .white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    private func clockSnapshot(for date: Date, timeZone: TimeZone) -> ClockSnapshot {
        Self.hoursMinutesFormatter.timeZone = timeZone
        Self.secondsFormatter.timeZone = timeZone
        Self.dateLabelFormatter.timeZone = timeZone

        let hoursMinutes = Self.hoursMinutesFormatter.string(from: date)
        let seconds = Self.secondsFormatter.string(from: date)
        let dateLabel = Self.dateLabelFormatter.string(from: date)

        return ClockSnapshot(
            hoursMinutes: hoursMinutes,
            seconds: seconds,
            dateLabel: dateLabel
        )
    }

    private func utcOffsetString(for timeZone: TimeZone, at date: Date) -> String {
        let totalMinutes = timeZone.secondsFromGMT(for: date) / 60
        let sign = totalMinutes >= 0 ? "+" : "-"
        let absoluteMinutes = abs(totalMinutes)
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    private func compactUTCOffsetString(for timeZone: TimeZone, at date: Date) -> String {
        let totalMinutes = timeZone.secondsFromGMT(for: date) / 60
        if totalMinutes == 0 { return "UTC" }

        let sign = totalMinutes > 0 ? "+" : "-"
        let absoluteMinutes = abs(totalMinutes)
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60

        if minutes == 0 {
            return "UTC \(sign)\(hours)"
        }
        return "UTC \(sign)\(hours):\(String(format: "%02d", minutes))"
    }

    private func placeName(for timeZone: TimeZone) -> String {
        let identifier = timeZone.identifier
        if let city = identifier.split(separator: "/").last {
            let formatted = city.replacingOccurrences(of: "_", with: " ")
            if !formatted.isEmpty {
                return formatted
            }
        }
        if let localized = timeZone.localizedName(for: .shortStandard, locale: .current), !localized.isEmpty {
            return localized
        }
        return identifier
    }

    private func shortZoneLabel(for timeZone: TimeZone, at date: Date) -> String {
        if let abbreviation = timeZone.abbreviation(for: date), !abbreviation.isEmpty {
            return abbreviation
        }
        return "UTC \(utcOffsetString(for: timeZone, at: date))"
    }

    // MARK: - Components

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = service.nowPlaying.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [.purple.opacity(0.45), .orange.opacity(0.28), .blue.opacity(0.32)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        let duration = service.nowPlaying.duration
        let liveElapsed = service.nowPlaying.currentElapsed
        let displayedElapsed = min(max(scrubbingElapsed ?? liveElapsed, 0), duration)
        let progress = duration > 0 ? min(max(CGFloat(displayedElapsed / duration), 0), 1) : 0
        let remaining = max(duration - displayedElapsed, 0)

        VStack(spacing: 5) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let fillWidth = width * progress

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .frame(height: 5)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.88, blue: 1.0),
                                    Color(red: 1.0, green: 0.78, blue: 0.56)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 5)

                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: scrubbingElapsed == nil ? 7 : 9, height: scrubbingElapsed == nil ? 7 : 9)
                        .offset(x: min(max(fillWidth - (scrubbingElapsed == nil ? 7 : 9), 0), width - (scrubbingElapsed == nil ? 7 : 9)))
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard service.nowPlaying.canSeek else { return }
                            let clampedProgress = min(max(value.location.x / width, 0), 1)
                            scrubbingElapsed = duration * clampedProgress
                        }
                        .onEnded { value in
                            guard service.nowPlaying.canSeek else {
                                scrubbingElapsed = nil
                                return
                            }
                            let clampedProgress = min(max(value.location.x / width, 0), 1)
                            let target = duration * clampedProgress
                            scrubbingElapsed = nil
                            service.seek(to: target)
                        }
                )
            }
            .frame(height: 12)

            HStack {
                Text(formatTime(displayedElapsed))
                Spacer()
                Text("-\(formatTime(remaining))")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white.opacity(0.34))
        }
    }

    private var volumeIcon: String {
        if volumeService.isMuted || volumeService.volume == 0 { return "speaker.slash.fill" }
        if volumeService.volume < 0.33 { return "speaker.wave.1.fill" }
        if volumeService.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}
