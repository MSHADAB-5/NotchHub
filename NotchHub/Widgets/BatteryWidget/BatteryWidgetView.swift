import SwiftUI

/// Battery levels for MacBook and Bluetooth peripherals.
struct BatteryWidgetView: View {
    @ObservedObject var service: BatteryService

    var body: some View {
        VStack(spacing: 10) {
            if service.macBattery.isAvailable {
                macRow
            }

            ForEach(service.peripherals) { device in
                peripheralRow(device)
            }

            if !service.macBattery.isAvailable && service.peripherals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "battery.0percent")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No battery info")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .glassCard(cornerRadius: 14, padding: 12)
    }

    @ViewBuilder
    private var macRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .trim(from: 0, to: CGFloat(service.macBattery.level) / 100)
                    .stroke(batteryColor(service.macBattery.level), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)

                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 3)
                    .frame(width: 36, height: 36)

                if service.macBattery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else {
                    Text("\(service.macBattery.level)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MacBook")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 6) {
                    Text("\(service.macBattery.level)%")
                        .font(.system(size: 12, design: .monospaced))

                    if service.macBattery.isCharging {
                        Text("Charging")
                            .foregroundColor(.green.opacity(0.8))
                    } else if service.macBattery.isPluggedIn {
                        Text("Plugged in")
                    }

                    if service.macBattery.timeRemaining > 0 {
                        Text(formatTime(service.macBattery.timeRemaining))
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func peripheralRow(_ device: BatteryService.PeripheralBattery) -> some View {
        HStack(spacing: 12) {
            Image(systemName: device.deviceType.icon)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 22)

            Text(device.name)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            Text("\(device.level)%")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(batteryColor(device.level))
        }
    }

    private func batteryColor(_ level: Int) -> Color {
        if level > 50 { return .green }
        if level > 20 { return .yellow }
        return .red
    }

    private func formatTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
