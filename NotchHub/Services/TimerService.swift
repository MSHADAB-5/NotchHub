import Foundation
import Combine
import UserNotifications
import AppKit

/// Full Pomodoro timer with work / short-rest / long-rest cycles.
/// Pauses between intervals and waits for user confirmation before proceeding.
final class TimerService: ObservableObject {

    enum Phase: String {
        case idle
        case work       = "Focus"
        case shortRest  = "Short Break"
        case longRest   = "Long Break"
    }

    enum TimerState {
        case idle, running, paused, waitingConfirm
    }

    // MARK: - Published State

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var timerState: TimerState = .idle
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var totalSeconds: Int = 0
    @Published private(set) var completedIntervals: Int = 0
    /// What the next phase will be — shown in the confirm prompt
    @Published private(set) var pendingNextPhase: Phase = .idle

    // MARK: - Settings

    @Published var workMinutes: Int = 25
    @Published var shortRestMinutes: Int = 5
    @Published var longRestMinutes: Int = 15
    @Published var intervalsBeforeLong: Int = 4

    // MARK: - Computed

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    var displayTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var isRunning: Bool { timerState == .running }
    var isWaiting: Bool { timerState == .waitingConfirm }

    var phaseColor: (r: Double, g: Double, b: Double) {
        switch phase {
        case .idle:      return (1, 1, 1)
        case .work:      return (0.35, 0.78, 0.48)  // green
        case .shortRest: return (0.40, 0.72, 1.0)    // blue
        case .longRest:  return (0.85, 0.55, 1.0)    // purple
        }
    }

    private var timer: Timer?
    private var soundRepeatTimer: Timer?

    // MARK: - Controls

    func start() {
        phase = .work
        totalSeconds = workMinutes * 60
        remainingSeconds = totalSeconds
        completedIntervals = 0
        timerState = .running
        startTicking()
    }

    func togglePause() {
        if timerState == .running {
            timerState = .paused
            timer?.invalidate()
            timer = nil
        } else if timerState == .paused {
            timerState = .running
            startTicking()
        }
    }

    func stop() {
        timerState = .idle
        phase = .idle
        timer?.invalidate()
        timer = nil
        soundRepeatTimer?.invalidate()
        soundRepeatTimer = nil
        remainingSeconds = 0
        totalSeconds = 0
        completedIntervals = 0
    }

    func skip() {
        timer?.invalidate()
        timer = nil
        if phase == .work {
            completedIntervals += 1
        }
        showConfirmPrompt()
    }

    /// User confirms to start the next interval.
    func confirmNext() {
        let next = pendingNextPhase
        let shouldResetCycle = phase == .longRest && next == .work
        phase = next
        switch next {
        case .work:      totalSeconds = workMinutes * 60
        case .shortRest: totalSeconds = shortRestMinutes * 60
        case .longRest:  totalSeconds = longRestMinutes * 60
        case .idle:      stop(); return
        }
        if shouldResetCycle {
            completedIntervals = 0
        }
        remainingSeconds = totalSeconds
        timerState = .running
        startTicking()
    }

    // MARK: - Tick

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.intervalCompleted()
            }
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func intervalCompleted() {
        timer?.invalidate()
        timer = nil

        playCompletionSound()
        sendNotification(phase: phase)

        if phase == .work {
            completedIntervals += 1
        }

        // Pause and wait for user to confirm next interval
        showConfirmPrompt()
    }

    private func showConfirmPrompt() {
        // Determine what the next phase should be
        switch phase {
        case .work:
            if completedIntervals >= intervalsBeforeLong {
                pendingNextPhase = .longRest
            } else {
                pendingNextPhase = .shortRest
            }
        case .shortRest, .longRest:
            pendingNextPhase = .work
        case .idle:
            return
        }

        remainingSeconds = 0
        timerState = .waitingConfirm
    }

    // MARK: - Sound

    private func playCompletionSound() {
        var playCount = 0
        let playOnce = { _ = NSSound(named: "Glass")?.play() }

        playOnce()
        playCount += 1

        soundRepeatTimer?.invalidate()
        soundRepeatTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            playCount += 1
            playOnce()
            if playCount >= 3 {
                timer.invalidate()
                self?.soundRepeatTimer = nil
            }
        }
        if let t = soundRepeatTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    // MARK: - Notification

    private func sendNotification(phase: Phase) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "NotchHub Timer"
            switch phase {
            case .work:
                content.body = "Focus session done! Time for a break."
            case .shortRest:
                content.body = "Break over! Ready to focus?"
            case .longRest:
                content.body = "Long break done! Ready for another set?"
            case .idle:
                return
            }
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }

    deinit {
        timer?.invalidate()
        soundRepeatTimer?.invalidate()
    }
}
