import SwiftUI

/// Volume and brightness sliders with glass styling.
struct HUDWidgetView: View {
    @ObservedObject var volumeService: VolumeService
    @ObservedObject var brightnessService: BrightnessService

    var body: some View {
        VStack(spacing: 12) {
            // Volume
            hudSlider(
                icon: volumeIcon,
                value: volumeService.volume,
                onChanged: { volumeService.setVolume($0) },
                tint: .white
            )

            // Brightness
            if brightnessService.isAvailable {
                hudSlider(
                    icon: brightnessIcon,
                    value: brightnessService.brightness,
                    onChanged: { brightnessService.setBrightness($0) },
                    tint: .yellow
                )
            }
        }
        .glassCard()
    }

    @ViewBuilder
    private func hudSlider(icon: String, value: Float, onChanged: @escaping (Float) -> Void, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tint.opacity(0.7))
                .frame(width: 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.5), tint.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
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
            .frame(height: 28)

            Text("\(Int(value * 100))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 24, alignment: .trailing)
        }
    }

    private var volumeIcon: String {
        if volumeService.isMuted || volumeService.volume == 0 {
            return "speaker.slash.fill"
        } else if volumeService.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volumeService.volume < 0.66 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }

    private var brightnessIcon: String {
        brightnessService.brightness < 0.5 ? "sun.min.fill" : "sun.max.fill"
    }
}
