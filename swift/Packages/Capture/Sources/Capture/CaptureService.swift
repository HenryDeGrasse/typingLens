import AppKit
import Combine
#if canImport(Carbon)
import Carbon
#endif
import Core
import Foundation

@MainActor
public final class CaptureService: ObservableObject {
    @Published public private(set) var state: CaptureDashboardState

    // Future seam: keep any raw preview transient and debug-only. Product features
    // should read profileSnapshot instead of depending on text-like diagnostics.
    private let debugBuffer = InMemoryDebugBuffer(maxPreviewCharacters: 120, maxEvents: 12)

    // Future seam: keep native capture, profile aggregation, and UI wiring separated.
    private let eventTap = KeyboardEventTap()
    private let profileEngine = TypingProfileEngine()
    private let practiceRuntimeEngine = PracticeRuntimeEngine()
    private let advancedDiagnosticsAggregator = TypingMetricsAggregator()
    private let manualExclusionStore = ManualExclusionStore()
    private let legacyAggregateStore = AggregateMetricsStore()

    private var manualExcludedApplications: [ExcludedApplication]
    private var activationObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var secureInputPollTimer: Timer?
    private var practiceTimer: Timer?
    private var lastRuntimeNote: String?
    private var exclusionNote: String?
    private var lastObservedApplication: ObservedApplication?
    private var lastExcludedAppName: String?
    private var secureInputState: SecureInputState = .unavailable
    private var unsavedProfileMutations = 0

    public init() {
        try? legacyAggregateStore.clear()

        let manualExcludedApplications = manualExclusionStore.load()
            .sorted(using: KeyPathComparator(\.displayName, comparator: .localizedStandard))
        self.manualExcludedApplications = manualExcludedApplications

        self.state = CaptureDashboardState(
            profileSnapshot: profileEngine.currentSnapshot(),
            learningModel: LearningModelEngine.build(from: profileEngine.currentSnapshot()),
            practiceRuntime: practiceRuntimeEngine.snapshot(),
            advancedDiagnostics: advancedDiagnosticsAggregator.metrics,
            trustState: TrustState(
                secureInputState: .unavailable,
                profileStorePath: profileEngine.persistenceDescription,
                manualExclusionsStorePath: manualExclusionStore.persistenceDescription,
                storesRawText: false,
                storesLiteralNGrams: false,
                note: "Typing Lens stores content-free local profile summaries. Raw preview stays debug-only in memory and any legacy M2 literal n-gram store is cleared on launch."
            ),
            exclusionStatus: ExclusionStatus(
                builtInExcludedApplications: ApplicationExclusionPolicy.builtInExcludedApplications,
                manualExcludedApplications: manualExcludedApplications
            )
        )

        configureTapCallbacks()
        installLifecycleObservers()
        installSecureInputPolling()
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
        refreshSecureInputState()

        if state.permissionState != .granted {
            state.isPaused = false
            eventTap.uninstall()
            profileEngine.interruptSession()
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
        profileEngine.interruptSession()
        persistProfile(force: true)
        refreshDerivedStateAndHealth()
    }

    public func resumeCapture() {
        guard state.permissionState == .granted else { return }
        state.isPaused = false
        lastRuntimeNote = nil
        startTapIfPossible()
    }

    public func resetCaptureData() {
        clearPracticeRuntime()
        debugBuffer.reset()
        state.debugPreviewText = ""
        state.recentEvents = []
        state.tapHealth.lastEventAt = nil
        lastRuntimeNote = nil
        lastObservedApplication = nil
        lastExcludedAppName = nil
        exclusionNote = nil
        unsavedProfileMutations = 0

        do {
            try profileEngine.reset()
            try? legacyAggregateStore.clear()
        } catch {
            lastRuntimeNote = "Could not clear profile store: \(error.localizedDescription)"
        }

        advancedDiagnosticsAggregator.reset()
        refreshDerivedStateAndHealth()
    }

    public func startRecommendedPracticeSession() {
        guard let sessionPlan = state.learningModel.recommendedSession else {
            return
        }

        lastRuntimeNote = nil
        practiceRuntimeEngine.start(
            plan: sessionPlan,
            weakness: state.learningModel.primaryWeakness
        )
        startPracticeTimer()
        refreshDerivedStateAndHealth()
    }

    public func pausePracticeSession() {
        pausePracticeSession(reason: "Practice paused. Resume when you are ready.")
    }

    public func resumePracticeSession() {
        lastRuntimeNote = nil
        practiceRuntimeEngine.resume()
        startPracticeTimer()
        refreshDerivedStateAndHealth()
    }

    public func cancelPracticeSession() {
        practiceRuntimeEngine.cancel()
        stopPracticeTimer()
        lastRuntimeNote = nil
        refreshDerivedStateAndHealth()
    }

    public func advancePracticeBlock() {
        practiceRuntimeEngine.advanceBlock()
        syncPracticeTimerToRuntimeState()
        refreshDerivedStateAndHealth()
    }

    public func skipPracticePrompt() {
        practiceRuntimeEngine.skipPrompt()
        refreshDerivedStateAndHealth()
    }

    public func handlePracticeCharacter(_ character: String) {
        practiceRuntimeEngine.handleCharacter(character)
        refreshDerivedStateAndHealth()
    }

    public func handlePracticeBackspace() {
        practiceRuntimeEngine.handleBackspace()
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
                self?.persistProfile(force: true)
                self?.pausePracticeSession(reason: "Practice paused because Typing Lens moved to the background.")
            }
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistProfile(force: true)
                self?.stopPracticeTimer()
            }
        }
    }

    private func installSecureInputPolling() {
        secureInputPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSecureInputState()
                self?.refreshDerivedStateAndHealth()
            }
        }
        secureInputPollTimer?.tolerance = 0.25
    }

    private func refreshSecureInputState() {
        #if canImport(Carbon)
        secureInputState = IsSecureEventInputEnabled() ? .enabled : .disabled
        #else
        secureInputState = .unavailable
        #endif
    }

    private func handleObservedKeyEvent(_ observedEvent: ObservedKeyEvent) {
        guard state.permissionState == .granted else { return }
        guard !state.isPaused else { return }

        refreshSecureInputState()
        state.tapHealth.lastEventAt = observedEvent.timestamp

        if secureInputState == .enabled {
            profileEngine.interruptSession()
            refreshDerivedStateAndHealth()
            return
        }

        let activeApplication = ApplicationExclusionPolicy.currentFrontmostApplication()
        lastObservedApplication = activeApplication?.asObservedApplication

        if activeApplication?.bundleIdentifier == Bundle.main.bundleIdentifier,
           practiceRuntimeEngine.isActive {
            lastRuntimeNote = "In-app practice session active. Typing Lens keystrokes are routed to the drill runtime, not the passive profile."
            refreshDerivedStateAndHealth()
            return
        }

        let classifiedEvent = KeyEventNormalizer.classify(observedEvent)

        if observedEvent.phase == .keyDown,
           ApplicationExclusionPolicy.shouldExclude(
                activeApplication,
                manualBundleIdentifiers: manualExcludedBundleIdentifiers
           ) {
            profileEngine.recordExcludedKeyDown(at: observedEvent.timestamp)
            advancedDiagnosticsAggregator.recordExcludedEvent(timestamp: observedEvent.timestamp)
            lastExcludedAppName = activeApplication?.displayName
            lastRuntimeNote = "Tap is healthy, but events from \(activeApplication?.displayName ?? "this app") are currently excluded."
            markProfileDirty()
            refreshDerivedStateAndHealth()
            return
        }

        profileEngine.record(classifiedEvent)

        if classifiedEvent.eventPhase == .keyDown, classifiedEvent.shouldUseInProfile {
            advancedDiagnosticsAggregator.recordIncludedEvent(
                token: classifiedEvent.advancedAggregateToken,
                isBackspace: classifiedEvent.isBackspace,
                timestamp: classifiedEvent.timestamp
            )

            debugBuffer.append(
                renderedValue: classifiedEvent.debugRenderedValue,
                kind: classifiedEvent.kind,
                keyCode: classifiedEvent.keyCode,
                timestamp: classifiedEvent.timestamp
            )

            state.debugPreviewText = debugBuffer.previewText
            state.recentEvents = debugBuffer.events
            lastRuntimeNote = nil
        }

        markProfileDirty()
        refreshDerivedStateAndHealth()
    }

    private func markProfileDirty() {
        unsavedProfileMutations += 1
        if unsavedProfileMutations >= 60 {
            persistProfile(force: true)
        }
    }

    private func persistProfile(force: Bool) {
        guard force || unsavedProfileMutations > 0 else {
            return
        }

        do {
            try profileEngine.persist()
            unsavedProfileMutations = 0
        } catch {
            lastRuntimeNote = "Could not persist profile summaries: \(error.localizedDescription)"
        }
    }

    private func refreshDerivedStateAndHealth() {
        state.captureActivityState = currentCaptureActivityState()
        state.profileSnapshot = profileEngine.currentSnapshot()
        state.learningModel = LearningModelEngine.build(from: state.profileSnapshot)
        state.practiceRuntime = practiceRuntimeEngine.snapshot()
        state.advancedDiagnostics = advancedDiagnosticsAggregator.metrics
        state.tapHealth = TapHealth(
            isInstalled: eventTap.isInstalled,
            isEnabled: eventTap.isEnabled,
            lastEventAt: state.tapHealth.lastEventAt,
            statusNote: currentTapNote()
        )
        state.trustState = TrustState(
            secureInputState: secureInputState,
            profileStorePath: profileEngine.persistenceDescription,
            manualExclusionsStorePath: manualExclusionStore.persistenceDescription,
            storesRawText: false,
            storesLiteralNGrams: false,
            note: "Typing Lens stores content-free daily profile summaries locally. Literal n-grams and raw preview text are not persisted, and any legacy M2 literal n-gram store is cleared on launch."
        )
        refreshExclusionState()
    }

    private func refreshExclusionState() {
        state.exclusionStatus = ExclusionStatus(
            builtInExcludedApplications: ApplicationExclusionPolicy.builtInExcludedApplications,
            manualExcludedApplications: manualExcludedApplications,
            excludedEventCount: state.profileSnapshot.today.excludedEventCount,
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

            if secureInputState == .enabled {
                return .secureInputBlocked
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

        if secureInputState == .enabled {
            return "Secure Event Input is currently enabled by another app, so Typing Lens is temporarily blocked from observing keystrokes."
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

        return "Tap installed and listening for local profile summaries."
    }

    private func pausePracticeSession(reason: String) {
        practiceRuntimeEngine.pause(reason: reason)
        stopPracticeTimer()
        refreshDerivedStateAndHealth()
    }

    private func clearPracticeRuntime() {
        practiceRuntimeEngine.reset()
        stopPracticeTimer()
        lastRuntimeNote = nil
    }

    private func startPracticeTimer() {
        stopPracticeTimer()

        guard practiceRuntimeEngine.snapshot().status == .running else {
            return
        }

        practiceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.practiceRuntimeEngine.tick()
                self.syncPracticeTimerToRuntimeState()
                self.refreshDerivedStateAndHealth()
            }
        }
        practiceTimer?.tolerance = 0.15
        if let practiceTimer {
            RunLoop.main.add(practiceTimer, forMode: .common)
        }
    }

    private func stopPracticeTimer() {
        practiceTimer?.invalidate()
        practiceTimer = nil
    }

    private func syncPracticeTimerToRuntimeState() {
        switch practiceRuntimeEngine.snapshot().status {
        case .running:
            if practiceTimer == nil {
                startPracticeTimer()
            }
        case .paused:
            stopPracticeTimer()
        case .idle, .completed, .canceled:
            stopPracticeTimer()
            lastRuntimeNote = nil
        }
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
