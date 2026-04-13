import AppKit
import Combine
import Core
import Foundation

@MainActor
public final class CaptureService: ObservableObject {
    @Published public private(set) var state = CaptureDashboardState()

    // Future seam: M2 can swap this RAM-only debug buffer for an aggregate-only
    // pipeline without changing the tap implementation or the app-facing state model.
    private let debugBuffer = InMemoryDebugBuffer()

    // Future seam: keep all native event tap behavior inside Capture so the app layer
    // remains focused on presentation and workflow.
    private let eventTap = KeyboardEventTap()
    private var activationObserver: NSObjectProtocol?

    public init() {
        configureTapCallbacks()
        installActivationObserver()
        refreshPermissionState()
        startTapIfPossible()
    }

    public func requestPermissionFlow() {
        _ = InputMonitoringPermissionManager.requestAccess()
        refreshPermissionState()

        if state.permissionState != .granted {
            _ = InputMonitoringPermissionManager.openSettings()
        }

        startTapIfPossible()
    }

    public func openInputMonitoringSettings() {
        _ = InputMonitoringPermissionManager.openSettings()
    }

    public func refreshPermissionState() {
        state.permissionState = InputMonitoringPermissionManager.currentState()
        state.guidanceText = InputMonitoringPermissionManager.guidanceText(for: state.permissionState)

        if state.permissionState != .granted {
            state.isPaused = false
            eventTap.uninstall()
        }

        refreshTapHealth(note: currentTapNote())
    }

    public func startTapIfPossible() {
        guard state.permissionState == .granted else {
            refreshTapHealth(note: currentTapNote())
            return
        }

        do {
            try eventTap.install()
            if state.isPaused {
                eventTap.setEnabled(false)
            }
            refreshTapHealth(note: currentTapNote())
        } catch {
            refreshTapHealth(note: note(for: error))
        }
    }

    public func togglePause() {
        state.isPaused ? resumeCapture() : pauseCapture()
    }

    public func pauseCapture() {
        guard state.permissionState == .granted else { return }
        state.isPaused = true
        eventTap.setEnabled(false)
        refreshTapHealth(note: currentTapNote())
    }

    public func resumeCapture() {
        guard state.permissionState == .granted else { return }
        state.isPaused = false
        startTapIfPossible()
    }

    public func resetDebugData() {
        debugBuffer.reset()
        state.counters = CaptureCounters()
        state.debugPreviewText = ""
        state.recentEvents = []
    }

    private func configureTapCallbacks() {
        eventTap.onObservedKeyEvent = { [weak self] observedEvent in
            guard let self else { return }
            self.handleObservedKeyEvent(observedEvent)
        }

        eventTap.onTapNote = { [weak self] note in
            guard let self else { return }
            self.refreshTapHealth(note: note)
        }
    }

    private func installActivationObserver() {
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshPermissionState()
                self.startTapIfPossible()
            }
        }
    }

    private func handleObservedKeyEvent(_ observedEvent: ObservedKeyEvent) {
        guard state.permissionState == .granted else { return }
        guard !state.isPaused else { return }

        state.counters.totalKeyDownEvents += 1
        if observedEvent.isBackspace {
            state.counters.totalBackspaces += 1
        }

        debugBuffer.append(
            renderedValue: observedEvent.renderedValue,
            kind: observedEvent.kind,
            keyCode: observedEvent.keyCode,
            timestamp: observedEvent.timestamp
        )

        state.debugPreviewText = debugBuffer.previewText
        state.recentEvents = debugBuffer.events
        state.tapHealth.lastEventAt = observedEvent.timestamp
        refreshTapHealth(note: currentTapNote())
    }

    private func refreshTapHealth(note: String) {
        state.tapHealth = TapHealth(
            isInstalled: eventTap.isInstalled,
            isEnabled: eventTap.isEnabled,
            lastEventAt: state.tapHealth.lastEventAt,
            statusNote: note
        )
    }

    private func currentTapNote() -> String {
        if state.permissionState != .granted {
            return "Tap not installed because Input Monitoring is not granted."
        }

        if !eventTap.isInstalled {
            return "Permission granted, but the tap is not installed yet."
        }

        if !eventTap.isEnabled {
            return state.isPaused
                ? "Tap installed but paused."
                : "Tap installed but currently disabled."
        }

        return "Tap installed and listening."
    }

    private func note(for error: Error) -> String {
        switch error {
        case KeyboardEventTapError.permissionNotGranted:
            return "Tap not installed because Input Monitoring is not granted."
        case KeyboardEventTapError.tapCreationFailed:
            return "macOS did not allow the listen-only tap to be created. Re-check Input Monitoring and relaunch if needed."
        case KeyboardEventTapError.runLoopSourceCreationFailed:
            return "Tap was created, but its run loop source failed to initialize."
        default:
            return "Unexpected tap error: \(String(describing: error))"
        }
    }
}
