import Foundation
import IOKit.ps
import Combine

/// Monitors MacBook battery state and connected Bluetooth device battery levels.
final class BatteryService: ObservableObject {

    struct BatteryInfo {
        var level: Int = -1           // 0–100, -1 if unavailable
        var isCharging: Bool = false
        var isPluggedIn: Bool = false
        var timeRemaining: Int = -1   // minutes, -1 if unknown
        var isAvailable: Bool { level >= 0 }
    }

    struct PeripheralBattery: Identifiable {
        let id: String               // device address or name
        let name: String
        let level: Int               // 0–100
        let deviceType: DeviceType

        enum DeviceType: String {
            case mouse, keyboard, headphones, trackpad, gamepad, unknown
            var icon: String {
                switch self {
                case .mouse: return "computermouse.fill"
                case .keyboard: return "keyboard.fill"
                case .headphones: return "headphones"
                case .trackpad: return "trackpad.fill"
                case .gamepad: return "gamecontroller.fill"
                case .unknown: return "battery.100percent"
                }
            }
        }
    }

    @Published private(set) var macBattery = BatteryInfo()
    @Published private(set) var peripherals: [PeripheralBattery] = []

    private var refreshTimer: Timer?

    init() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let timer = refreshTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func refresh() {
        fetchMacBattery()
        fetchPeripherals()
    }

    // MARK: - Mac Battery via IOKit Power Sources

    private func fetchMacBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              !sources.isEmpty else {
            macBattery = BatteryInfo()
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?
                    .takeUnretainedValue() as? [String: Any] else { continue }

            let type = desc[kIOPSTypeKey] as? String
            guard type == kIOPSInternalBatteryType else { continue }

            var info = BatteryInfo()
            info.level = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
            info.isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false

            let powerSource = desc[kIOPSPowerSourceStateKey] as? String
            info.isPluggedIn = powerSource == kIOPSACPowerValue

            info.timeRemaining = desc[kIOPSTimeToEmptyKey] as? Int ?? -1
            if info.isCharging {
                info.timeRemaining = desc[kIOPSTimeToFullChargeKey] as? Int ?? -1
            }

            macBattery = info
            return
        }
    }

    // MARK: - Bluetooth Peripherals via IORegistry

    private func fetchPeripherals() {
        var result: [PeripheralBattery] = []

        // Look for Bluetooth HID devices with battery info in IORegistry
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            peripherals = result
            return
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            // Get battery percent
            guard let batteryProp = IORegistryEntryCreateCFProperty(service, "BatteryPercent" as CFString, nil, 0),
                  let level = batteryProp.takeRetainedValue() as? Int else { continue }

            // Get product name
            let nameProp = IORegistryEntryCreateCFProperty(service, "Product" as CFString, nil, 0)
            let name = (nameProp?.takeRetainedValue() as? String) ?? "Unknown Device"

            // Determine device type from name
            let deviceType = classifyDevice(name)

            result.append(PeripheralBattery(
                id: name,
                name: name,
                level: level,
                deviceType: deviceType
            ))
        }

        peripherals = result
    }

    private func classifyDevice(_ name: String) -> PeripheralBattery.DeviceType {
        let lower = name.lowercased()
        if lower.contains("mouse") || lower.contains("magic mouse") { return .mouse }
        if lower.contains("keyboard") { return .keyboard }
        if lower.contains("trackpad") { return .trackpad }
        if lower.contains("airpod") || lower.contains("headphone") || lower.contains("beats") { return .headphones }
        if lower.contains("controller") || lower.contains("gamepad") || lower.contains("dualshock") || lower.contains("dualsense") { return .gamepad }
        return .unknown
    }
}
