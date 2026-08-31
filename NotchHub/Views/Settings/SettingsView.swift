import SwiftUI

/// Settings window content.
struct SettingsView: View {
    @ObservedObject var settings: SettingsService
    @ObservedObject var widgetRegistry: WidgetRegistry

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
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
                    clockSection
                    widgetsSection
                    aboutSection
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 520)
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("General")

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)

            Toggle("Expand on Hover", isOn: $settings.expandOnHover)

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

            Toggle("Haptic Feedback", isOn: $settings.hapticFeedback)
        }
    }

    // MARK: - Nook Clock

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

    // MARK: - Widgets

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

    // MARK: - About

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

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.primary)
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
                // Update the registry's enabled pages
                widgetRegistry.enabledPages = WidgetPage.allCases.filter {
                    settings.enabledWidgets.contains($0.settingsKey)
                }
            }
        )
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

// MARK: - WidgetPage settings key mapping

extension WidgetPage {
    var settingsKey: String {
        switch self {
        case .media: return "media"
        case .quickActions: return "quickActions"
        case .battery: return "battery"
        case .clipboard: return "clipboard"
        case .timer: return "timer"
        }
    }
}
