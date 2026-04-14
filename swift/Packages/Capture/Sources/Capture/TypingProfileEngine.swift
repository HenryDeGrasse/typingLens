import Core
import Foundation

final class TypingProfileEngine {
    private struct ActiveKeyDown {
        let timestamp: Date
        let keyClass: KeyClass
    }

    private struct SessionState {
        var isSessionOpen = false
        var currentBurstLength = 0
        var lastIncludedKeyDownAt: Date?
        var lastIncludedKeyCode: Int64?
        var currentCorrectionBurstLength = 0
        var lastBackspaceAt: Date?
        var backspaceHoldStartedAt: Date?
        var sawHeldDeleteAutoRepeat = false

        mutating func clearContinuity() {
            isSessionOpen = false
            currentBurstLength = 0
            lastIncludedKeyDownAt = nil
            lastIncludedKeyCode = nil
            currentCorrectionBurstLength = 0
            lastBackspaceAt = nil
            backspaceHoldStartedAt = nil
            sawHeldDeleteAutoRepeat = false
        }
    }

    private let store: TypingProfileStore
    private let calendar: Calendar
    private let burstBoundaryMilliseconds: Double
    private let sessionBoundaryMilliseconds: Double
    private let maxFlightMilliseconds: Double
    private let maxStoredDays: Int

    private var persistedSnapshot: PersistedProfileStoreSnapshot
    private var currentDayIdentifier: String
    private var currentDaySummary: TypingProfileSummary
    private var sessionState = SessionState()
    private var activeKeyDowns: [Int64: ActiveKeyDown] = [:]

    init(
        store: TypingProfileStore = TypingProfileStore(),
        calendar: Calendar = .current,
        burstBoundaryMilliseconds: Double = 750,
        sessionBoundaryMilliseconds: Double = 30_000,
        maxFlightMilliseconds: Double = 2_000,
        maxStoredDays: Int = 45,
        now: Date = Date()
    ) {
        self.store = store
        self.calendar = calendar
        self.burstBoundaryMilliseconds = burstBoundaryMilliseconds
        self.sessionBoundaryMilliseconds = sessionBoundaryMilliseconds
        self.maxFlightMilliseconds = maxFlightMilliseconds
        self.maxStoredDays = maxStoredDays
        self.persistedSnapshot = store.load()
        let initialDayIdentifier = Self.dayIdentifier(for: now, calendar: calendar)
        self.currentDayIdentifier = initialDayIdentifier
        self.currentDaySummary = persistedSnapshot.dayRecords.first(where: { $0.dayIdentifier == initialDayIdentifier })?.summary
            ?? TypingProfileSummary()
    }

    var persistenceDescription: String {
        store.persistenceDescription
    }

    func currentSnapshot() -> TypingProfileSnapshot {
        let baselineRecords = persistedSnapshot.dayRecords
            .filter { $0.dayIdentifier != currentDayIdentifier && $0.summary.includedKeyDownCount > 0 }
            .suffix(14)

        var baselineSummary = TypingProfileSummary()
        for record in baselineRecords {
            baselineSummary.merge(record.summary)
        }

        return TypingProfileSnapshot(
            today: currentDaySummary,
            baseline: baselineSummary,
            baselineDayCount: baselineRecords.count,
            confidence: confidenceState(baselineDayCount: baselineRecords.count),
            insights: insights(
                today: currentDaySummary,
                baseline: baselineSummary,
                baselineDayCount: baselineRecords.count
            )
        )
    }

    func recordExcludedKeyDown(at timestamp: Date) {
        rolloverDayIfNeeded(for: timestamp)
        currentDaySummary.excludedEventCount += 1
        currentDaySummary.lastUpdatedAt = timestamp
        closeCurrentBurstIfNeeded()
        closeCorrectionBurstIfNeeded()
        activeKeyDowns.removeAll(keepingCapacity: true)
        sessionState.clearContinuity()
    }

    func record(_ event: ClassifiedKeyEvent) {
        rolloverDayIfNeeded(for: event.timestamp)

        switch event.eventPhase {
        case .keyDown:
            handleKeyDown(event)
        case .keyUp:
            handleKeyUp(event)
        }
    }

    func interruptSession() {
        closeCurrentBurstIfNeeded()
        closeCorrectionBurstIfNeeded()
        activeKeyDowns.removeAll(keepingCapacity: true)
        sessionState.clearContinuity()
    }

    func reset() throws {
        persistedSnapshot = PersistedProfileStoreSnapshot()
        currentDaySummary = TypingProfileSummary()
        activeKeyDowns.removeAll(keepingCapacity: true)
        sessionState.clearContinuity()
        try store.clear()
    }

    func persist() throws {
        upsertCurrentDayRecord()
        try store.save(persistedSnapshot)
    }

    private func handleKeyDown(_ event: ClassifiedKeyEvent) {
        if event.shouldTrackDwell {
            activeKeyDowns[event.keyCode] = ActiveKeyDown(
                timestamp: event.timestamp,
                keyClass: event.keyClass
            )
        }

        if event.isBackspace {
            if event.isAutoRepeat {
                sessionState.sawHeldDeleteAutoRepeat = true
                return
            }

            if sessionState.backspaceHoldStartedAt == nil {
                sessionState.backspaceHoldStartedAt = event.timestamp
            }
        }

        guard event.shouldUseInProfile else {
            return
        }

        if !sessionState.isSessionOpen {
            currentDaySummary.sessionCount += 1
            sessionState.isSessionOpen = true
        }

        if let lastIncludedKeyDownAt = sessionState.lastIncludedKeyDownAt,
           let lastIncludedKeyCode = sessionState.lastIncludedKeyCode {
            let pauseMilliseconds = event.timestamp.timeIntervalSince(lastIncludedKeyDownAt) * 1_000

            if pauseMilliseconds >= sessionBoundaryMilliseconds {
                currentDaySummary.pauseHistogram.insert(pauseMilliseconds)
                closeCurrentBurstIfNeeded()
                closeCorrectionBurstIfNeeded()
                currentDaySummary.sessionCount += 1
                sessionState.isSessionOpen = true
            } else if pauseMilliseconds >= burstBoundaryMilliseconds {
                currentDaySummary.pauseHistogram.insert(pauseMilliseconds)
                closeCurrentBurstIfNeeded()
                closeCorrectionBurstIfNeeded()
            } else if pauseMilliseconds >= 0, pauseMilliseconds <= maxFlightMilliseconds {
                currentDaySummary.flightHistogram.insert(pauseMilliseconds)

                let handPattern = KeyGeometryMap.handPattern(from: lastIncludedKeyCode, to: event.keyCode)
                var handHistogram = currentDaySummary.flightByHandPattern[handPattern.rawValue, default: .timing()]
                handHistogram.insert(pauseMilliseconds)
                currentDaySummary.flightByHandPattern[handPattern.rawValue] = handHistogram

                let distanceBucket = KeyGeometryMap.distanceBucket(from: lastIncludedKeyCode, to: event.keyCode)
                var distanceHistogram = currentDaySummary.flightByDistanceBucket[distanceBucket.rawValue, default: .timing()]
                distanceHistogram.insert(pauseMilliseconds)
                currentDaySummary.flightByDistanceBucket[distanceBucket.rawValue] = distanceHistogram
            }
        }

        currentDaySummary.includedKeyDownCount += 1
        if event.countsAsPrintable {
            currentDaySummary.printableKeyDownCount += 1
        }
        if event.isBackspace {
            currentDaySummary.backspaceCount += 1
        }
        currentDaySummary.lastIncludedEventAt = event.timestamp
        currentDaySummary.lastUpdatedAt = event.timestamp

        sessionState.currentBurstLength += 1

        if event.isBackspace {
            if sessionState.currentCorrectionBurstLength == 0,
               let lastIncludedKeyDownAt = sessionState.lastIncludedKeyDownAt {
                let hesitationMilliseconds = event.timestamp.timeIntervalSince(lastIncludedKeyDownAt) * 1_000
                if hesitationMilliseconds >= 0, hesitationMilliseconds <= maxFlightMilliseconds {
                    currentDaySummary.preCorrectionFlightHistogram.insert(hesitationMilliseconds)
                }
            }

            sessionState.currentCorrectionBurstLength += 1
            sessionState.lastBackspaceAt = event.timestamp
        } else if sessionState.currentCorrectionBurstLength > 0 {
            if let lastBackspaceAt = sessionState.lastBackspaceAt {
                let recoveryMilliseconds = event.timestamp.timeIntervalSince(lastBackspaceAt) * 1_000
                if recoveryMilliseconds >= 0, recoveryMilliseconds <= maxFlightMilliseconds {
                    currentDaySummary.recoveryFlightHistogram.insert(recoveryMilliseconds)
                }
            }
            closeCorrectionBurstIfNeeded()
        }

        sessionState.lastIncludedKeyDownAt = event.timestamp
        sessionState.lastIncludedKeyCode = event.keyCode
    }

    private func handleKeyUp(_ event: ClassifiedKeyEvent) {
        guard event.shouldTrackDwell else {
            activeKeyDowns.removeValue(forKey: event.keyCode)
            return
        }

        guard let activeKeyDown = activeKeyDowns.removeValue(forKey: event.keyCode) else {
            return
        }

        if event.isBackspace,
           let backspaceHoldStartedAt = sessionState.backspaceHoldStartedAt {
            if sessionState.sawHeldDeleteAutoRepeat {
                let heldDeleteDuration = event.timestamp.timeIntervalSince(backspaceHoldStartedAt) * 1_000
                if heldDeleteDuration >= 0 {
                    currentDaySummary.heldDeleteBurstCount += 1
                    currentDaySummary.heldDeleteDurationHistogram.insert(heldDeleteDuration)
                    sessionState.lastBackspaceAt = event.timestamp
                }
            }

            sessionState.backspaceHoldStartedAt = nil
            sessionState.sawHeldDeleteAutoRepeat = false
        }

        let dwellMilliseconds = event.timestamp.timeIntervalSince(activeKeyDown.timestamp) * 1_000
        guard dwellMilliseconds >= 0, dwellMilliseconds <= maxFlightMilliseconds else {
            return
        }

        currentDaySummary.dwellHistogram.insert(dwellMilliseconds)
        var dwellHistogram = currentDaySummary.dwellByKeyClass[activeKeyDown.keyClass.rawValue, default: .timing()]
        dwellHistogram.insert(dwellMilliseconds)
        currentDaySummary.dwellByKeyClass[activeKeyDown.keyClass.rawValue] = dwellHistogram
        currentDaySummary.lastUpdatedAt = event.timestamp
    }

    private func closeCurrentBurstIfNeeded() {
        guard sessionState.currentBurstLength > 0 else {
            return
        }

        currentDaySummary.burstCount += 1
        currentDaySummary.totalBurstKeyCount += sessionState.currentBurstLength
        currentDaySummary.burstLengthHistogram.insert(Double(sessionState.currentBurstLength))
        sessionState.currentBurstLength = 0
    }

    private func closeCorrectionBurstIfNeeded() {
        guard sessionState.currentCorrectionBurstLength > 0 else {
            return
        }

        currentDaySummary.correctionBurstHistogram.insert(Double(sessionState.currentCorrectionBurstLength))
        sessionState.currentCorrectionBurstLength = 0
        sessionState.lastBackspaceAt = nil
    }

    private func rolloverDayIfNeeded(for timestamp: Date) {
        let incomingDayIdentifier = Self.dayIdentifier(for: timestamp, calendar: calendar)
        guard incomingDayIdentifier != currentDayIdentifier else {
            return
        }

        closeCurrentBurstIfNeeded()
        closeCorrectionBurstIfNeeded()
        upsertCurrentDayRecord()

        currentDayIdentifier = incomingDayIdentifier
        currentDaySummary = persistedSnapshot.dayRecords.first(where: { $0.dayIdentifier == incomingDayIdentifier })?.summary
            ?? TypingProfileSummary()
        activeKeyDowns.removeAll(keepingCapacity: true)
        sessionState.clearContinuity()
    }

    private func upsertCurrentDayRecord() {
        if let index = persistedSnapshot.dayRecords.firstIndex(where: { $0.dayIdentifier == currentDayIdentifier }) {
            persistedSnapshot.dayRecords[index].summary = currentDaySummary
        } else {
            persistedSnapshot.dayRecords.append(
                PersistedProfileDayRecord(
                    dayIdentifier: currentDayIdentifier,
                    summary: currentDaySummary
                )
            )
        }

        persistedSnapshot.dayRecords.sort { $0.dayIdentifier < $1.dayIdentifier }
        if persistedSnapshot.dayRecords.count > maxStoredDays {
            persistedSnapshot.dayRecords.removeFirst(persistedSnapshot.dayRecords.count - maxStoredDays)
        }
    }

    private func confidenceState(baselineDayCount: Int) -> ProfileConfidenceState {
        if currentDaySummary.includedKeyDownCount < 200 && baselineDayCount == 0 {
            return .warmingUp
        }

        if baselineDayCount < 3 {
            return .buildingBaseline
        }

        return .ready
    }

    private func insights(
        today: TypingProfileSummary,
        baseline: TypingProfileSummary,
        baselineDayCount: Int
    ) -> [ProfileInsight] {
        guard today.includedKeyDownCount > 0 else {
            return [
                ProfileInsight(
                    title: "Profile starts after real typing",
                    detail: "Type in a non-excluded app to start building a local profile for rhythm, flow, correction, and reach."
                )
            ]
        }

        if baselineDayCount == 0 {
            return [
                ProfileInsight(
                    title: "Baseline is warming up",
                    detail: "Typing Lens is collecting your first day of profile data. Use it across a few sessions before trusting deltas too heavily."
                )
            ]
        }

        var results: [ProfileInsight] = []

        if baseline.backspaceDensity > 0,
           today.backspaceDensity > baseline.backspaceDensity * 1.2,
           today.backspaceDensity - baseline.backspaceDensity > 0.01 {
            results.append(
                ProfileInsight(
                    title: "Correction pressure is higher today",
                    detail: "Backspace density is above your baseline, which usually means more edits or recoveries inside bursts."
                )
            )
        }

        if baseline.averageBurstLength > 0,
           today.averageBurstLength > 0,
           today.averageBurstLength < baseline.averageBurstLength * 0.85 {
            results.append(
                ProfileInsight(
                    title: "Typing flow is more fragmented",
                    detail: "Average burst length is shorter than your baseline, so today’s typing is breaking into smaller chunks."
                )
            )
        }

        if let todayP90 = today.flightStats.p90Milliseconds,
           let baselineP90 = baseline.flightStats.p90Milliseconds,
           todayP90 > baselineP90 * 1.1 {
            results.append(
                ProfileInsight(
                    title: "High-latency transitions slowed down",
                    detail: "Your slower flight-time tail is above baseline, which usually shows up as more hesitation or awkward reaches."
                )
            )
        }

        let todaySameHand = today.flightStats(for: .sameHand)
        let todayCrossHand = today.flightStats(for: .crossHand)
        if let sameHandP90 = todaySameHand.p90Milliseconds,
           let crossHandP90 = todayCrossHand.p90Milliseconds,
           sameHandP90 > crossHandP90 * 1.1,
           todaySameHand.sampleCount >= 20,
           todayCrossHand.sampleCount >= 20 {
            results.append(
                ProfileInsight(
                    title: "Same-hand reaches are your main friction point",
                    detail: "Cross-hand transitions are currently smoother than same-hand transitions, which is a useful target for future drills."
                )
            )
        }

        if results.isEmpty {
            results.append(
                ProfileInsight(
                    title: "Profile is tracking steadily",
                    detail: "Today’s rhythm and correction patterns are close to your recent baseline. Keep using the app across a few days for stronger trends."
                )
            )
        }

        return Array(results.prefix(3))
    }

    private static func dayIdentifier(
        for date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
