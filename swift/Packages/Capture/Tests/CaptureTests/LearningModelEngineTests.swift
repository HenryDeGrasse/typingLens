import Foundation
import Testing
@testable import Capture
@testable import Core

@Suite("LearningModelEngine")
struct LearningModelEngineTests {

    // MARK: - Catalog

    @Test func skillGraphAlwaysIncludesEightLeafSkills() {
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot())
        let leafCount = snapshot.skillNodes.filter { $0.level == .leaf }.count
        #expect(leafCount == 8)
    }

    @Test func skillGraphIncludesFiveAggregateAndThreeOutcomeSkills() {
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot())
        let aggregate = snapshot.skillNodes.filter { $0.level == .aggregate }.count
        let outcome = snapshot.skillNodes.filter { $0.level == .outcome }.count
        #expect(aggregate == 5)
        #expect(outcome == 3)
    }

    @Test func edgesReferenceOnlyKnownSkillNodes() {
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot())
        let nodeIDs = Set(snapshot.skillNodes.map(\.id))
        for edge in snapshot.skillEdges {
            #expect(nodeIDs.contains(edge.fromSkillID), "Edge references unknown from-node: \(edge.fromSkillID)")
            #expect(nodeIDs.contains(edge.toSkillID), "Edge references unknown to-node: \(edge.toSkillID)")
        }
    }

    // MARK: - Empty profile

    @Test func emptyProfileDetectsNoWeaknesses() {
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot())
        #expect(snapshot.weaknesses.isEmpty)
        #expect(snapshot.primaryWeakness == nil)
        #expect(snapshot.recommendedSession == nil)
    }

    // MARK: - Same-hand sequences weakness

    @Test func sameHandWeaknessDetectedWhenRatioExceedsThreshold() {
        let profile = profile(
            sameHandFlightMs: 220, sameHandSamples: 60,
            crossHandFlightMs: 160, crossHandSamples: 60
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile))
        #expect(snapshot.weaknesses.contains(where: { $0.category == .sameHandSequences }))
    }

    @Test func sameHandWeaknessSuppressedWhenSampleCountTooLow() {
        let profile = profile(
            sameHandFlightMs: 220, sameHandSamples: 10,
            crossHandFlightMs: 160, crossHandSamples: 10
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile))
        #expect(!snapshot.weaknesses.contains(where: { $0.category == .sameHandSequences }))
    }

    @Test func sameHandWeaknessSuppressedWhenRatioBelowThreshold() {
        // Both values land in the same histogram bucket (160–200), so ratio is 1.0.
        let profile = profile(
            sameHandFlightMs: 165, sameHandSamples: 80,
            crossHandFlightMs: 165, crossHandSamples: 80
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile))
        #expect(!snapshot.weaknesses.contains(where: { $0.category == .sameHandSequences }))
    }

    @Test func strongerRatioYieldsHigherSeverity() throws {
        // Mild: 220 → bucket midpoint 225, 170 → midpoint 180, ratio ≈ 1.25 (above 1.18 trigger, below 1.28 moderate).
        let mild = profile(
            sameHandFlightMs: 220, sameHandSamples: 80,
            crossHandFlightMs: 170, crossHandSamples: 80
        )
        // Strong: 320 → midpoint 285, 150 → midpoint 145, ratio ≈ 1.97 (above strong threshold 1.40).
        let strong = profile(
            sameHandFlightMs: 320, sameHandSamples: 80,
            crossHandFlightMs: 150, crossHandSamples: 80
        )

        let mildWeakness = try #require(LearningModelEngine.build(from: TypingProfileSnapshot(today: mild))
            .weaknesses.first(where: { $0.category == .sameHandSequences }))
        let strongWeakness = try #require(LearningModelEngine.build(from: TypingProfileSnapshot(today: strong))
            .weaknesses.first(where: { $0.category == .sameHandSequences }))

        #expect(severityRank(strongWeakness.severity) > severityRank(mildWeakness.severity))
    }

    // MARK: - Reach precision weakness

    @Test func reachPrecisionWeaknessDetectedWhenFarMuchSlowerThanNear() {
        let profile = profile(
            nearFlightMs: 130, nearSamples: 40,
            farFlightMs: 220, farSamples: 40
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile))
        #expect(snapshot.weaknesses.contains(where: { $0.category == .reachPrecision }))
    }

    // MARK: - Accuracy & recovery weakness

    @Test func accuracyRecoveryRequiresKeyVolumeAndElevatedBackspaceDensity() {
        var summary = TypingProfileSummary()
        summary.includedKeyDownCount = 400
        summary.backspaceCount = 36
        for _ in 0..<40 { summary.recoveryFlightHistogram.insert(800) }
        for _ in 0..<40 { summary.preCorrectionFlightHistogram.insert(400) }

        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: summary))
        #expect(snapshot.weaknesses.contains(where: { $0.category == .accuracyRecovery }))
    }

    @Test func accuracyRecoveryNotTriggeredAtVeryLowVolume() {
        var summary = TypingProfileSummary()
        summary.includedKeyDownCount = 50
        summary.backspaceCount = 10
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: summary))
        #expect(!snapshot.weaknesses.contains(where: { $0.category == .accuracyRecovery }))
    }

    // MARK: - Hand handoff weakness

    @Test func handHandoffWeaknessDetectedWhenCrossSlowerThanSame() {
        let profile = profile(
            sameHandFlightMs: 150, sameHandSamples: 60,
            crossHandFlightMs: 175, crossHandSamples: 60
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile))
        #expect(snapshot.weaknesses.contains(where: { $0.category == .handHandoffs }))
    }

    // MARK: - Priority sort

    @Test func accuracyRecoveryHasHigherPriorityThanReachWhenBothPresent() {
        var summary = TypingProfileSummary()
        summary.includedKeyDownCount = 400
        summary.backspaceCount = 40
        for _ in 0..<40 { summary.recoveryFlightHistogram.insert(800) }
        for _ in 0..<40 { summary.preCorrectionFlightHistogram.insert(400) }
        var nearHist = DistributionHistogram.timing()
        var farHist = DistributionHistogram.timing()
        for _ in 0..<40 { nearHist.insert(130) }
        for _ in 0..<40 { farHist.insert(220) }
        summary.flightByDistanceBucket[DistanceBucket.near.rawValue] = nearHist
        summary.flightByDistanceBucket[DistanceBucket.far.rawValue] = farHist

        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: summary))
        #expect(snapshot.primaryWeakness?.category == .accuracyRecovery)
    }

    // MARK: - Confidence

    @Test func confidenceIsLowWhenEvidenceIsThin() {
        let profile = profile(
            sameHandFlightMs: 220, sameHandSamples: 45,
            crossHandFlightMs: 160, crossHandSamples: 45
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile, baselineDayCount: 0))
        let weakness = snapshot.weaknesses.first(where: { $0.category == .sameHandSequences })
        #expect(weakness?.confidence == .low)
    }

    @Test func confidenceIsHighWithLargeEvidenceAndBaseline() {
        let profile = profile(
            sameHandFlightMs: 220, sameHandSamples: 200,
            crossHandFlightMs: 160, crossHandSamples: 200
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile, baselineDayCount: 5))
        let weakness = snapshot.weaknesses.first(where: { $0.category == .sameHandSequences })
        #expect(weakness?.confidence == .high)
    }

    // MARK: - Recommended session

    @Test func recommendedSessionMatchesPrimaryWeaknessFamily() {
        let profile = profile(
            sameHandFlightMs: 240, sameHandSamples: 80,
            crossHandFlightMs: 160, crossHandSamples: 80
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile))
        #expect(snapshot.primaryWeakness?.recommendedDrill == .sameHandLadders)
        #expect(snapshot.recommendedSession != nil)
        let drillBlock = snapshot.recommendedSession?.blocks.first(where: { $0.kind == .drill })
        #expect(drillBlock?.drillFamily == .sameHandLadders)
    }

    @Test func recommendedSessionIncludesProbeDrillsPostCheckAndTransfer() {
        let profile = profile(
            sameHandFlightMs: 240, sameHandSamples: 80,
            crossHandFlightMs: 160, crossHandSamples: 80
        )
        let snapshot = LearningModelEngine.build(from: TypingProfileSnapshot(today: profile))
        let kinds = snapshot.recommendedSession?.blocks.map(\.kind) ?? []
        #expect(kinds.contains(.confirmatoryProbe))
        #expect(kinds.contains(.drill))
        #expect(kinds.contains(.postCheck))
        #expect(kinds.contains(.nearTransferCheck))
    }

    // MARK: - Manual override

    @Test func manualPracticeRecommendationProducesMatchingFamily() {
        let (weakness, plan) = LearningModelEngine.manualPracticeRecommendation(for: .reachAndReturn)
        #expect(weakness.recommendedDrill == .reachAndReturn)
        #expect(weakness.category == .reachPrecision)
        #expect(weakness.supportingSignals.contains("manualOverride"))
        #expect(plan.blocks.contains(where: { $0.drillFamily == .reachAndReturn }))
    }

    @Test func manualMixedTransferStillProducesValidPlan() {
        let (weakness, plan) = LearningModelEngine.manualPracticeRecommendation(for: .mixedTransfer)
        #expect(weakness.recommendedDrill == .mixedTransfer)
        #expect(!plan.blocks.isEmpty)
    }

    // MARK: - Helpers

    private func profile(
        sameHandFlightMs: Double = 0, sameHandSamples: Int = 0,
        crossHandFlightMs: Double = 0, crossHandSamples: Int = 0,
        nearFlightMs: Double = 0, nearSamples: Int = 0,
        farFlightMs: Double = 0, farSamples: Int = 0
    ) -> TypingProfileSummary {
        var summary = TypingProfileSummary()
        if sameHandSamples > 0 {
            var hist = DistributionHistogram.timing()
            for _ in 0..<sameHandSamples { hist.insert(sameHandFlightMs) }
            summary.flightByHandPattern[HandTransitionPattern.sameHand.rawValue] = hist
        }
        if crossHandSamples > 0 {
            var hist = DistributionHistogram.timing()
            for _ in 0..<crossHandSamples { hist.insert(crossHandFlightMs) }
            summary.flightByHandPattern[HandTransitionPattern.crossHand.rawValue] = hist
        }
        if nearSamples > 0 {
            var hist = DistributionHistogram.timing()
            for _ in 0..<nearSamples { hist.insert(nearFlightMs) }
            summary.flightByDistanceBucket[DistanceBucket.near.rawValue] = hist
        }
        if farSamples > 0 {
            var hist = DistributionHistogram.timing()
            for _ in 0..<farSamples { hist.insert(farFlightMs) }
            summary.flightByDistanceBucket[DistanceBucket.far.rawValue] = hist
        }
        summary.includedKeyDownCount = max(sameHandSamples + crossHandSamples + nearSamples + farSamples, 100)
        return summary
    }

    private func severityRank(_ severity: WeaknessSeverity) -> Int {
        switch severity {
        case .mild: return 0
        case .moderate: return 1
        case .strong: return 2
        }
    }
}
