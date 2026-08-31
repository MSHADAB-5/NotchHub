import AppKit
import SwiftUI
import Combine

/// Main application delegate — sets up the notch panel and menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var screenDetector: ScreenDetector!
    private var viewModel: NotchViewModel!
    private var windowController: NotchWindowController!
    private var menuBarController: MenuBarController!
    private var nowPlayingService: NowPlayingService!
    private var systemActionsService: SystemActionsService!
    private var volumeService: VolumeService!
    private var brightnessService: BrightnessService!
    private var batteryService: BatteryService!
    private var clipboardService: ClipboardService!
    private var timerService: TimerService!
    private var settingsService: SettingsService!
    private var widgetRegistry: WidgetRegistry!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        screenDetector = ScreenDetector()
        viewModel = NotchViewModel()
        settingsService = SettingsService()
        windowController = NotchWindowController(
            screenDetector: screenDetector,
            viewModel: viewModel,
            settingsService: settingsService
        )
        menuBarController = MenuBarController(viewModel: viewModel)

        nowPlayingService = NowPlayingService()
        systemActionsService = SystemActionsService()
        volumeService = VolumeService()
        brightnessService = BrightnessService()
        batteryService = BatteryService()
        clipboardService = ClipboardService()
        timerService = TimerService()
        widgetRegistry = WidgetRegistry()

        let allPages = WidgetPage.allCases
        widgetRegistry.enabledPages = allPages.filter {
            settingsService.enabledWidgets.contains($0.settingsKey)
        }

        if let preferred = WidgetPage.from(settingsKey: settingsService.defaultWidgetKey),
           widgetRegistry.enabledPages.contains(preferred) {
            widgetRegistry.currentPage = preferred
        } else if let firstEnabled = widgetRegistry.enabledPages.first {
            widgetRegistry.currentPage = firstEnabled
        }

        menuBarController.settingsService = settingsService
        menuBarController.widgetRegistry = widgetRegistry
        menuBarController.setup()

        windowController.setupPanel {
            NotchContainerView(
                viewModel: self.viewModel,
                screenDetector: self.screenDetector,
                nowPlayingService: self.nowPlayingService,
                systemActionsService: self.systemActionsService,
                volumeService: self.volumeService,
                brightnessService: self.brightnessService,
                batteryService: self.batteryService,
                clipboardService: self.clipboardService,
                timerService: self.timerService,
                settingsService: self.settingsService,
                widgetRegistry: self.widgetRegistry,
                onOpenSettings: { [weak self] in
                    self?.menuBarController.showSettings()
                }
            )
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.viewModel.dismiss()
                return nil
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowController?.tearDown()
    }
}
