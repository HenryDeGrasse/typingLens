import Core
import Foundation

final class PassiveSliceRecorder {
    private struct SliceState {
        var startedAt: Date?
        var keyboardLayoutID = "unknown"
        var keyboardDeviceClass = "unknown"
        var summary = TypingProfileSummary()
        var activeTypingMilliseconds: Double = 0
        var currentBurstLength = 0
        var currentCorrectionBurstLength = 0
        var lastIncludedKeyDownAt: Date?
        var lastIncludedKeyCode: Int64?
        var lastBackspaceAt: Date?

        mutating func reset() {
            startedAt = nil
            keyboardLayoutID = "unknown"
            keyboardDeviceClass = "unknown"
            summary = TypingProfileSummary()
            activeTypingMilliseconds = 0
            currentBurstLength = 0
            currentCorrectionBurstLength = 0
            lastIncludedKeyDownAt = nil
            lastIncludedKeyCode = nil
            lastBackspaceAt = nil
        }
    }

    private let burstBoundaryMilliseconds: Double
    private let sessionBoundaryMilliseconds: Double
    private let maxFlightMilliseconds: Double
    private let flushKeyDownThreshold: Int
    private let minimumKeyDownsForSlice: Int
    private let activeTypingThresholdMilliseconds: Double
    private var state = SliceState()

    init(
        burstBoundaryMilliseconds: Double = 750,
        sessionBoundaryMilliseconds: Double = 30_000,
        maxFlightMilliseconds: Double = 2_000,
        flushKeyDownThreshold: Int = 180,
        minimumKeyDownsForSlice: Int = 60,
        activeTypingThresholdMilliseconds: Double = 120_000
    ) {
        self.burstBoundaryMilliseconds = burstBoundaryMilliseconds
        self.sessionBoundaryMilliseconds = sessionBoundaryMilliseconds
        self.maxFlightMilliseconds = maxFlightMilliseconds
        self.flushKeyDownThreshold = flushKeyDownThreshold
        self.minimumKeyDownsForSlice = minimumKeyDownsForSlice
        self.activeTypingThresholdMilliseconds = activeTypingThresholdMilliseconds
    }

    func record(
        _ event: ClassifiedKeyEvent,
        keyboardLayoutID: String,
        keyboardDeviceClass: String,
        modelVersionStampID: String
    ) -> PassiveActiveSliceRecord? {
        guard event.eventPhase == .keyDown, event.shouldUseInProfile else {
            return nil
        }

        var flushRecord: PassiveActiveSliceRecord?
        if let lastIncludedKeyDownAt = state.lastIncludedKeyDownAt,
           state.startedAt != nil,
           state.keyboardLayoutID != keyboardLayoutID || state.keyboardDeviceClass != keyboardDeviceClass {
            if state.summary.includedKeyDownCount >= minimumKeyDownsForSlice {
                flushRecord = flushIfPossible(endedAt: lastIncludedKeyDownAt, modelVersionStampID: modelVersionStampID)
            } else {
                state.reset()
            }
        }

        if let lastIncludedKeyDownAt = state.lastIncludedKeyDownAt {
            let pauseMilliseconds = event.timestamp.timeIntervalSince(lastIncludedKeyDownAt) * 1_000
            if pauseMilliseconds >= sessionBoundaryMilliseconds,
               state.summary.includedKeyDownCount >= minimumKeyDownsForSlice {
                flushRecord = flushIfPossible(endedAt: lastIncludedKeyDownAt, modelVersionStampID: modelVersionStampID)
            } else if pauseMilliseconds >= sessionBoundaryMilliseconds {
                state.reset()
            }
        }

        if state.startedAt == nil {
            state.startedAt = event.timestamp
            state.keyboardLayoutID = keyboardLayoutID
            state.keyboardDeviceClass = keyboardDeviceClass
        }

        recordIncludedKeyDown(event)

        if state.summary.includedKeyDownCount >= flushKeyDownThreshold || state.activeTypingMilliseconds >= activeTypingThresholdMilliseconds {
            return flushIfPossible(endedAt: event.timestamp, modelVersionStampID: modelVersionStampID) ?? flushRecord
        }

        return flushRecord
    }

    func flushRemaining(modelVersionStampID: String, endedAt: Date = Date()) -> PassiveActiveSliceRecord? {
        flushIfPossible(endedAt: endedAt, modelVersionStampID: modelVersionStampID)
    }

    func reset() {
        state.reset()
    }

    private func recordIncludedKeyDown(_ event: ClassifiedKeyEvent) {
        if let lastIncludedKeyDownAt = state.lastIncludedKeyDownAt,
           let lastIncludedKeyCode = state.lastIncludedKeyCode {
            let pauseMilliseconds = event.timestamp.timeIntervalSince(lastIncludedKeyDownAt) * 1_000

            if pauseMilliseconds >= sessionBoundaryMilliseconds {
                state.summary.pauseHistogram.insert(pauseMilliseconds)
                closeCurrentBurstIfNeeded()
                closeCorrectionBurstIfNeeded()
            } else if pauseMilliseconds >= burstBoundaryMilliseconds {
                state.summary.pauseHistogram.insert(pauseMilliseconds)
                closeCurrentBurstIfNeeded()
                closeCorrectionBurstIfNeeded()
            } else if pauseMilliseconds >= 0, pauseMilliseconds <= maxFlightMilliseconds {
                state.summary.flightHistogram.insert(pauseMilliseconds)
                state.activeTypingMilliseconds += pauseMilliseconds

                let handPattern = KeyGeometryMap.handPattern(from: lastIncludedKeyCode, to: event.keyCode)
                var handHistogram = state.summary.flightByHandPattern[handPattern.rawValue, default: .timing()]
                handHistogram.insert(pauseMilliseconds)
                state.summary.flightByHandPattern[handPattern.rawValue] = handHistogram

                let distanceBucket = KeyGeometryMap.distanceBucket(from: lastIncludedKeyCode, to: event.keyCode)
                var distanceHistogram = state.summary.flightByDistanceBucket[distanceBucket.rawValue, default: .timing()]
                distanceHistogram.insert(pauseMilliseconds)
                state.summary.flightByDistanceBucket[distanceBucket.rawValue] = distanceHistogram
            }
        }

        state.summary.includedKeyDownCount += 1
        if event.countsAsPrintable {
            state.summary.printableKeyDownCount += 1
        }
        if event.isBackspace {
            state.summary.backspaceCount += 1
        }
        state.summary.lastIncludedEventAt = event.timestamp
        state.summary.lastUpdatedAt = event.timestamp
        state.currentBurstLength += 1

        if event.isBackspace {
            if state.currentCorrectionBurstLength == 0,
               let lastIncludedKeyDownAt = state.lastIncludedKeyDownAt {
                let hesitationMilliseconds = event.timestamp.timeIntervalSince(lastIncludedKeyDownAt) * 1_000
                if hesitationMilliseconds >= 0, hesitationMilliseconds <= maxFlightMilliseconds {
                    state.summary.preCorrectionFlightHistogram.insert(hesitationMilliseconds)
                }
            }
            state.currentCorrectionBurstLength += 1
            state.lastBackspaceAt = event.timestamp
        } else if state.currentCorrectionBurstLength > 0 {
            if let lastBackspaceAt = state.lastBackspaceAt {
                let recoveryMilliseconds = event.timestamp.timeIntervalSince(lastBackspaceAt) * 1_000
                if recoveryMilliseconds >= 0, recoveryMilliseconds <= maxFlightMilliseconds {
                    state.summary.recoveryFlightHistogram.insert(recoveryMilliseconds)
                }
            }
            closeCorrectionBurstIfNeeded()
        }

        state.lastIncludedKeyDownAt = event.timestamp
        state.lastIncludedKeyCode = event.keyCode
    }

    private func closeCurrentBurstIfNeeded() {
        guard state.currentBurstLength > 0 else { return }
        state.summary.burstCount += 1
        state.summary.totalBurstKeyCount += state.currentBurstLength
        state.summary.burstLengthHistogram.insert(Double(state.currentBurstLength))
        state.currentBurstLength = 0
    }

    private func closeCorrectionBurstIfNeeded() {
        guard state.currentCorrectionBurstLength > 0 else { return }
        state.summary.correctionBurstHistogram.insert(Double(state.currentCorrectionBurstLength))
        state.currentCorrectionBurstLength = 0
        state.lastBackspaceAt = nil
    }

    private func flushIfPossible(endedAt: Date, modelVersionStampID: String) -> PassiveActiveSliceRecord? {
        guard state.summary.includedKeyDownCount >= minimumKeyDownsForSlice,
              let startedAt = state.startedAt else {
            return nil
        }

        closeCurrentBurstIfNeeded()
        closeCorrectionBurstIfNeeded()

        let record = PassiveActiveSliceRecord(
            startedAt: startedAt,
            endedAt: endedAt,
            activeTypingMilliseconds: Int(state.activeTypingMilliseconds.rounded()),
            totalKeyDowns: state.summary.includedKeyDownCount,
            keyboardLayoutID: state.keyboardLayoutID,
            keyboardDeviceClass: state.keyboardDeviceClass,
            modelVersionStampID: modelVersionStampID,
            summary: state.summary
        )
        state.reset()
        return record
    }
}
