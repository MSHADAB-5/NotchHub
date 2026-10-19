import Foundation
import Combine
import ServiceManagement

/// Persists user preferences and manages launch-at-login.
final class SettingsService: ObservableObject {

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

    @Published var peekNotificationsEnabled: Bool {
        didSet { save() }
    }

    @Published var defaultWidgetKey: String {
        didSet { save() }
    }

    @Published var panelSizePreset: String {
        didSet { save() }
    }

    @Published var primaryClockTimeZoneIdentifier: String {
        didSet { save() }
    }

    @Published var referenceClockTimeZoneIdentifier: String {
        didSet { save() }
    }

    var primaryClockTimeZone: TimeZone {
        ClockTimeZone.resolve(primaryClockTimeZoneIdentifier)
    }

    var referenceClockTimeZone: TimeZone {
        ClockTimeZone.resolve(referenceClockTimeZoneIdentifier, fallback: ClockTimeZone.defaultReferenceIdentifier)
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let enabledWidgets = "enabledWidgets"
        static let expandOnHover = "expandOnHover"
        static let collapseDelay = "collapseDelay"
        static let hapticFeedback = "hapticFeedback"
        static let peekNotificationsEnabled = "peekNotificationsEnabled"
        static let defaultWidgetKey = "defaultWidgetKey"
        static let panelSizePreset = "panelSizePreset"
        static let primaryClockTimeZoneIdentifier = "primaryClockTimeZoneIdentifier"
        static let referenceClockTimeZoneIdentifier = "referenceClockTimeZoneIdentifier"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        expandOnHover = defaults.object(forKey: Keys.expandOnHover) as? Bool ?? true
        collapseDelay = defaults.object(forKey: Keys.collapseDelay) as? Double ?? 0.3
        hapticFeedback = defaults.object(forKey: Keys.hapticFeedback) as? Bool ?? true
        peekNotificationsEnabled = defaults.object(forKey: Keys.peekNotificationsEnabled) as? Bool ?? true
        defaultWidgetKey = defaults.string(forKey: Keys.defaultWidgetKey) ?? WidgetPage.media.settingsKey
        panelSizePreset = defaults.string(forKey: Keys.panelSizePreset) ?? "standard"
        primaryClockTimeZoneIdentifier = ClockTimeZone.validatedIdentifier(
            defaults.string(forKey: Keys.primaryClockTimeZoneIdentifier),
            fallback: ClockTimeZone.followMacIdentifier
        )
        referenceClockTimeZoneIdentifier = ClockTimeZone.validatedIdentifier(
            defaults.string(forKey: Keys.referenceClockTimeZoneIdentifier),
            fallback: ClockTimeZone.defaultReferenceIdentifier
        )

        if let saved = defaults.stringArray(forKey: Keys.enabledWidgets) {
            enabledWidgets = Set(saved)
        } else {
            enabledWidgets = Set(["media", "quickActions", "battery", "clipboard", "timer"])
        }

        if WidgetPage.from(settingsKey: defaultWidgetKey) == nil {
            defaultWidgetKey = WidgetPage.media.settingsKey
        }
        if !["compact", "standard", "roomy"].contains(panelSizePreset) {
            panelSizePreset = "standard"
        }
    }

    private func save() {
        defaults.set(Array(enabledWidgets), forKey: Keys.enabledWidgets)
        defaults.set(expandOnHover, forKey: Keys.expandOnHover)
        defaults.set(collapseDelay, forKey: Keys.collapseDelay)
        defaults.set(hapticFeedback, forKey: Keys.hapticFeedback)
        defaults.set(peekNotificationsEnabled, forKey: Keys.peekNotificationsEnabled)
        defaults.set(defaultWidgetKey, forKey: Keys.defaultWidgetKey)
        defaults.set(panelSizePreset, forKey: Keys.panelSizePreset)
        defaults.set(primaryClockTimeZoneIdentifier, forKey: Keys.primaryClockTimeZoneIdentifier)
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
