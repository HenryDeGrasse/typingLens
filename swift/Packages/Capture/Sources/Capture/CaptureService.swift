import AppKit
import Combine
import Core
import Foundation

@MainActor
public final class CaptureService: ObservableObject {
    @Published public private(set) var state: CaptureDashboardState

    // Future seam: this transient raw buffer stays debug-only and in-memory. Product
    // features should read aggregateMetrics instead of depending on raw event text.
    private let debugBuffer = InMemoryDebugBuffer(maxPreviewCharacters: 120, maxEvents: 12)

    // Future seam: keep all native tap behavior isolated from aggregation and UI.
    private let eventTap = KeyboardEventTap()
    private let aggregateStore = AggregateMetricsStore()
    private let aggregator: TypingMetricsAggregator

    private var activationObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var lastRuntimeNote: String?
    private var unsavedAggregateMutations = 0

    public init() {
        let persistedMetrics = aggregateStore.load()
        self.aggregator = TypingMetricsAggregator(initialMetrics: persistedMetrics)
        self.state = CaptureDashboardState(
            aggregateMetrics: persistedMetrics,
            exclusionStatus: ExclusionStatus(
                excludedAppDisplayNames: ApplicationExclusionPolicy.excludedAppDisplayNames,
                excludedBundleIdentifiers: ApplicationExclusionPolicy.excludedBundleIdentifiers,
                excludedEventCount: persistedMetrics.excludedEventCount
            )
        )

        configureTapCallbacks()
        installLifecycleObservers()
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
            lastRuntimeNote = nil
        }

        refreshDerivedStateAndHealth()
    }

    public func startTapIfPossible() {
        guard state.permissionState == .granted else {
            refreshDerivedStateAndHealth()
            return
        }

        do {
            try eventTap.install()
            if state.isPaused {
                eventTap.setEnabled(false)
            }
            refreshDerivedStateAndHealth()
        } catch {
            lastRuntimeNote = note(for: error)
            refreshDerivedStateAndHealth()
        }
    }

    public func togglePause() {
        state.isPaused ? resumeCapture() : pauseCapture()
    }

    public func pauseCapture() {
        guard state.permissionState == .granted else { return }
        state.isPaused = true
        eventTap.setEnabled(false)
        persistAggregates(force: true)
        refreshDerivedStateAndHealth()
    }

    public func resumeCapture() {
        guard state.permissionState == .granted else { return }
        state.isPaused = false
        lastRuntimeNote = nil
        startTapIfPossible()
    }

    public func resetCaptureData() {
        debugBuffer.reset()
        aggregator.reset()
        state.aggregateMetrics = aggregator.metrics
        state.exclusionStatus.excludedEventCount = 0
        state.exclusionStatus.lastExcludedAppName = nil
        state.debugPreviewText = ""
        state.recentEvents = []
        state.tapHealth.lastEventAt = nil
        lastRuntimeNote = nil
        unsavedAggregateMutations = 0

        do {
            try aggregateStore.clear()
        } catch {
            lastRuntimeNote = "Could not clear aggregate store: \(error.localizedDescription)"
        }

        refreshDerivedStateAndHealth()
    }

    private func configureTapCallbacks() {
        eventTap.onObservedKeyEvent = { [weak self] observedEvent in
            guard let self else { return }
            self.handleObservedKeyEvent(observedEvent)
        }

        eventTap.onTapNote = { [weak self] note in
            guard let self else { return }
            self.lastRuntimeNote = note
            self.refreshDerivedStateAndHealth()
        }
    }

    private func installLifecycleObservers() {
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

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistAggregates(force: true)
            }
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistAggregates(force: true)
            }
        }
    }

    private func handleObservedKeyEvent(_ observedEvent: ObservedKeyEvent) {
        guard state.permissionState == .granted else { return }
        guard !state.isPaused else { return }

        state.tapHealth.lastEventAt = observedEvent.timestamp

        let activeApplication = ApplicationExclusionPolicy.currentFrontmostApplication()
        if ApplicationExclusionPolicy.shouldExclude(activeApplication) {
            aggregator.recordExcludedEvent(timestamp: observedEvent.timestamp)
            state.aggregateMetrics = aggregator.metrics
            state.exclusionStatus.excludedEventCount = aggregator.metrics.excludedEventCount
            state.exclusionStatus.lastExcludedAppName = activeApplication?.displayName
            lastRuntimeNote = "Tap is healthy, but events from \(activeApplication?.displayName ?? "this app") are currently excluded."
            markAggregatesDirty()
            refreshDerivedStateAndHealth()
            return
        }

        let classifiedEvent = KeyEventNormalizer.classify(observedEvent)
        aggregator.recordIncludedEvent(
            token: classifiedEvent.aggregateToken,
            isBackspace: classifiedEvent.isBackspace,
            timestamp: classifiedEvent.timestamp
        )

        debugBuffer.append(
            renderedValue: classifiedEvent.debugRenderedValue,
            kind: classifiedEvent.kind,
            keyCode: classifiedEvent.keyCode,
            timestamp: classifiedEvent.timestamp
        )

        state.aggregateMetrics = aggregator.metrics
        state.exclusionStatus.excludedEventCount = aggregator.metrics.excludedEventCount
        state.debugPreviewText = debugBuffer.previewText
        state.recentEvents = debugBuffer.events
        lastRuntimeNote = nil
        markAggregatesDirty()
        refreshDerivedStateAndHealth()
    }

    private func markAggregatesDirty() {
        unsavedAggregateMutations += 1
        if unsavedAggregateMutations >= 20 {
            persistAggregates(force: true)
        }
    }

    private func persistAggregates(force: Bool) {
        guard force || unsavedAggregateMutations > 0 else {
            return
        }

        do {
            try aggregateStore.save(aggregator.metrics)
            unsavedAggregateMutations = 0
        } catch {
            lastRuntimeNote = "Could not persist aggregate metrics: \(error.localizedDescription)"
        }
    }

    private func refreshDerivedStateAndHealth() {
        state.captureActivityState = currentCaptureActivityState()
        state.tapHealth = TapHealth(
            isInstalled: eventTap.isInstalled,
            isEnabled: eventTap.isEnabled,
            lastEventAt: state.tapHealth.lastEventAt,
            statusNote: currentTapNote()
        )
    }

    private func currentCaptureActivityState() -> CaptureActivityState {
        switch state.permissionState {
        case .denied:
            return .permissionDenied
        case .unknown:
            return .needsPermission
        case .granted:
            if state.isPaused {
                return .paused
            }

            if eventTap.isInstalled && eventTap.isEnabled {
                return .recording
            }

            return .tapUnavailable
        }
    }

    private func currentTapNote() -> String {
        if state.permissionState != .granted {
            return "Tap not installed because Input Monitoring is not granted."
        }

        if !eventTap.isInstalled {
            return lastRuntimeNote ?? "Permission granted, but the tap is not installed yet."
        }

        if !eventTap.isEnabled {
            if state.isPaused {
                return "Tap installed but paused."
            }
            return lastRuntimeNote ?? "Tap installed but currently disabled."
        }

        if let lastRuntimeNote {
            return lastRuntimeNote
        }

        return "Tap installed and listening for aggregate diagnostics."
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
