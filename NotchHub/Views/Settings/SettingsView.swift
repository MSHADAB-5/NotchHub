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
            sectionHeader("Nook Clocks")

            Text("Choose a location for each clock, or let either one follow your Mac.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            ClockLocationPicker(title: "Clock 1", selection: $settings.primaryClockTimeZoneIdentifier)
            ClockLocationPicker(
                title: "Clock 2",
                selection: $settings.referenceClockTimeZoneIdentifier,
                fallbackIdentifier: ClockTimeZone.defaultReferenceIdentifier
            )
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
}

private struct ClockLocationPicker: View {
    let title: String
    @Binding var selection: String
    var fallbackIdentifier = ClockTimeZone.followMacIdentifier
    @State private var isChoosing = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let zone = ClockTimeZone.resolve(selection, fallback: fallbackIdentifier)
            Button(action: { isChoosing.toggle() }) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 48, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selection == ClockTimeZone.followMacIdentifier ? "Follow Mac" : ClockTimeZone.placeName(for: zone))
                            .font(.system(size: 13, weight: .medium))
                        Text("\(zone.identifier) · \(ClockTimeZone.utcOffsetString(for: zone, at: context.date))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .lineLimit(1)

                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) location")
            .help("Choose a location for \(title)")
        }
        .popover(isPresented: $isChoosing, arrowEdge: .trailing) {
            locationChooser
        }
        .onChange(of: isChoosing) { choosing in
            if !choosing { searchText = "" }
        }
    }

    private var locationChooser: some View {
        let options = ClockTimeZone.options(matching: searchText)
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(title) Location")
                .font(.system(size: 13, weight: .semibold))
            TextField("Search cities or time zones", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onAppear { isSearchFocused = true }

            locationRow(
                title: "Follow Mac",
                subtitle: ClockTimeZone.placeName(for: .autoupdatingCurrent),
                identifier: ClockTimeZone.followMacIdentifier
            )
            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(options) { option in
                        locationRow(title: option.label, subtitle: option.identifier, identifier: option.identifier)
                    }
                    if options.isEmpty {
                        Text("No matching locations")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
            }
            .frame(height: 240)
        }
        .padding(14)
        .frame(width: 320)
    }

    private func locationRow(title: String, subtitle: String, identifier: String) -> some View {
        Button {
            selection = identifier
            isChoosing = false
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 4)
                if selection == identifier {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(selection == identifier ? 0.1 : 0.001))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
