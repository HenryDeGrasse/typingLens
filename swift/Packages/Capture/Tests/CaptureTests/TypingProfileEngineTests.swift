import Foundation
import Testing
@testable import Capture
@testable import Core

@Suite("TypingProfileEngine")
final class TypingProfileEngineTests {
    private let tempStoreURL: URL

    init() {
        self.tempStoreURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("TypingLensTests-\(UUID().uuidString).json")
    }

    deinit {
        if FileManager.default.fileExists(atPath: tempStoreURL.path) {
            try? FileManager.default.removeItem(at: tempStoreURL)
        }
    }

    // MARK: - Snapshot defaults

    @Test func freshEngineHasWarmingUpConfidence() {
        let engine = makeEngine()
        let snapshot = engine.currentSnapshot()
        #expect(snapshot.confidence == .warmingUp)
        #expect(snapshot.today.includedKeyDownCount == 0)
    }

    // MARK: - Burst aggregation

    @Test func includedKeyDownsAccumulateInTodaySummary() {
        let engine = makeEngine()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<10 {
            engine.record(makeLetterEvent(at: now.addingTimeInterval(Double(i) * 0.1), keyCode: 0))
        }
        let snapshot = engine.currentSnapshot()
        #expect(snapshot.today.includedKeyDownCount == 10)
        #expect(snapshot.today.printableKeyDownCount == 10)
    }

    @Test func flightHistogramBuildsFromConsecutiveKeyDowns() {
        let engine = makeEngine()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<5 {
            engine.record(makeLetterEvent(at: now.addingTimeInterval(Double(i) * 0.15), keyCode: 0))
        }
        let snapshot = engine.currentSnapshot()
        #expect(snapshot.today.flightHistogram.sampleCount == 4)
    }

    @Test func pauseAboveBurstBoundaryClosesBurstAndIncrementsCount() {
        let engine = makeEngine(burstBoundaryMilliseconds: 500)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        engine.record(makeLetterEvent(at: start, keyCode: 0))
        engine.record(makeLetterEvent(at: start.addingTimeInterval(0.1), keyCode: 1))
        engine.record(makeLetterEvent(at: start.addingTimeInterval(0.7), keyCode: 0))

        let snapshot = engine.currentSnapshot()
        #expect(snapshot.today.burstCount == 1)
        #expect(snapshot.today.pauseHistogram.sampleCount > 0)
    }

    @Test func interruptSessionClosesOpenBurst() {
        let engine = makeEngine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        engine.record(makeLetterEvent(at: start, keyCode: 0))
        engine.record(makeLetterEvent(at: start.addingTimeInterval(0.1), keyCode: 1))
        engine.interruptSession()
        let snapshot = engine.currentSnapshot()
        #expect(snapshot.today.burstCount == 1)
    }

    // MARK: - Backspace behavior

    @Test func backspaceIncrementsBackspaceCountAndDensity() {
        let engine = makeEngine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        engine.record(makeLetterEvent(at: start, keyCode: 0))
        engine.record(makeBackspaceEvent(at: start.addingTimeInterval(0.1)))
        engine.record(makeLetterEvent(at: start.addingTimeInterval(0.2), keyCode: 1))

        let snapshot = engine.currentSnapshot()
        #expect(snapshot.today.backspaceCount == 1)
        #expect(snapshot.today.backspaceDensity > 0)
    }

    @Test func recoveryFlightCapturedAfterCorrectionBurst() {
        let engine = makeEngine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        engine.record(makeLetterEvent(at: start, keyCode: 0))
        engine.record(makeBackspaceEvent(at: start.addingTimeInterval(0.05)))
        engine.record(makeLetterEvent(at: start.addingTimeInterval(0.45), keyCode: 1))

        let snapshot = engine.currentSnapshot()
        #expect(snapshot.today.recoveryFlightHistogram.sampleCount > 0)
    }

    // MARK: - Excluded events

    @Test func excludedKeyDownIncrementsExcludedCounterAndClearsContinuity() {
        let engine = makeEngine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        engine.record(makeLetterEvent(at: start, keyCode: 0))
        engine.record(makeLetterEvent(at: start.addingTimeInterval(0.1), keyCode: 1))
        engine.recordExcludedKeyDown(at: start.addingTimeInterval(0.2))
        engine.record(makeLetterEvent(at: start.addingTimeInterval(0.3), keyCode: 0))

        let snapshot = engine.currentSnapshot()
        #expect(snapshot.today.excludedEventCount == 1)
        #expect(snapshot.today.flightHistogram.sampleCount == 1)
    }

    // MARK: - Persistence round-trip

    @Test func persistAndReloadProducesEqualTodaySummary() throws {
        let engine = makeEngine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<6 {
            engine.record(makeLetterEvent(at: start.addingTimeInterval(Double(i) * 0.1), keyCode: 0))
        }
        try engine.persist()

        let reloaded = makeEngine(now: start)
        let snapshot = reloaded.currentSnapshot()
        #expect(snapshot.today.includedKeyDownCount == 6)
    }

    @Test func resetClearsTodaySummary() throws {
        let engine = makeEngine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        engine.record(makeLetterEvent(at: start, keyCode: 0))
        try engine.persist()
        try engine.reset()

        #expect(engine.currentSnapshot().today.includedKeyDownCount == 0)
    }

    // MARK: - Helpers

    private func makeEngine(
        burstBoundaryMilliseconds: Double = 750,
        sessionBoundaryMilliseconds: Double = 30_000,
        maxFlightMilliseconds: Double = 2_000,
        maxStoredDays: Int = 90,
        now: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> TypingProfileEngine {
        let store = TypingProfileStore(storeURL: tempStoreURL)
        return TypingProfileEngine(
            store: store,
            calendar: .current,
            burstBoundaryMilliseconds: burstBoundaryMilliseconds,
            sessionBoundaryMilliseconds: sessionBoundaryMilliseconds,
            maxFlightMilliseconds: maxFlightMilliseconds,
            maxStoredDays: maxStoredDays,
            now: now
        )
    }

    private func makeLetterEvent(at timestamp: Date, keyCode: Int64) -> ClassifiedKeyEvent {
        ClassifiedKeyEvent(
            timestamp: timestamp,
            keyCode: keyCode,
            keyboardType: 41,
            deviceID: 1,
            eventPhase: .keyDown,
            kind: "keyDown",
            debugRenderedValue: "a",
            advancedAggregateToken: "a",
            keyClass: .letter,
            isBackspace: false,
            isAutoRepeat: false,
            countsAsPrintable: true,
            shouldUseInProfile: true,
            shouldTrackDwell: true
        )
    }

    private func makeBackspaceEvent(at timestamp: Date) -> ClassifiedKeyEvent {
        ClassifiedKeyEvent(
            timestamp: timestamp,
            keyCode: 51,
            keyboardType: 41,
            deviceID: 1,
            eventPhase: .keyDown,
            kind: "keyDown",
            debugRenderedValue: "⌫",
            advancedAggregateToken: "⌫",
            keyClass: .backspace,
            isBackspace: true,
            isAutoRepeat: false,
            countsAsPrintable: false,
            shouldUseInProfile: true,
            shouldTrackDwell: true
        )
    }
}
