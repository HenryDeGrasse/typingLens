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

    // Future seam: keep native tap behavior isolated from aggregation, exclusions, and UI.
    private let eventTap = KeyboardEventTap()
    private let aggregateStore = AggregateMetricsStore()
    private let manualExclusionStore = ManualExclusionStore()
    private let aggregator: TypingMetricsAggregator

    private var manualExcludedApplications: [ExcludedApplication]
    private var activationObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var lastRuntimeNote: String?
    private var exclusionNote: String?
    private var lastObservedApplication: ObservedApplication?
    private var lastExcludedAppName: String?
    private var unsavedAggregateMutations = 0

    public init() {
        let persistedMetrics = aggregateStore.load()
        let manualExcludedApplications = manualExclusionStore.load()
            .sorted(using: KeyPathComparator(\.displayName, comparator: .localizedStandard))

        self.manualExcludedApplications = manualExcludedApplications
        self.aggregator = TypingMetricsAggregator(initialMetrics: persistedMetrics)
        self.state = CaptureDashboardState(
            aggregateMetrics: persistedMetrics,
            exclusionStatus: ExclusionStatus(
                builtInExcludedApplications: ApplicationExclusionPolicy.builtInExcludedApplications,
                manualExcludedApplications: manualExcludedApplications,
                excludedEventCount: persistedMetrics.excludedEventCount
            )
        )

        configureTapCallbacks()
        installLifecycleObservers()
        refreshExclusionState()
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

    public func addManualExclusionFromLastObservedApp() {
        guard let lastObservedApplication else {
            exclusionNote = "No recently observed app is available yet. Type in another app first, then come back here."
            refreshExclusionState()
            return
        }

        guard let bundleIdentifier = lastObservedApplication.bundleIdentifier else {
            exclusionNote = "The last observed app does not expose a bundle identifier, so it cannot be added yet."
            refreshExclusionState()
            return
        }

        addManualExclusion(
            bundleIdentifier: bundleIdentifier,
            displayName: lastObservedApplication.displayName
        )
    }

    public func addManualExclusion(bundleIdentifier rawValue: String) {
        addManualExclusion(bundleIdentifier: rawValue, displayName: nil)
    }

    public func removeManualExclusion(bundleIdentifier: String) {
        guard let removedApplication = manualExcludedApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            exclusionNote = "That manual exclusion was not found."
            refreshExclusionState()
            return
        }

        let previousManualExcludedApplications = manualExcludedApplications
        manualExcludedApplications.removeAll { $0.bundleIdentifier == bundleIdentifier }

        do {
            try persistManualExclusions()
            exclusionNote = "Removed \(removedApplication.displayName) from manual exclusions."
        } catch {
            manualExcludedApplications = previousManualExcludedApplications
            exclusionNote = "Could not save manual exclusions: \(error.localizedDescription)"
        }

        refreshExclusionState()
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
        state.debugPreviewText = ""
        state.recentEvents = []
        state.tapHealth.lastEventAt = nil
        lastRuntimeNote = nil
        lastObservedApplication = nil
        lastExcludedAppName = nil
        exclusionNote = nil
        unsavedAggregateMutations = 0

        do {
            try aggregateStore.clear()
        } catch {
            lastRuntimeNote = "Could not clear aggregate store: \(error.localizedDescription)"
        }

        refreshDerivedStateAndHealth()
    }

    private var manualExcludedBundleIdentifiers: Set<String> {
        Set(manualExcludedApplications.map(\.bundleIdentifier))
    }

    private func addManualExclusion(
        bundleIdentifier rawValue: String,
        displayName: String?
    ) {
        let bundleIdentifier = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !bundleIdentifier.isEmpty else {
            exclusionNote = "Enter a bundle identifier like com.example.app before adding a manual exclusion."
            refreshExclusionState()
            return
        }

        if bundleIdentifier == Bundle.main.bundleIdentifier {
            exclusionNote = "Typing Lens cannot exclude itself from this control."
            refreshExclusionState()
            return
        }

        if ApplicationExclusionPolicy.isBuiltInExcluded(bundleIdentifier: bundleIdentifier) {
            exclusionNote = "That app is already part of the built-in exclusion list."
            refreshExclusionState()
            return
        }

        if manualExcludedBundleIdentifiers.contains(bundleIdentifier) {
            exclusionNote = "That bundle identifier is already in the manual exclusion list."
            refreshExclusionState()
            return
        }

        let excludedApplication = ExcludedApplication(
            displayName: resolvedDisplayName(
                for: bundleIdentifier,
                suggestedDisplayName: displayName
            ),
            bundleIdentifier: bundleIdentifier
        )

        let previousManualExcludedApplications = manualExcludedApplications
        manualExcludedApplications.append(excludedApplication)
        manualExcludedApplications.sort(using: KeyPathComparator(\.displayName, comparator: .localizedStandard))

        do {
            try persistManualExclusions()
            exclusionNote = "Added \(excludedApplication.displayName) to manual exclusions."
        } catch {
            manualExcludedApplications = previousManualExcludedApplications
            exclusionNote = "Could not save manual exclusions: \(error.localizedDescription)"
        }

        refreshExclusionState()
    }

    private func resolvedDisplayName(
        for bundleIdentifier: String,
        suggestedDisplayName: String?
    ) -> String {
        if let suggestedDisplayName,
           !suggestedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return suggestedDisplayName
        }

        if let runningApplication = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
           let localizedName = runningApplication.localizedName,
           !localizedName.isEmpty {
            return localizedName
        }

        return bundleIdentifier
    }

    private func persistManualExclusions() throws {
        try manualExclusionStore.save(manualExcludedApplications)
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
        lastObservedApplication = activeApplication?.asObservedApplication

        if ApplicationExclusionPolicy.shouldExclude(
            activeApplication,
            manualBundleIdentifiers: manualExcludedBundleIdentifiers
        ) {
            aggregator.recordExcludedEvent(timestamp: observedEvent.timestamp)
            state.aggregateMetrics = aggregator.metrics
            lastExcludedAppName = activeApplication?.displayName
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
        state.aggregateMetrics = aggregator.metrics
        state.tapHealth = TapHealth(
            isInstalled: eventTap.isInstalled,
            isEnabled: eventTap.isEnabled,
            lastEventAt: state.tapHealth.lastEventAt,
            statusNote: currentTapNote()
        )
        refreshExclusionState()
    }

    private func refreshExclusionState() {
        state.exclusionStatus = ExclusionStatus(
            builtInExcludedApplications: ApplicationExclusionPolicy.builtInExcludedApplications,
            manualExcludedApplications: manualExcludedApplications,
            excludedEventCount: aggregator.metrics.excludedEventCount,
            lastExcludedAppName: lastExcludedAppName,
            lastObservedApplication: lastObservedApplication,
            note: exclusionNote
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
