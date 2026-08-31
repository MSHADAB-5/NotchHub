import SwiftUI

/// Now-playing media controls with artwork, track info, playback controls,
/// plus volume and brightness sliders. Compact layout — no scrolling.
struct MediaWidgetView: View {
    @ObservedObject var service: NowPlayingService
    @ObservedObject var volumeService: VolumeService
    @ObservedObject var brightnessService: BrightnessService

    var body: some View {
        VStack(spacing: 10) {
            if service.nowPlaying.hasContent {
                nowPlayingContent
            } else {
                emptyState
            }

            hudSliders
        }
    }

    // MARK: - Now Playing

    @ViewBuilder
    private var nowPlayingContent: some View {
        VStack(spacing: 10) {
            // Track info + controls
            HStack(spacing: 14) {
                artworkView
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(service.nowPlaying.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(service.nowPlaying.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Playback controls
                HStack(spacing: 16) {
                    Button(action: { service.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)

                    Button(action: { service.togglePlayPause() }) {
                        Image(systemName: service.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: { service.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.06))
                )
            }

            // Progress bar
            if service.nowPlaying.duration > 0 {
                progressBar
            }
        }
        .glassCard(cornerRadius: 14, padding: 12)
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
        VStack(spacing: 8) {
            hudRow(
                icon: volumeIcon,
                value: volumeService.volume,
                onChanged: { volumeService.setVolume($0) },
                tint: .white,
                iconAction: { volumeService.toggleMute() }
            )

            if brightnessService.isAvailable {
                hudRow(
                    icon: brightnessService.brightness < 0.5 ? "sun.min.fill" : "sun.max.fill",
                    value: brightnessService.brightness,
                    onChanged: { brightnessService.setBrightness($0) },
                    tint: .yellow
                )
            }
        }
        .glassCard(cornerRadius: 14, padding: 12)
    }

    @ViewBuilder
    private func hudRow(
        icon: String,
        value: Float,
        onChanged: @escaping (Float) -> Void,
        tint: Color,
        iconAction: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 10) {
            if let iconAction {
                Button(action: iconAction) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(tint.opacity(0.8))
                        .frame(width: 18)
                }
                .buttonStyle(.plain)
                .help("Mute / Unmute")
            } else {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(tint.opacity(0.65))
                    .frame(width: 18)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.5), tint.opacity(0.3)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(value)))
                }
                .frame(height: 6)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let v = Float(drag.location.x / geo.size.width)
                            onChanged(max(0, min(1, v)))
                        }
                )
            }
            .frame(height: 26)

            Text("\(Int(value * 100))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 26, alignment: .trailing)
        }
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
                    colors: [.purple.opacity(0.4), .blue.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        let progress: CGFloat = service.nowPlaying.duration > 0
            ? CGFloat(service.nowPlaying.currentElapsed / service.nowPlaying.duration) : 0

        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08)).frame(height: 4)
                    Capsule().fill(.white.opacity(0.56))
                        .frame(width: max(0, geo.size.width * min(progress, 1.0)), height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text(formatTime(service.nowPlaying.currentElapsed))
                Spacer()
                Text(formatTime(service.nowPlaying.duration))
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
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
