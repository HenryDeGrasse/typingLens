import Foundation
import Testing
@testable import Capture
@testable import Core

@Suite("PracticeEvidenceStore")
final class PracticeEvidenceStoreTests {
    private let tempDirectory: URL

    init() throws {
        let dir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("TypingLensEvidenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.tempDirectory = dir
    }

    deinit {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Initialization

    @Test func freshStoreInitializesWithoutPersistenceError() {
        let store = makeStore()
        #expect(store.lastPersistenceError == nil)
        #expect(store.persistenceDescription.contains("evidence.sqlite3"))
    }

    @Test func freshHistoryIsEmpty() {
        let store = makeStore()
        let history = store.fetchPracticeHistory()
        #expect(history.modelVersionStamp == nil)
        #expect(history.recentSessions.isEmpty)
        #expect(history.recentEvaluations.isEmpty)
    }

    // MARK: - Model version stamp

    @Test func ensureModelVersionStampPersistsFirstWriteOnly() {
        let store = makeStore()
        let stamp = makeStamp(id: "stamp-1")
        store.ensureModelVersionStamp(stamp)
        store.ensureModelVersionStamp(makeStamp(id: "stamp-1"))

        let history = store.fetchPracticeHistory()
        #expect(history.modelVersionStamp?.id == "stamp-1")
    }

    // MARK: - Sessions

    @Test func appendPracticeSessionRoundTripsThroughHistory() {
        let store = makeStore()
        let session = makeSession()
        store.appendPracticeSession(session)

        let history = store.fetchPracticeHistory(limit: 4)
        #expect(history.recentSessions.count == 1)
        #expect(history.recentSessions.first?.id == session.id)
    }

    @Test func recentSessionsRespectLimitAndOrder() {
        let store = makeStore()
        for index in 0..<5 {
            store.appendPracticeSession(makeSession(endedAt: Date(timeIntervalSince1970: 1_000 + Double(index) * 10)))
        }
        let history = store.fetchPracticeHistory(limit: 3)
        #expect(history.recentSessions.count == 3)
        let times = history.recentSessions.map(\.endedAt)
        #expect(times == times.sorted(by: >))
    }

    // MARK: - Recommendation decisions

    @Test func recommendationDecisionRoundTrip() {
        let store = makeStore()
        let decision = RecommendationDecisionRecord(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            selectedSkillID: "sameHandShortControl",
            selectedWeakness: .sameHandSequences,
            candidateSkillIDs: ["sameHandShortControl"],
            candidateReasonCodes: ["ratio>=1.18"],
            selectedBecauseReasonCode: "ratio",
            passiveSnapshotReference: "ref",
            hysteresisApplied: false,
            suppressedBecausePendingTransfer: false,
            modelVersionStampID: "stamp-1"
        )
        store.appendRecommendationDecision(decision)
        let history = store.fetchPracticeHistory()
        #expect(history.recentDecisions.first?.id == decision.id)
    }

    // MARK: - Transfer ticket lifecycle

    @Test func transferTicketIsRetrievableWhilePending() {
        let store = makeStore()
        let ticket = makeTicket(status: .pending)
        store.upsertTransferTicket(ticket)
        let history = store.fetchPracticeHistory()
        #expect(history.pendingTransferTickets.count == 1)
        #expect(history.pendingTransferTickets.first?.id == ticket.id)
    }

    @Test func resolvedTicketDropsFromPendingList() {
        let store = makeStore()
        let ticket = makeTicket(status: .pending)
        store.upsertTransferTicket(ticket)
        store.upsertTransferTicket(ticket.updating(status: .resolved))

        let history = store.fetchPracticeHistory()
        #expect(history.pendingTransferTickets.isEmpty)
    }

    @Test func appendTransferResultIsRetrievable() {
        let store = makeStore()
        let result = PassiveTransferResultRecord(
            ticketID: UUID(),
            resolvedAt: Date(),
            baselineSliceIDs: [],
            postSliceIDs: [],
            outcome: .improvedWeak,
            evidenceWeight: 1,
            reasonCodes: ["test"],
            metricDeltaSummary: ["k": 1.0],
            evaluatorVersion: 1
        )
        store.appendTransferResult(result)
        let history = store.fetchPracticeHistory()
        #expect(history.recentTransferResults.first?.id == result.id)
    }

    // MARK: - Passive slices and progress

    @Test func transferProgressCountsCompatibleSlicesByLayoutAndDevice() {
        let store = makeStore()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)
        let ticket = makeTicket(
            status: .pending,
            keyboardLayoutID: "us",
            keyboardDeviceClass: "device-1",
            earliestEligibleAt: baseTime
        )
        store.upsertTransferTicket(ticket)

        store.appendPassiveSlices([
            makeSlice(startedAt: baseTime.addingTimeInterval(60), layout: "us", device: "device-1"),
            makeSlice(startedAt: baseTime.addingTimeInterval(120), layout: "us", device: "device-1"),
            makeSlice(startedAt: baseTime.addingTimeInterval(180), layout: "fr", device: "device-1")
        ])

        let progress = store.transferProgress(for: ticket)
        #expect(progress.compatibleSliceCount == 2)
        #expect(progress.incompatibleSliceCount == 1)
    }

    // MARK: - Learner state overlay

    @Test func appliedLearnerStateUpdatesAccumulateInOverlay() {
        let store = makeStore()
        store.appendLearnerStateUpdate(makeUpdate(skillID: "sameHandShortControl", control: 0.05, automaticity: 0.04, applied: true))
        store.appendLearnerStateUpdate(makeUpdate(skillID: "sameHandShortControl", consistency: 0.06, applied: true))
        store.appendLearnerStateUpdate(makeUpdate(skillID: "sameHandShortControl", control: 1, applied: false))

        let overlay = store.appliedStateOverlay()
        #expect(abs((overlay["sameHandShortControl"]?.control ?? 0) - 0.05) < 0.0001)
        #expect(abs((overlay["sameHandShortControl"]?.consistency ?? 0) - 0.06) < 0.0001)
        #expect(abs((overlay["sameHandShortControl"]?.automaticity ?? 0) - 0.04) < 0.0001)
    }

    // MARK: - Migration / persistence

    @Test func reopeningStoreAtSameURLPreservesData() {
        let url = tempDirectory.appendingPathComponent("evidence.sqlite3")
        let first = PracticeEvidenceStore(storeURL: url)
        first.appendPracticeSession(makeSession())

        let second = PracticeEvidenceStore(storeURL: url)
        let history = second.fetchPracticeHistory()
        #expect(history.recentSessions.count == 1)
    }

    // MARK: - Helpers

    private func makeStore() -> PracticeEvidenceStore {
        let url = tempDirectory.appendingPathComponent("\(UUID().uuidString)-evidence.sqlite3")
        return PracticeEvidenceStore(storeURL: url)
    }

    private func makeStamp(id: String) -> ModelVersionStamp {
        ModelVersionStamp(
            id: id,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            appBuild: "0.1.0",
            passiveFeatureVersion: 1,
            practiceScorerVersion: 1,
            skillGraphVersion: 1,
            assessmentBlueprintVersion: 1,
            immediateEvaluatorVersion: 1,
            passiveTransferEvaluatorVersion: 1,
            learnerUpdatePolicyVersion: 1,
            keyboardMapVersion: 1
        )
    }

    private func makeSession(endedAt: Date = Date()) -> PracticeSessionSummaryRecord {
        PracticeSessionSummaryRecord(
            startedAt: endedAt.addingTimeInterval(-300),
            endedAt: endedAt,
            selectedSkillID: "sameHandShortControl",
            selectedWeakness: .sameHandSequences,
            recommendationDecisionID: UUID(),
            modelVersionStampID: "stamp-1",
            targetConfirmationStatus: .confirmed,
            immediateOutcome: .improvedWeak,
            nearTransferOutcome: .flat,
            passiveTransferTicketID: nil,
            updateMode: .shadow,
            keyboardLayoutID: "us",
            keyboardDeviceClass: "device-1",
            blockSummaries: []
        )
    }

    private func makeTicket(
        status: PassiveTransferTicketStatus,
        keyboardLayoutID: String = "us",
        keyboardDeviceClass: String = "device-1",
        earliestEligibleAt: Date = Date()
    ) -> PassiveTransferTicketRecord {
        PassiveTransferTicketRecord(
            sessionID: UUID(),
            skillID: "sameHandShortControl",
            weakness: .sameHandSequences,
            createdAt: earliestEligibleAt,
            keyboardLayoutID: keyboardLayoutID,
            keyboardDeviceClass: keyboardDeviceClass,
            baselineSliceIDs: [UUID()],
            baselineMetricSnapshot: ["flightMedianMs::sameHand": 200],
            earliestEligibleAt: earliestEligibleAt,
            expiresAt: earliestEligibleAt.addingTimeInterval(7 * 24 * 60 * 60),
            requiredPostSliceCount: 2,
            requiredSampleCounts: ["flightMedianMs::sameHand": 30],
            status: status
        )
    }

    private func makeSlice(startedAt: Date, layout: String, device: String) -> PassiveActiveSliceRecord {
        PassiveActiveSliceRecord(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(60),
            activeTypingMilliseconds: 60_000,
            totalKeyDowns: 100,
            keyboardLayoutID: layout,
            keyboardDeviceClass: device,
            modelVersionStampID: "stamp-1",
            summary: TypingProfileSummary()
        )
    }

    private func makeUpdate(
        skillID: String,
        control: Double = 0,
        consistency: Double = 0,
        automaticity: Double = 0,
        stability: Double = 0,
        applied: Bool
    ) -> LearnerStateUpdateRecord {
        LearnerStateUpdateRecord(
            createdAt: Date(),
            skillID: skillID,
            sourceType: applied ? .passiveTransfer : .sessionImmediate,
            sourceSessionID: nil,
            sourceEvaluationID: nil,
            deltaControl: control,
            deltaConsistency: consistency,
            deltaAutomaticity: automaticity,
            deltaStability: stability,
            evidenceWeight: 1,
            reasonCodes: [],
            policyVersion: 1,
            appliedToRecommendations: applied
        )
    }
}
