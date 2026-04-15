import Foundation
import Testing
@testable import Capture
@testable import Core

@Suite("PracticeEvaluationEngine")
struct PracticeEvaluationEngineTests {

    // MARK: - Immediate evaluation

    @Test func immediateImprovementProducesImprovedStrongWhenBigDelta() {
        let weakness = sameHandWeakness()
        let baseline = block(role: .confirmatoryProbe, sameHandFlightMs: 200, sampleCount: 12)
        let post = block(role: .postCheck, sameHandFlightMs: 160, sampleCount: 12)

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            blocks: [baseline, post]
        )

        #expect(result.targetConfirmationStatus == .confirmed)
        #expect(result.immediateOutcome == .improvedStrong)
    }

    @Test func immediateModestImprovementProducesImprovedWeak() {
        let weakness = sameHandWeakness()
        let baseline = block(role: .confirmatoryProbe, sameHandFlightMs: 200, sampleCount: 12)
        let post = block(role: .postCheck, sameHandFlightMs: 188, sampleCount: 12)

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            blocks: [baseline, post]
        )

        #expect(result.immediateOutcome == .improvedWeak)
    }

    @Test func insufficientSampleCountReturnsInsufficientData() {
        let weakness = sameHandWeakness()
        let baseline = block(role: .confirmatoryProbe, sameHandFlightMs: 200, sampleCount: 2)
        let post = block(role: .postCheck, sameHandFlightMs: 150, sampleCount: 2)

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            blocks: [baseline, post]
        )

        #expect(result.immediateOutcome == .insufficientData)
    }

    @Test func flatOutcomeWhenChangeIsTrivial() {
        let weakness = sameHandWeakness()
        let baseline = block(role: .confirmatoryProbe, sameHandFlightMs: 200, sampleCount: 12)
        let post = block(role: .postCheck, sameHandFlightMs: 198, sampleCount: 12)

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            blocks: [baseline, post]
        )
        #expect(result.immediateOutcome == .flat)
    }

    @Test func worseOutcomeWhenCandidateRegresses() {
        let weakness = sameHandWeakness()
        let baseline = block(role: .confirmatoryProbe, sameHandFlightMs: 200, sampleCount: 12)
        let post = block(role: .postCheck, sameHandFlightMs: 240, sampleCount: 12)

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            blocks: [baseline, post]
        )
        #expect(result.immediateOutcome == .worseStrong || result.immediateOutcome == .worseWeak)
    }

    // MARK: - Guard rails

    @Test func accuracyRegressionGuardDemotesImprovementToFlat() {
        let weakness = sameHandWeakness()
        let baseline = block(role: .confirmatoryProbe, sameHandFlightMs: 200, sampleCount: 12, incorrectRate: 0.01)
        let post = block(role: .postCheck, sameHandFlightMs: 150, sampleCount: 12, incorrectRate: 0.05)

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            blocks: [baseline, post]
        )
        #expect(result.immediateOutcome == .flat)
    }

    // MARK: - Specificity control

    @Test func warmupLikeImprovementDemotesStrongToWeak() {
        let weakness = sameHandWeakness()
        let baseline = block(
            role: .confirmatoryProbe,
            sameHandFlightMs: 200, crossHandFlightMs: 200,
            sampleCount: 12
        )
        let post = block(
            role: .postCheck,
            sameHandFlightMs: 160, crossHandFlightMs: 160,
            sampleCount: 12
        )

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            blocks: [baseline, post]
        )
        #expect(result.immediateOutcome == .improvedWeak)
    }

    // MARK: - Update creation policy

    @Test func flowConsistencyDoesNotProduceShadowUpdates() {
        let weakness = WeaknessAssessment(
            category: .flowConsistency,
            title: "Flow",
            summary: "",
            severity: .mild,
            confidence: .medium,
            lifecycleState: .monitoring,
            supportingSignals: [],
            targetSkillIDs: ["burstRestartControl"],
            recommendedDrill: .meteredFlow,
            rationale: ""
        )
        let baseline = block(role: .confirmatoryProbe, cadenceIQRMs: 60, sampleCount: 20, activeMs: 50_000)
        let post = block(role: .postCheck, cadenceIQRMs: 30, sampleCount: 20, activeMs: 50_000)

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "burstRestartControl",
            weakness: weakness,
            blocks: [baseline, post]
        )

        #expect(result.updates.isEmpty)
    }

    @Test func nonFlowImprovementProducesShadowUpdateWithDeltaControl() throws {
        let weakness = sameHandWeakness()
        let baseline = block(role: .confirmatoryProbe, sameHandFlightMs: 200, sampleCount: 12)
        let post = block(role: .postCheck, sameHandFlightMs: 150, sampleCount: 12)

        let result = PracticeEvaluationEngine.evaluateImmediateSession(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            blocks: [baseline, post]
        )

        let postUpdate = try #require(result.updates.first(where: { $0.sourceType == .sessionImmediate }))
        #expect(postUpdate.deltaControl > 0)
        #expect(!postUpdate.appliedToRecommendations, "Updates should default to shadow mode")
    }

    // MARK: - Transfer ticket creation

    @Test func transferTicketSuppressedForFlowConsistency() {
        let weakness = WeaknessAssessment(
            category: .flowConsistency,
            title: "", summary: "", severity: .mild,
            confidence: .medium, lifecycleState: .monitoring,
            supportingSignals: [], targetSkillIDs: ["x"],
            recommendedDrill: .meteredFlow, rationale: ""
        )

        let ticket = PracticeEvaluationEngine.makeTransferTicket(
            sessionID: UUID(),
            selectedSkillID: "x",
            weakness: weakness,
            sessionEndedAt: Date(),
            keyboardLayoutID: "us-qwerty",
            keyboardDeviceClass: "device-1",
            baselineSlices: [makeSlice(sameHandFlightMs: 200, samples: 50)]
        )

        #expect(ticket == nil)
    }

    @Test func transferTicketSuppressedWhenKeyboardLayoutUnknown() {
        let weakness = sameHandWeakness()
        let ticket = PracticeEvaluationEngine.makeTransferTicket(
            sessionID: UUID(),
            selectedSkillID: "x",
            weakness: weakness,
            sessionEndedAt: Date(),
            keyboardLayoutID: "unknown",
            keyboardDeviceClass: "device-1",
            baselineSlices: [makeSlice(sameHandFlightMs: 200, samples: 50)]
        )
        #expect(ticket == nil)
    }

    @Test func transferTicketSuppressedWhenBaselineSlicesEmpty() {
        let weakness = sameHandWeakness()
        let ticket = PracticeEvaluationEngine.makeTransferTicket(
            sessionID: UUID(),
            selectedSkillID: "x",
            weakness: weakness,
            sessionEndedAt: Date(),
            keyboardLayoutID: "us-qwerty",
            keyboardDeviceClass: "device-1",
            baselineSlices: []
        )
        #expect(ticket == nil)
    }

    @Test func transferTicketCreatedWithCooldownAndExpiry() throws {
        let weakness = sameHandWeakness()
        let endedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let ticket = try #require(PracticeEvaluationEngine.makeTransferTicket(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            sessionEndedAt: endedAt,
            keyboardLayoutID: "us-qwerty",
            keyboardDeviceClass: "device-1",
            baselineSlices: [makeSlice(sameHandFlightMs: 220, samples: 60)]
        ))

        #expect(ticket.status == .pending)
        #expect(ticket.earliestEligibleAt.timeIntervalSince(endedAt) == 60 * 60)
        #expect(ticket.expiresAt.timeIntervalSince(endedAt) == 7 * 24 * 60 * 60)
        #expect(ticket.requiredPostSliceCount == 2)
    }

    // MARK: - Passive transfer evaluation

    @Test func passiveTransferDeferredWhenPostSlicesInsufficient() throws {
        let weakness = sameHandWeakness()
        let ticket = try #require(PracticeEvaluationEngine.makeTransferTicket(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            sessionEndedAt: Date(),
            keyboardLayoutID: "us-qwerty",
            keyboardDeviceClass: "device-1",
            baselineSlices: [makeSlice(sameHandFlightMs: 220, samples: 50)]
        ))

        let outcome = PracticeEvaluationEngine.evaluatePassiveTransfer(
            ticket: ticket,
            postSlices: [makeSlice(sameHandFlightMs: 200, samples: 30)]
        )

        #expect(outcome == nil)
    }

    @Test func passiveTransferProducesImprovedOutcomeWhenPostBeatsBaseline() throws {
        let weakness = sameHandWeakness()
        let ticket = try #require(PracticeEvaluationEngine.makeTransferTicket(
            sessionID: UUID(),
            selectedSkillID: "sameHandShortControl",
            weakness: weakness,
            sessionEndedAt: Date(),
            keyboardLayoutID: "us-qwerty",
            keyboardDeviceClass: "device-1",
            baselineSlices: [makeSlice(sameHandFlightMs: 240, samples: 60)]
        ))

        let result = try #require(PracticeEvaluationEngine.evaluatePassiveTransfer(
            ticket: ticket,
            postSlices: [
                makeSlice(sameHandFlightMs: 180, samples: 40),
                makeSlice(sameHandFlightMs: 180, samples: 40)
            ]
        ))

        #expect(result.result.outcome == .improvedStrong || result.result.outcome == .improvedWeak)
        #expect(result.result.evidenceWeight > 0)
        #expect(result.update.deltaAutomaticity > 0)
    }

    // MARK: - Helpers

    private func sameHandWeakness() -> WeaknessAssessment {
        WeaknessAssessment(
            category: .sameHandSequences,
            title: "Same hand",
            summary: "",
            severity: .moderate,
            confidence: .medium,
            lifecycleState: .monitoring,
            supportingSignals: [],
            targetSkillIDs: ["sameHandShortControl"],
            recommendedDrill: .sameHandLadders,
            rationale: ""
        )
    }

    private func block(
        role: PracticeBlockKind,
        sameHandFlightMs: Double? = nil,
        crossHandFlightMs: Double? = nil,
        cadenceIQRMs: Double? = nil,
        sampleCount: Int,
        incorrectRate: Double = 0,
        activeMs: Int = 25_000
    ) -> PracticeBlockSummaryRecord {
        var metrics: [PracticeBlockMetricSnapshot] = []
        if let value = sameHandFlightMs {
            metrics.append(.init(metricKey: "flightMedianMs", cohortKey: "sameHand", sampleCount: sampleCount, scalarValue: value, betterDirection: .lowerIsBetter))
        }
        if let value = crossHandFlightMs {
            metrics.append(.init(metricKey: "flightMedianMs", cohortKey: "crossHand", sampleCount: sampleCount, scalarValue: value, betterDirection: .lowerIsBetter))
        }
        if let value = cadenceIQRMs {
            metrics.append(.init(metricKey: "cadenceIQRMs", cohortKey: "overall", sampleCount: sampleCount, scalarValue: value, betterDirection: .lowerIsBetter))
        }
        metrics.append(.init(metricKey: "incorrectRate", cohortKey: "overall", sampleCount: max(sampleCount, 1), scalarValue: incorrectRate, betterDirection: .lowerIsBetter))

        return PracticeBlockSummaryRecord(
            blockIndex: 0,
            title: "Block",
            role: role,
            skillID: "sameHandShortControl",
            weakness: .sameHandSequences,
            assessmentBlueprintDescriptor: "",
            durationMilliseconds: activeMs,
            activeTypingMilliseconds: activeMs,
            charsPresented: 0,
            charsEntered: 0,
            correctChars: 0,
            incorrectChars: 0,
            correctedErrorEpisodeCount: 4,
            uncorrectedErrorEpisodeCount: 0,
            backspaceTapCount: 0,
            heldDeleteEpisodeCount: 0,
            promptsCompleted: 0,
            sufficiencyStatus: .sufficient,
            metrics: metrics
        )
    }

    private func makeSlice(sameHandFlightMs: Double, samples: Int) -> PassiveActiveSliceRecord {
        var summary = TypingProfileSummary()
        var hist = DistributionHistogram.timing()
        for _ in 0..<samples { hist.insert(sameHandFlightMs) }
        summary.flightByHandPattern[HandTransitionPattern.sameHand.rawValue] = hist
        summary.includedKeyDownCount = samples
        return PassiveActiveSliceRecord(
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 2_000),
            activeTypingMilliseconds: 60_000,
            totalKeyDowns: samples,
            keyboardLayoutID: "us-qwerty",
            keyboardDeviceClass: "device-1",
            modelVersionStampID: "test",
            summary: summary
        )
    }
}
