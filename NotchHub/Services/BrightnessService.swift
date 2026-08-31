import Foundation
import CoreGraphics
import Combine

/// Monitors and controls the built-in display brightness using DisplayServices private framework.
final class BrightnessService: ObservableObject {

    @Published private(set) var brightness: Float = 1.0 // 0.0–1.0
    @Published private(set) var isAvailable: Bool = false

    private var pollingTimer: Timer?
    private var displayID: UInt32 = 0

    // Raw function pointers
    private var getBrightnessPtr: UnsafeMutableRawPointer?
    private var setBrightnessPtr: UnsafeMutableRawPointer?

    init() {
        loadDisplayServices()
        if isAvailable {
            brightness = getBrightness()
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self else { return }
                let newVal = self.getBrightness()
                if newVal >= 0, abs(newVal - self.brightness) > 0.005 {
                    self.brightness = newVal
                }
            }
            if let timer = pollingTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    deinit {
        pollingTimer?.invalidate()
    }

    func setBrightness(_ value: Float) {
        let clamped = max(0, min(1, value))
        guard let ptr = setBrightnessPtr else { return }
        typealias SetFn = @convention(c) (UInt32, Float) -> Int32
        let fn = unsafeBitCast(ptr, to: SetFn.self)
        _ = fn(displayID, clamped)
        brightness = clamped
    }

    // MARK: - DisplayServices Framework

    private func loadDisplayServices() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) else {
            return
        }

        displayID = CGMainDisplayID()
        getBrightnessPtr = dlsym(handle, "DisplayServicesGetBrightness")
        setBrightnessPtr = dlsym(handle, "DisplayServicesSetBrightness")

        // Test if it works
        if getBrightnessPtr != nil {
            let val = getBrightness()
            isAvailable = (val >= 0)
        }
    }

    private func getBrightness() -> Float {
        guard let ptr = getBrightnessPtr else { return -1 }
        typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
        let fn = unsafeBitCast(ptr, to: GetFn.self)
        var val: Float = 0
        let err = fn(displayID, &val)
        return err == 0 ? val : -1
    }
}
