import AppKit
import SwiftUI

/// Manages the NSStatusItem (menu bar icon) for NotchHub.
final class MenuBarController {

    private var statusItem: NSStatusItem?
    private let viewModel: NotchViewModel
    private var settingsWindow: NSWindow?
    var settingsService: SettingsService?
    var widgetRegistry: WidgetRegistry?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                   accessibilityDescription: "NotchHub")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show NotchHub", action: #selector(toggleNotch), keyEquivalent: "n")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About NotchHub", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NotchHub", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleNotch() {
        if viewModel.isExpanded {
            viewModel.dismiss()
        } else {
            viewModel.mouseEntered()
        }
    }

    @objc func showSettings() {
        guard let settings = settingsService, let registry = widgetRegistry else { return }

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settings: settings, widgetRegistry: registry)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "NotchHub Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
