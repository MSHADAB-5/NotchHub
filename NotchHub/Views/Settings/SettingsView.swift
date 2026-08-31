import SwiftUI

/// Settings window content.
struct SettingsView: View {
    @ObservedObject var settings: SettingsService
    @ObservedObject var widgetRegistry: WidgetRegistry

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NotchHub Settings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    generalSection
                    layoutSection
                    clockSection
                    widgetsSection
                    aboutSection
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 580)
    }

    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("General")

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            Toggle("Expand on Hover", isOn: $settings.expandOnHover)
            Toggle("Peek Notifications", isOn: $settings.peekNotificationsEnabled)
            Toggle("Haptic Feedback", isOn: $settings.hapticFeedback)

            HStack {
                Text("Collapse Delay")
                Spacer()
                Picker("", selection: $settings.collapseDelay) {
                    Text("Instant").tag(0.0)
                    Text("0.3s").tag(0.3)
                    Text("0.5s").tag(0.5)
                    Text("1.0s").tag(1.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
        }
    }

    @ViewBuilder
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Layout")

            Text("Choose the default tab and how roomy the expanded notch panel should feel.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack {
                Text("Default Tab")
                Spacer()
                Picker("", selection: defaultWidgetBinding) {
                    ForEach(WidgetPage.allCases) { page in
                        Text(tabLabel(page)).tag(page.settingsKey)
                    }
                }
                .frame(width: 220)
                .pickerStyle(.menu)
            }

            HStack {
                Text("Panel Size")
                Spacer()
                Picker("", selection: $settings.panelSizePreset) {
                    Text("Compact").tag("compact")
                    Text("Standard").tag("standard")
                    Text("Roomy").tag("roomy")
                }
                .frame(width: 220)
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var clockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Nook Clock")

            Text("Choose the timezone for the second clock shown in the Nook tab.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack {
                Text("Reference Zone")
                Spacer()
                Picker("", selection: $settings.referenceClockTimeZoneIdentifier) {
                    ForEach(clockTimeZoneOptions) { option in
                        Text(option.label).tag(option.identifier)
                    }
                }
                .frame(width: 220)
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Widgets")

            Text("Choose which widgets appear in the notch panel.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            ForEach(WidgetPage.allCases) { page in
                Toggle(isOn: widgetBinding(for: page)) {
                    HStack(spacing: 8) {
                        Image(systemName: page.icon)
                            .frame(width: 20)
                        Text(page.rawValue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("About")

            HStack {
                Text("NotchHub")
                    .font(.system(size: 13, weight: .medium))
                Text("v1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Text("A native macOS notch utility app.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.primary)
    }

    private var defaultWidgetBinding: Binding<String> {
        Binding(
            get: { settings.defaultWidgetKey },
            set: { newValue in
                settings.defaultWidgetKey = newValue
                if let page = WidgetPage.from(settingsKey: newValue),
                   settings.enabledWidgets.contains(page.settingsKey) {
                    widgetRegistry.currentPage = page
                }
            }
        )
    }

    private func widgetBinding(for page: WidgetPage) -> Binding<Bool> {
        Binding(
            get: { settings.enabledWidgets.contains(page.settingsKey) },
            set: { enabled in
                if enabled {
                    settings.enabledWidgets.insert(page.settingsKey)
                } else {
                    settings.enabledWidgets.remove(page.settingsKey)
                }

                widgetRegistry.enabledPages = WidgetPage.allCases.filter {
                    settings.enabledWidgets.contains($0.settingsKey)
                }

                if !widgetRegistry.enabledPages.contains(widgetRegistry.currentPage),
                   let fallback = preferredAvailablePage() {
                    widgetRegistry.currentPage = fallback
                }
            }
        )
    }

    private func preferredAvailablePage() -> WidgetPage? {
        if let preferred = WidgetPage.from(settingsKey: settings.defaultWidgetKey),
           settings.enabledWidgets.contains(preferred.settingsKey) {
            return preferred
        }
        return widgetRegistry.enabledPages.first
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

    private struct ClockTimeZoneOption: Identifiable {
        let identifier: String
        let label: String
        var id: String { identifier }
    }

    private var clockTimeZoneOptions: [ClockTimeZoneOption] {
        [
            ClockTimeZoneOption(identifier: "Europe/Paris", label: "CET/CEST - Paris"),
            ClockTimeZoneOption(identifier: "Europe/Berlin", label: "CET/CEST - Berlin"),
            ClockTimeZoneOption(identifier: "Europe/Madrid", label: "CET/CEST - Madrid"),
            ClockTimeZoneOption(identifier: "Europe/Rome", label: "CET/CEST - Rome"),
            ClockTimeZoneOption(identifier: "Europe/Zurich", label: "CET/CEST - Zurich"),
            ClockTimeZoneOption(identifier: "Europe/London", label: "UK - London"),
            ClockTimeZoneOption(identifier: "UTC", label: "UTC"),
            ClockTimeZoneOption(identifier: "America/New_York", label: "US Eastern - New York"),
            ClockTimeZoneOption(identifier: "America/Los_Angeles", label: "US Pacific - Los Angeles"),
            ClockTimeZoneOption(identifier: "Asia/Dubai", label: "Gulf - Dubai"),
            ClockTimeZoneOption(identifier: "Asia/Kolkata", label: "India - Kolkata"),
            ClockTimeZoneOption(identifier: "Asia/Tokyo", label: "Japan - Tokyo"),
            ClockTimeZoneOption(identifier: "Australia/Sydney", label: "Australia - Sydney")
        ]
    }
}
