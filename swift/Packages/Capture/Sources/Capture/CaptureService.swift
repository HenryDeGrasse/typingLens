import AppKit
import Combine
#if canImport(Carbon)
import Carbon
#endif
import Core
import Foundation
import os

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
    private let passiveSliceRecorder = PassiveSliceRecorder()
    private let advancedDiagnosticsAggregator = TypingMetricsAggregator()
    private let manualExclusionStore = ManualExclusionStore()
    private let legacyAggregateStore = AggregateMetricsStore()
    private let evidenceStore = PracticeEvidenceStore()
    private let modelVersionStamp = PracticeEvaluationEngine.currentModelVersionStamp

    private var manualExcludedApplications: [ExcludedApplication]
    nonisolated(unsafe) private var activationObserver: NSObjectProtocol?
    nonisolated(unsafe) private var backgroundObserver: NSObjectProtocol?
    nonisolated(unsafe) private var terminationObserver: NSObjectProtocol?
    nonisolated(unsafe) private var secureInputPollTimer: Timer?
    nonisolated(unsafe) private var practiceTimer: Timer?
    private var lastRuntimeNote: String?
    private var exclusionNote: String?
    private var lastObservedApplication: ObservedApplication?
    private var lastExcludedAppName: String?
    private var secureInputState: SecureInputState = .unavailable
    private var unsavedProfileMutations = 0
    private var activeRecommendationDecision: RecommendationDecisionRecord?
    private var currentPracticeDeviceClass = "unknown-device"

    public init() {
        do {
            try legacyAggregateStore.clear()
        } catch {
            Self.logger.error("Could not clear legacy aggregate store: \(error.localizedDescription, privacy: .public)")
        }
        evidenceStore.ensureModelVersionStamp(modelVersionStamp)

        let manualExcludedApplications = manualExclusionStore.load()
            .sorted(using: KeyPathComparator(\.displayName, comparator: .localizedStandard))
        self.manualExcludedApplications = manualExcludedApplications

        let initialPersistenceWarning = [
            profileEngine.lastPersistenceError,
            evidenceStore.lastPersistenceError
        ].compactMap { $0 }.joined(separator: " ").nonEmptyOrNil

        self.state = CaptureDashboardState(
            profileSnapshot: profileEngine.currentSnapshot(),
            learningModel: LearningModelEngine.build(from: profileEngine.currentSnapshot()),
            practiceRuntime: practiceRuntimeEngine.snapshot(),
            practiceHistory: evidenceStore.fetchPracticeHistory(limit: 8),
            advancedDiagnostics: advancedDiagnosticsAggregator.metrics,
            trustState: TrustState(
                secureInputState: .unavailable,
                profileStorePath: profileEngine.persistenceDescription,
                manualExclusionsStorePath: manualExclusionStore.persistenceDescription,
                evidenceStorePath: evidenceStore.persistenceDescription,
                keyboardLayoutID: KeyboardContext.currentLayoutID(),
                keyboardLayoutName: KeyboardContext.currentLayoutName(),
                keyboardDeviceClass: currentPracticeDeviceClass,
                storesRawText: false,
                storesLiteralNGrams: false,
                note: "Typing Lens stores local profile summaries in JSON and aggregate-only coaching evidence in SQLite. It does not store raw typed text, raw practice responses, or raw event streams.",
                persistenceWarning: initialPersistenceWarning
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

    deinit {
        // Notification observers are retained by NotificationCenter until removed.
        // Removing here is safe because NotificationCenter APIs are thread-safe.
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        secureInputPollTimer?.invalidate()
        practiceTimer?.invalidate()
    }

    private static let logger = Logger(subsystem: "ai.gauntlet.typinglens", category: "CaptureService")

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

    public struct StoreFileDescriptor: Identifiable, Sendable {
        public let id: String
        public let label: String
        public let path: String
        public let exists: Bool
        public let sizeBytes: Int64?
        public let lastModified: Date?
    }

    public func currentStoreFileDescriptors() -> [StoreFileDescriptor] {
        let fileManager = FileManager.default
        let paths: [(String, String, String)] = [
            ("profile", "Typing profile (JSON)", profileEngine.persistenceDescription),
            ("exclusions", "Manual exclusions (JSON)", manualExclusionStore.persistenceDescription),
            ("evidence", "Practice evidence (SQLite)", evidenceStore.persistenceDescription)
        ]

        return paths.map { id, label, path in
            let attributes = (try? fileManager.attributesOfItem(atPath: path)) ?? [:]
            let size = (attributes[.size] as? NSNumber)?.int64Value
            let modified = attributes[.modificationDate] as? Date
            return StoreFileDescriptor(
                id: id,
                label: label,
                path: path,
                exists: fileManager.fileExists(atPath: path),
                sizeBytes: size,
                lastModified: modified
            )
        }
    }

    /// Copy all local stores into the destination directory. Returns the per-file destinations actually written.
    @discardableResult
    public func exportAllStores(to destinationDirectory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        var written: [URL] = []
        for descriptor in currentStoreFileDescriptors() where descriptor.exists {
            let source = URL(fileURLWithPath: descriptor.path)
            let target = destinationDirectory.appendingPathComponent(source.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.copyItem(at: source, to: target)
            written.append(target)
        }
        return written
    }

    /// Wipe every locally persisted store. Profile snapshots, manual exclusions, and the SQLite evidence ledger are removed.
    public func deleteAllStoredData() throws {
        clearPracticeRuntime()
        passiveSliceRecorder.reset()
        debugBuffer.reset()
        try profileEngine.reset()
        try? legacyAggregateStore.clear()
        try manualExclusionStore.clear()
        manualExcludedApplications = []

        let fileManager = FileManager.default
        let evidencePath = evidenceStore.persistenceDescription
        if fileManager.fileExists(atPath: evidencePath) {
            try fileManager.removeItem(atPath: evidencePath)
        }
        let walPath = evidencePath + "-wal"
        if fileManager.fileExists(atPath: walPath) {
            try? fileManager.removeItem(atPath: walPath)
        }
        let shmPath = evidencePath + "-shm"
        if fileManager.fileExists(atPath: shmPath) {
            try? fileManager.removeItem(atPath: shmPath)
        }

        unsavedProfileMutations = 0
        lastRuntimeNote = nil
        exclusionNote = "All local data has been deleted."
        refreshDerivedStateAndHealth()
    }

    public func resetCaptureData() {
        clearPracticeRuntime()
        passiveSliceRecorder.reset()
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
        } catch {
            lastRuntimeNote = "Could not clear profile store: \(error.localizedDescription)"
        }
        do {
            try legacyAggregateStore.clear()
        } catch {
            Self.logger.error("Could not clear legacy aggregate store during reset: \(error.localizedDescription, privacy: .public)")
        }

        advancedDiagnosticsAggregator.reset()
        refreshDerivedStateAndHealth()
    }

    public func startRecommendedPracticeSession() {
        guard let sessionPlan = state.learningModel.recommendedSession,
              let primaryWeakness = state.learningModel.primaryWeakness else {
            return
        }

        startPracticeSession(plan: sessionPlan, weakness: primaryWeakness)
    }

    public func startManualPracticeSession(family: PracticeDrillFamily) {
        let manualRecommendation = LearningModelEngine.manualPracticeRecommendation(for: family)
        startPracticeSession(plan: manualRecommendation.1, weakness: manualRecommendation.0)
    }

    public func observePracticeDeviceClass(_ deviceClass: String) {
        guard !deviceClass.isEmpty, deviceClass != currentPracticeDeviceClass else { return }
        currentPracticeDeviceClass = deviceClass
        refreshDerivedStateAndHealth()
    }

    private func startPracticeSession(plan: PracticeSessionPlan, weakness: WeaknessAssessment) {
        guard state.permissionState == .granted else { return }

        lastRuntimeNote = nil
        currentPracticeDeviceClass = "unknown-device"
        flushPassiveSliceIfNeeded(endedAt: Date())
        let decision = recommendationDecision(for: weakness)
        activeRecommendationDecision = decision
        evidenceStore.appendRecommendationDecision(decision)
        practiceRuntimeEngine.start(
            plan: plan,
            weakness: weakness
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
        if let artifact = practiceRuntimeEngine.cancel() {
            persistCompletedPracticeArtifact(artifact)
        }
        stopPracticeTimer()
        lastRuntimeNote = nil
        refreshDerivedStateAndHealth()
    }

    public func advancePracticeBlock() {
        if let artifact = practiceRuntimeEngine.advanceBlock() {
            persistCompletedPracticeArtifact(artifact)
        }
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
                self?.flushPassiveSliceIfNeeded(endedAt: Date())
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
                self?.flushPassiveSliceIfNeeded(endedAt: Date())
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

            if let slice = passiveSliceRecorder.record(
                classifiedEvent,
                keyboardLayoutID: currentKeyboardLayoutID(),
                keyboardDeviceClass: KeyboardContext.deviceClass(for: observedEvent),
                modelVersionStampID: modelVersionStamp.id
            ) {
                evidenceStore.appendPassiveSlices([slice])
                resolvePendingTransferTickets()
            }
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
        state.learningModel = overlayAppliedStateUpdates(on: LearningModelEngine.build(from: state.profileSnapshot))
        state.practiceRuntime = practiceRuntimeEngine.snapshot()
        state.practiceHistory = evidenceStore.fetchPracticeHistory(limit: 8)
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
            evidenceStorePath: evidenceStore.persistenceDescription,
            keyboardLayoutID: currentKeyboardLayoutID(),
            keyboardLayoutName: currentKeyboardLayoutName(),
            keyboardDeviceClass: currentPracticeDeviceClass,
            storesRawText: false,
            storesLiteralNGrams: false,
            note: "Typing Lens stores content-free daily profile summaries locally, plus aggregate-only coaching evidence in SQLite. Prompt text, typed practice responses, raw preview text, and raw event streams are not persisted.",
            persistenceWarning: composedPersistenceWarning()
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
        activeRecommendationDecision = nil
        currentPracticeDeviceClass = "unknown-device"
    }

    private func startPracticeTimer() {
        stopPracticeTimer()

        guard practiceRuntimeEngine.snapshot().status == .running else {
            return
        }

        practiceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let artifact = self.practiceRuntimeEngine.tick() {
                    self.persistCompletedPracticeArtifact(artifact)
                }
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

    private func recommendationDecision(for weakness: WeaknessAssessment) -> RecommendationDecisionRecord {
        RecommendationDecisionRecord(
            createdAt: Date(),
            selectedSkillID: weakness.targetSkillIDs.first ?? "unknownSkill",
            selectedWeakness: weakness.category,
            candidateSkillIDs: state.learningModel.weaknesses.flatMap(\.targetSkillIDs),
            candidateReasonCodes: weakness.supportingSignals,
            selectedBecauseReasonCode: weakness.rationale,
            passiveSnapshotReference: snapshotReference(),
            hysteresisApplied: false,
            suppressedBecausePendingTransfer: !state.practiceHistory.pendingTransferTickets.isEmpty,
            modelVersionStampID: modelVersionStamp.id
        )
    }

    private func snapshotReference() -> String {
        "todayKeys:\(state.profileSnapshot.today.includedKeyDownCount)|baselineDays:\(state.profileSnapshot.baselineDayCount)|last:\(state.profileSnapshot.today.lastIncludedEventAt?.ISO8601Format() ?? "none")"
    }

    private func currentKeyboardLayoutID() -> String {
        KeyboardContext.currentLayoutID()
    }

    private func currentKeyboardLayoutName() -> String {
        KeyboardContext.currentLayoutName()
    }

    private func flushPassiveSliceIfNeeded(endedAt: Date) {
        if let slice = passiveSliceRecorder.flushRemaining(modelVersionStampID: modelVersionStamp.id, endedAt: endedAt) {
            evidenceStore.appendPassiveSlices([slice])
            resolvePendingTransferTickets()
        }
    }

    private func persistCompletedPracticeArtifact(_ artifact: PracticeRuntimeEngine.CompletedSessionArtifact) {
        guard let decision = activeRecommendationDecision else {
            activeRecommendationDecision = nil
            return
        }

        let sessionID = UUID()

        let evaluations = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: sessionID,
            selectedSkillID: artifact.selectedSkillID,
            weakness: artifact.weakness,
            blocks: artifact.blockSummaries
        )

        let keyboardLayoutID = currentKeyboardLayoutID()
        let keyboardDeviceClass = currentPracticeDeviceClass
        let baselineSlices = evidenceStore.recentPassiveSlices(
            endingBefore: artifact.startedAt,
            keyboardLayoutID: keyboardLayoutID,
            keyboardDeviceClass: keyboardDeviceClass,
            limit: 3
        )
        let transferTicket = PracticeEvaluationEngine.makeTransferTicket(
            sessionID: sessionID,
            selectedSkillID: artifact.selectedSkillID,
            weakness: artifact.weakness,
            sessionEndedAt: artifact.endedAt,
            keyboardLayoutID: keyboardLayoutID,
            keyboardDeviceClass: keyboardDeviceClass,
            baselineSlices: baselineSlices
        )

        let passiveTransferStatusNote = passiveTransferStatusNote(
            for: artifact.weakness,
            keyboardLayoutID: keyboardLayoutID,
            keyboardDeviceClass: keyboardDeviceClass,
            baselineSliceCount: baselineSlices.count,
            createdTicket: transferTicket != nil
        )

        let sessionRecord = PracticeSessionSummaryRecord(
            id: sessionID,
            startedAt: artifact.startedAt,
            endedAt: artifact.endedAt,
            selectedSkillID: artifact.selectedSkillID,
            selectedWeakness: artifact.weakness.category,
            recommendationDecisionID: decision.id,
            modelVersionStampID: modelVersionStamp.id,
            targetConfirmationStatus: evaluations.targetConfirmationStatus,
            immediateOutcome: evaluations.immediateOutcome,
            nearTransferOutcome: evaluations.nearTransferOutcome,
            passiveTransferTicketID: transferTicket?.id,
            passiveTransferStatusNote: passiveTransferStatusNote,
            updateMode: .shadow,
            keyboardLayoutID: keyboardLayoutID,
            keyboardDeviceClass: keyboardDeviceClass,
            blockSummaries: artifact.blockSummaries
        )

        evidenceStore.appendPracticeSession(sessionRecord)
        evidenceStore.appendImmediateEvaluations(evaluations.evaluations)
        evaluations.updates.forEach { evidenceStore.appendLearnerStateUpdate($0) }
        if let transferTicket {
            evidenceStore.upsertTransferTicket(transferTicket)
        }

        activeRecommendationDecision = nil
        currentPracticeDeviceClass = "unknown-device"
        resolvePendingTransferTickets()
    }

    private func resolvePendingTransferTickets() {
        let history = evidenceStore.fetchPracticeHistory(limit: 32)
        let now = Date()

        for ticket in history.pendingTransferTickets {
            if now > ticket.expiresAt {
                evidenceStore.upsertTransferTicket(ticket.updating(status: .expired))
                continue
            }

            guard now >= ticket.earliestEligibleAt else {
                continue
            }

            let postSlices = evidenceStore.recentPassiveSlices(
                startingAfter: ticket.earliestEligibleAt,
                keyboardLayoutID: ticket.keyboardLayoutID,
                keyboardDeviceClass: ticket.keyboardDeviceClass,
                limit: max(ticket.requiredPostSliceCount, 3)
            )

            guard let evaluation = PracticeEvaluationEngine.evaluatePassiveTransfer(
                ticket: ticket,
                postSlices: postSlices
            ) else {
                continue
            }

            evidenceStore.appendTransferResult(evaluation.result)
            let shouldApply = shouldApplyPassiveUpdate(for: ticket.skillID, outcome: evaluation.result.outcome)
            let updateRecord = evaluation.update.applying(
                toRecommendations: shouldApply,
                extraReasonCodes: shouldApply ? ["appliedGatePassed"] : ["appliedGateDeferred"]
            )
            evidenceStore.appendLearnerStateUpdate(updateRecord)
            evidenceStore.upsertTransferTicket(ticket.updating(status: .resolved))
        }
    }

    private func shouldApplyPassiveUpdate(
        for skillID: String,
        outcome: PracticeEvaluationOutcome
    ) -> Bool {
        let sessionCount = evidenceStore.recentPracticeSessionCount(skillID: skillID)
        let positiveOutcome = outcome == .improvedWeak || outcome == .improvedStrong
        return positiveOutcome && sessionCount >= 3
    }

    private func overlayAppliedStateUpdates(on snapshot: LearningModelSnapshot) -> LearningModelSnapshot {
        let overlay = evidenceStore.appliedStateOverlay()
        guard !overlay.isEmpty else { return snapshot }

        let updatedStates = snapshot.studentStates.map { state -> StudentSkillState in
            guard let delta = overlay[state.id] else { return state }
            return StudentSkillState(
                id: state.id,
                title: state.title,
                current: state.current.adding(delta).clamped(),
                target: state.target,
                confidence: state.confidence,
                evidenceCount: state.evidenceCount,
                note: state.note + " Applied local evidence overlay adjusts this skill from prior resolved transfer results."
            )
        }

        let updatedWeaknesses = snapshot.weaknesses.map { weakness -> WeaknessAssessment in
            guard let skillID = weakness.targetSkillIDs.first,
                  let delta = overlay[skillID] else {
                return weakness
            }

            let shouldStabilize = delta.automaticity >= 0.04 || (delta.control + delta.consistency) >= 0.12
            guard shouldStabilize else { return weakness }

            return WeaknessAssessment(
                id: weakness.id,
                category: weakness.category,
                title: weakness.title,
                summary: weakness.summary,
                severity: downgradedSeverity(weakness.severity),
                confidence: weakness.confidence,
                lifecycleState: .stabilizing,
                supportingSignals: weakness.supportingSignals + ["appliedEvidenceOverlay"],
                targetSkillIDs: weakness.targetSkillIDs,
                recommendedDrill: weakness.recommendedDrill,
                rationale: weakness.rationale
            )
        }

        let primaryWeakness = updatedWeaknesses.first

        return LearningModelSnapshot(
            skillNodes: snapshot.skillNodes,
            skillEdges: snapshot.skillEdges,
            studentStates: updatedStates,
            weaknesses: updatedWeaknesses,
            primaryWeakness: primaryWeakness,
            recommendedSession: primaryWeakness.map(LearningModelEngine.recommendedSession(for:))
        )
    }

    private func passiveTransferStatusNote(
        for weakness: WeaknessAssessment,
        keyboardLayoutID: String,
        keyboardDeviceClass: String,
        baselineSliceCount: Int,
        createdTicket: Bool
    ) -> String {
        if createdTicket {
            return "Passive transfer ticket created. The app will wait for cooldown and then look for compatible passive slices."
        }

        if weakness.category == .flowConsistency {
            return "Passive transfer tracking is disabled for flow consistency in this tester build because the signal is still too confounded."
        }

        if keyboardLayoutID == "unknown" || keyboardDeviceClass == "unknown-device" {
            return "Passive transfer tracking was unavailable because the keyboard layout or device class could not be matched confidently."
        }

        if baselineSliceCount == 0 {
            return "Passive transfer ticket was not created because there were no compatible passive baseline slices before the session."
        }

        return "Passive transfer tracking was not created for this session."
    }

    private func downgradedSeverity(_ severity: WeaknessSeverity) -> WeaknessSeverity {
        switch severity {
        case .strong:
            return .moderate
        case .moderate:
            return .mild
        case .mild:
            return .mild
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
            return "Unexpected tap error: \(error.localizedDescription)"
        }
    }

    private func composedPersistenceWarning() -> String? {
        let warnings = [
            profileEngine.lastPersistenceError,
            evidenceStore.lastPersistenceError
        ].compactMap { $0 }

        guard !warnings.isEmpty else { return nil }
        return warnings.joined(separator: " ")
    }
}

private extension String {
    var nonEmptyOrNil: String? {
        isEmpty ? nil : self
    }
}
