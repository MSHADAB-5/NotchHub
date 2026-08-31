import Foundation
import CoreAudio
import AudioToolbox
import Combine

/// Monitors and controls the system output volume using CoreAudio.
final class VolumeService: ObservableObject {

    @Published private(set) var volume: Float = 0 // 0.0–1.0
    @Published private(set) var isMuted: Bool = false

    private var defaultDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var listenerBlocks: [AudioObjectPropertyListenerBlock] = []

    init() {
        defaultDeviceID = getDefaultOutputDevice()
        if defaultDeviceID != kAudioObjectUnknown {
            volume = getVolume()
            isMuted = getMuteState()
            listenForChanges()
        }
    }

    deinit {
        removeListeners()
    }

    // MARK: - Get/Set

    func setVolume(_ newVolume: Float) {
        guard defaultDeviceID != kAudioObjectUnknown else { return }
        var vol = max(0, min(1, newVolume))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let size = UInt32(MemoryLayout<Float>.size)
        AudioObjectSetPropertyData(defaultDeviceID, &address, 0, nil, size, &vol)
        // Dragging volume above zero should immediately restore audible output.
        if vol > 0.001, isMuted {
            setMute(false)
        }
        volume = vol
    }

    func toggleMute() {
        guard defaultDeviceID != kAudioObjectUnknown else { return }
        setMute(!isMuted)
    }

    // MARK: - Read State

    private func getVolume() -> Float {
        var volume: Float = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<Float>.size)
        AudioObjectGetPropertyData(defaultDeviceID, &address, 0, nil, &size, &volume)
        return volume
    }

    private func getMuteState() -> Bool {
        var muted: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(defaultDeviceID, &address, 0, nil, &size, &muted)
        return muted != 0
    }

    private func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private func setMute(_ muted: Bool) {
        var muteValue: UInt32 = muted ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(defaultDeviceID, &address, 0, nil, size, &muteValue)
        isMuted = muted
    }

    // MARK: - Listeners

    private func listenForChanges() {
        // Listen for volume changes
        addListener(
            objectID: defaultDeviceID,
            selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            scope: kAudioDevicePropertyScopeOutput
        ) { [weak self] in
            self?.volume = self?.getVolume() ?? 0
        }

        // Listen for mute changes
        addListener(
            objectID: defaultDeviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput
        ) { [weak self] in
            self?.isMuted = self?.getMuteState() ?? false
        }

        // Listen for default output device changes
        addListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            scope: kAudioObjectPropertyScopeGlobal
        ) { [weak self] in
            self?.defaultDeviceID = self?.getDefaultOutputDevice() ?? kAudioObjectUnknown
            self?.volume = self?.getVolume() ?? 0
            self?.isMuted = self?.getMuteState() ?? false
        }
    }

    private func addListener(objectID: AudioObjectID, selector: AudioObjectPropertySelector,
                             scope: AudioObjectPropertyScope, handler: @escaping () -> Void) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            DispatchQueue.main.async { handler() }
        }
        AudioObjectAddPropertyListenerBlock(objectID, &address, DispatchQueue.main, block)
        listenerBlocks.append(block)
    }

    private func removeListeners() {
        // Listeners are cleaned up when the process exits
        listenerBlocks.removeAll()
    }
}
