import Foundation
import Combine
import ServiceManagement

/// Persists user preferences and manages launch-at-login.
final class SettingsService: ObservableObject {

    // MARK: - Persisted Settings

    @Published var launchAtLogin: Bool {
        didSet { setLaunchAtLogin(launchAtLogin) }
    }

    @Published var enabledWidgets: Set<String> {
        didSet { save() }
    }

    @Published var expandOnHover: Bool {
        didSet { save() }
    }

    @Published var collapseDelay: Double {
        didSet { save() }
    }

    @Published var hapticFeedback: Bool {
        didSet { save() }
    }

    @Published var referenceClockTimeZoneIdentifier: String {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let enabledWidgets = "enabledWidgets"
        static let expandOnHover = "expandOnHover"
        static let collapseDelay = "collapseDelay"
        static let hapticFeedback = "hapticFeedback"
        static let referenceClockTimeZoneIdentifier = "referenceClockTimeZoneIdentifier"
    }

    init() {
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        expandOnHover = defaults.object(forKey: Keys.expandOnHover) as? Bool ?? true
        collapseDelay = defaults.object(forKey: Keys.collapseDelay) as? Double ?? 0.3
        hapticFeedback = defaults.object(forKey: Keys.hapticFeedback) as? Bool ?? true
        referenceClockTimeZoneIdentifier =
            defaults.string(forKey: Keys.referenceClockTimeZoneIdentifier) ?? "Europe/Paris"

        if let saved = defaults.stringArray(forKey: Keys.enabledWidgets) {
            enabledWidgets = Set(saved)
        } else {
            // All enabled by default
            enabledWidgets = Set(["media", "quickActions", "battery", "clipboard", "timer"])
        }
    }

    private func save() {
        defaults.set(Array(enabledWidgets), forKey: Keys.enabledWidgets)
        defaults.set(expandOnHover, forKey: Keys.expandOnHover)
        defaults.set(collapseDelay, forKey: Keys.collapseDelay)
        defaults.set(hapticFeedback, forKey: Keys.hapticFeedback)
        defaults.set(referenceClockTimeZoneIdentifier, forKey: Keys.referenceClockTimeZoneIdentifier)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.launchAtLogin)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("[NotchHub] Launch at login error: %@", error.localizedDescription)
            }
        }
    }
}
