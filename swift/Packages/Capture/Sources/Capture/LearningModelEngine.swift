import Core
import Foundation

enum SkillGraphCatalog {
    enum ID {
        static let sameHandShort = "sameHandShortControl"
        static let sameHandMedium = "sameHandMediumControl"
        static let sameHandLong = "sameHandLongControl"
        static let crossHandHandoff = "crossHandHandoff"
        static let farReachPrecision = "farReachPrecision"
        static let correctionRecovery = "correctionRecovery"
        static let burstRestartControl = "burstRestartControl"
        static let rhythmConsistency = "rhythmConsistency"

        static let handCoordination = "handCoordination"
        static let reachPrecision = "reachPrecision"
        static let repairEfficiency = "repairEfficiency"
        static let flowFluency = "flowFluency"
        static let rhythmStability = "rhythmStability"

        static let sustainableAccuracy = "sustainableAccuracy"
        static let sustainableFluency = "sustainableFluency"
        static let transferQuality = "transferQuality"
    }

    static let nodes: [SkillNode] = [
        SkillNode(id: ID.sameHandShort, name: "Same-hand short control", family: .coordination, level: .leaf, stage: .foundation, detail: "Short same-hand transitions without losing smoothness or correction control."),
        SkillNode(id: ID.sameHandMedium, name: "Same-hand medium control", family: .coordination, level: .leaf, stage: .foundation, detail: "Medium-distance same-hand transitions that often expose rollover friction."),
        SkillNode(id: ID.sameHandLong, name: "Same-hand long control", family: .coordination, level: .leaf, stage: .fluent, detail: "Longer same-hand transitions that demand stronger preparation and accuracy."),
        SkillNode(id: ID.crossHandHandoff, name: "Cross-hand handoff", family: .coordination, level: .leaf, stage: .foundation, detail: "Alternating hand transitions that should feel smoother than same-hand sequences."),
        SkillNode(id: ID.farReachPrecision, name: "Far reach execution", family: .reach, level: .leaf, stage: .foundation, detail: "Outer-zone and longer-distance movement execution."),
        SkillNode(id: ID.correctionRecovery, name: "Correction recovery", family: .repair, level: .leaf, stage: .foundation, detail: "How quickly the typist recovers after corrections and restarts forward typing."),
        SkillNode(id: ID.burstRestartControl, name: "Burst restart control", family: .flow, level: .leaf, stage: .foundation, detail: "How quickly and cleanly the typist restarts after pauses inside a session."),
        SkillNode(id: ID.rhythmConsistency, name: "Rhythm consistency", family: .rhythm, level: .leaf, stage: .foundation, detail: "How stable the timing cadence feels inside normal typing bursts."),

        SkillNode(id: ID.handCoordination, name: "Hand coordination", family: .coordination, level: .aggregate, stage: .fluent, detail: "Aggregate coordination across same-hand and cross-hand transitions."),
        SkillNode(id: ID.reachPrecision, name: "Reach execution", family: .reach, level: .aggregate, stage: .fluent, detail: "Aggregate execution for larger or more awkward keyboard travel."),
        SkillNode(id: ID.repairEfficiency, name: "Repair efficiency", family: .repair, level: .aggregate, stage: .fluent, detail: "Aggregate skill for handling mistakes without losing too much time or flow."),
        SkillNode(id: ID.flowFluency, name: "Flow fluency", family: .flow, level: .aggregate, stage: .fluent, detail: "Aggregate fluency across pauses, bursts, and restarts."),
        SkillNode(id: ID.rhythmStability, name: "Rhythm stability", family: .rhythm, level: .aggregate, stage: .fluent, detail: "Aggregate stability of timing across core typing behavior."),

        SkillNode(id: ID.sustainableAccuracy, name: "Sustainable accuracy", family: .outcome, level: .outcome, stage: .automatic, detail: "Whether accuracy remains strong without excessive repair cost."),
        SkillNode(id: ID.sustainableFluency, name: "Sustainable fluency", family: .outcome, level: .outcome, stage: .automatic, detail: "Whether speed and flow hold up cleanly across longer sessions."),
        SkillNode(id: ID.transferQuality, name: "Transfer quality", family: .outcome, level: .outcome, stage: .automatic, detail: "Whether gains from focused drills show up again in normal typing."),
    ]

    static let edges: [SkillEdge] = [
        SkillEdge(fromSkillID: ID.sameHandShort, toSkillID: ID.handCoordination, type: .partOf, weight: 1.0, note: "Short same-hand control is one component of broader hand coordination."),
        SkillEdge(fromSkillID: ID.sameHandMedium, toSkillID: ID.handCoordination, type: .partOf, weight: 1.0, note: "Medium same-hand control strongly influences coordination quality."),
        SkillEdge(fromSkillID: ID.sameHandLong, toSkillID: ID.handCoordination, type: .partOf, weight: 0.9, note: "Long same-hand travel is a harder coordination case."),
        SkillEdge(fromSkillID: ID.crossHandHandoff, toSkillID: ID.handCoordination, type: .partOf, weight: 1.0, note: "Cross-hand handoffs complete the coordination family."),
        SkillEdge(fromSkillID: ID.farReachPrecision, toSkillID: ID.reachPrecision, type: .partOf, weight: 1.0, note: "Far reach precision is the leaf skill for the reach family in the first M4 slice."),
        SkillEdge(fromSkillID: ID.correctionRecovery, toSkillID: ID.repairEfficiency, type: .partOf, weight: 1.0, note: "Correction recovery is the core repair skill for the first M4 slice."),
        SkillEdge(fromSkillID: ID.burstRestartControl, toSkillID: ID.flowFluency, type: .partOf, weight: 1.0, note: "Burst restarts are one part of flow fluency."),
        SkillEdge(fromSkillID: ID.rhythmConsistency, toSkillID: ID.rhythmStability, type: .partOf, weight: 1.0, note: "Rhythm consistency rolls up into rhythm stability."),
        SkillEdge(fromSkillID: ID.handCoordination, toSkillID: ID.sustainableFluency, type: .positiveTransfer, weight: 0.8, note: "Better hand coordination generally supports better sustained fluency."),
        SkillEdge(fromSkillID: ID.reachPrecision, toSkillID: ID.sustainableAccuracy, type: .positiveTransfer, weight: 0.75, note: "Better reach precision often lowers correction pressure and improves accuracy."),
        SkillEdge(fromSkillID: ID.repairEfficiency, toSkillID: ID.sustainableAccuracy, type: .partOf, weight: 1.0, note: "Repair efficiency is a direct part of sustainable accuracy."),
        SkillEdge(fromSkillID: ID.flowFluency, toSkillID: ID.sustainableFluency, type: .partOf, weight: 1.0, note: "Flow fluency is a direct part of sustainable fluency."),
        SkillEdge(fromSkillID: ID.rhythmStability, toSkillID: ID.sustainableFluency, type: .positiveTransfer, weight: 0.8, note: "Stable rhythm generally supports sustained fluency."),
        SkillEdge(fromSkillID: ID.repairEfficiency, toSkillID: ID.flowFluency, type: .positiveTransfer, weight: 0.65, note: "Better repair behavior often supports smoother restarts and flow."),
        SkillEdge(fromSkillID: ID.handCoordination, toSkillID: ID.transferQuality, type: .observes, weight: 0.5, note: "Coordination changes often show up in later passive transfer checks."),
        SkillEdge(fromSkillID: ID.repairEfficiency, toSkillID: ID.transferQuality, type: .observes, weight: 0.5, note: "Repair efficiency should transfer back into normal typing if drills help."),
    ]
}

enum LearningModelEngine {
    static func build(from snapshot: TypingProfileSnapshot) -> LearningModelSnapshot {
        let leafStates = buildLeafStates(from: snapshot)
        let aggregateStates = buildAggregateStates(from: leafStates)
        let outcomeStates = buildOutcomeStates(from: aggregateStates)
        let allStates = leafStates + aggregateStates + outcomeStates
        let weaknesses = detectWeaknesses(from: snapshot)
        let primaryWeakness = selectPrimaryWeakness(from: weaknesses)
        let sessionPlan = primaryWeakness.map { makePracticePlan(for: $0) }

        return LearningModelSnapshot(
            skillNodes: SkillGraphCatalog.nodes,
            skillEdges: SkillGraphCatalog.edges,
            studentStates: allStates,
            weaknesses: weaknesses,
            primaryWeakness: primaryWeakness,
            recommendedSession: sessionPlan
        )
    }

    static func manualPracticeRecommendation(for family: PracticeDrillFamily) -> (WeaknessAssessment, PracticeSessionPlan) {
        let weakness = manualWeakness(for: family)
        return (weakness, makePracticePlan(for: weakness))
    }

    static func recommendedSession(for weakness: WeaknessAssessment) -> PracticeSessionPlan {
        makePracticePlan(for: weakness)
    }

    private static func buildLeafStates(from snapshot: TypingProfileSnapshot) -> [StudentSkillState] {
        let today = snapshot.today
        let baseline = snapshot.baseline
        let baselineDays = snapshot.baselineDayCount

        let sameHand = today.flightStats(for: .sameHand)
        let crossHand = today.flightStats(for: .crossHand)
        let near = today.flightStats(for: .near)
        let far = today.flightStats(for: .far)
        let correctionEvidence = max(today.preCorrectionStats.sampleCount, today.recoveryStats.sampleCount)

        let sameToCrossRatio = ratio(today: sameHand.p50Milliseconds, reference: crossHand.p50Milliseconds)
        let crossToSameRatio = ratio(today: crossHand.p50Milliseconds, reference: sameHand.p50Milliseconds)
        let farToNearRatio = ratio(today: far.p50Milliseconds, reference: near.p50Milliseconds)
        let backspaceRatio = ratio(today: max(today.backspaceDensity, 0.0001), reference: max(baseline.backspaceDensity, 0.04))
        let burstRatio = inverseRatio(today: max(today.averageBurstLength, 0.1), reference: max(baseline.averageBurstLength, 20))
        let flightTailRatio = ratio(today: today.flightStats.p90Milliseconds, reference: baseline.flightStats.p90Milliseconds ?? today.flightStats.p90Milliseconds)
        let correctionRecoveryRatio = ratio(today: today.recoveryStats.p50Milliseconds, reference: baseline.recoveryStats.p50Milliseconds ?? 350)

        return [
            StudentSkillState(
                id: SkillGraphCatalog.ID.sameHandShort,
                title: "Same-hand short control",
                current: SkillDimensionState(
                    control: scoreLowerIsBetter(backspaceRatio, good: 1.0, bad: 1.7),
                    automaticity: scoreLowerIsBetter(sameToCrossRatio, good: 1.0, bad: 1.35),
                    consistency: scoreLowerIsBetter(ratio(today: sameHand.iqrMilliseconds, reference: sameHand.p50Milliseconds), good: 0.5, bad: 1.1),
                    stability: stabilityScore(baselineDays: baselineDays, todayValue: sameHand.p50Milliseconds, baselineValue: baseline.flightStats(for: .sameHand).p50Milliseconds)
                ),
                target: .init(control: 0.9, automaticity: 0.9, consistency: 0.85, stability: 0.8),
                confidence: confidenceFor(evidenceCount: min(sameHand.sampleCount, crossHand.sampleCount), baselineDays: baselineDays),
                evidenceCount: min(sameHand.sampleCount, crossHand.sampleCount),
                note: "Uses same-hand vs cross-hand timing as a proxy for rollover friction."
            ),
            StudentSkillState(
                id: SkillGraphCatalog.ID.sameHandMedium,
                title: "Same-hand medium control",
                current: SkillDimensionState(
                    control: scoreLowerIsBetter(backspaceRatio, good: 1.0, bad: 1.8),
                    automaticity: scoreLowerIsBetter(sameToCrossRatio * farToNearRatio, good: 1.0, bad: 1.45),
                    consistency: scoreLowerIsBetter(ratio(today: sameHand.p90Milliseconds, reference: sameHand.p50Milliseconds), good: 1.15, bad: 1.8),
                    stability: stabilityScore(baselineDays: baselineDays, todayValue: sameHand.p90Milliseconds, baselineValue: baseline.flightStats(for: .sameHand).p90Milliseconds)
                ),
                target: .init(control: 0.9, automaticity: 0.85, consistency: 0.85, stability: 0.8),
                confidence: confidenceFor(evidenceCount: min(sameHand.sampleCount, crossHand.sampleCount), baselineDays: baselineDays),
                evidenceCount: min(sameHand.sampleCount, crossHand.sampleCount),
                note: "Combines same-hand timing with reach burden to approximate medium same-hand difficulty."
            ),
            StudentSkillState(
                id: SkillGraphCatalog.ID.sameHandLong,
                title: "Same-hand long control",
                current: SkillDimensionState(
                    control: scoreLowerIsBetter(backspaceRatio, good: 1.0, bad: 1.9),
                    automaticity: scoreLowerIsBetter(farToNearRatio, good: 1.0, bad: 1.45),
                    consistency: scoreLowerIsBetter(ratio(today: far.iqrMilliseconds, reference: far.p50Milliseconds), good: 0.5, bad: 1.15),
                    stability: stabilityScore(baselineDays: baselineDays, todayValue: far.p50Milliseconds, baselineValue: baseline.flightStats(for: .far).p50Milliseconds)
                ),
                target: .init(control: 0.9, automaticity: 0.85, consistency: 0.85, stability: 0.8),
                confidence: confidenceFor(evidenceCount: min(far.sampleCount, near.sampleCount), baselineDays: baselineDays),
                evidenceCount: min(far.sampleCount, near.sampleCount),
                note: "Uses far-reach timing as the current proxy for longer same-hand travel difficulty."
            ),
            StudentSkillState(
                id: SkillGraphCatalog.ID.crossHandHandoff,
                title: "Cross-hand handoff",
                current: SkillDimensionState(
                    control: scoreLowerIsBetter(backspaceRatio, good: 1.0, bad: 1.7),
                    automaticity: scoreLowerIsBetter(crossToSameRatio, good: 1.0, bad: 1.25),
                    consistency: scoreLowerIsBetter(ratio(today: crossHand.p90Milliseconds, reference: crossHand.p50Milliseconds), good: 1.1, bad: 1.7),
                    stability: stabilityScore(baselineDays: baselineDays, todayValue: crossHand.p50Milliseconds, baselineValue: baseline.flightStats(for: .crossHand).p50Milliseconds)
                ),
                target: .init(control: 0.9, automaticity: 0.9, consistency: 0.85, stability: 0.8),
                confidence: confidenceFor(evidenceCount: min(sameHand.sampleCount, crossHand.sampleCount), baselineDays: baselineDays),
                evidenceCount: min(sameHand.sampleCount, crossHand.sampleCount),
                note: "Cross-hand sequences should generally retain some alternation advantage over same-hand sequences."
            ),
            StudentSkillState(
                id: SkillGraphCatalog.ID.farReachPrecision,
                title: "Far reach execution",
                current: SkillDimensionState(
                    control: scoreLowerIsBetter(backspaceRatio, good: 1.0, bad: 1.8),
                    automaticity: scoreLowerIsBetter(farToNearRatio, good: 1.0, bad: 1.4),
                    consistency: scoreLowerIsBetter(ratio(today: far.p90Milliseconds, reference: far.p50Milliseconds), good: 1.1, bad: 1.8),
                    stability: stabilityScore(baselineDays: baselineDays, todayValue: far.p90Milliseconds, baselineValue: baseline.flightStats(for: .far).p90Milliseconds)
                ),
                target: .init(control: 0.9, automaticity: 0.85, consistency: 0.85, stability: 0.8),
                confidence: confidenceFor(evidenceCount: min(far.sampleCount, near.sampleCount), baselineDays: baselineDays),
                evidenceCount: min(far.sampleCount, near.sampleCount),
                note: "Far vs near transitions estimate how expensive larger keyboard travel feels."
            ),
            StudentSkillState(
                id: SkillGraphCatalog.ID.correctionRecovery,
                title: "Correction recovery",
                current: SkillDimensionState(
                    control: scoreLowerIsBetter(backspaceRatio, good: 1.0, bad: 1.8),
                    automaticity: scoreLowerIsBetter(correctionRecoveryRatio, good: 1.0, bad: 1.4),
                    consistency: scoreLowerIsBetter(ratio(today: today.preCorrectionStats.p90Milliseconds, reference: today.preCorrectionStats.p50Milliseconds), good: 1.1, bad: 1.8),
                    stability: stabilityScore(baselineDays: baselineDays, todayValue: today.recoveryStats.p50Milliseconds, baselineValue: baseline.recoveryStats.p50Milliseconds)
                ),
                target: .init(control: 0.92, automaticity: 0.85, consistency: 0.85, stability: 0.8),
                confidence: confidenceFor(evidenceCount: correctionEvidence, baselineDays: baselineDays),
                evidenceCount: correctionEvidence,
                note: "Recovery tracks how much typing momentum is lost when errors happen."
            ),
            StudentSkillState(
                id: SkillGraphCatalog.ID.burstRestartControl,
                title: "Burst restart control",
                current: SkillDimensionState(
                    control: scoreHigherIsBetter(today.averageBurstLength, good: max(baseline.averageBurstLength, 18), bad: 8),
                    automaticity: scoreLowerIsBetter(ratio(today: today.pauseStats.p50Milliseconds, reference: baseline.pauseStats.p50Milliseconds ?? 750), good: 1.0, bad: 1.5),
                    consistency: scoreLowerIsBetter(burstRatio, good: 1.0, bad: 1.35),
                    stability: stabilityScore(baselineDays: baselineDays, todayValue: today.averageBurstLength, baselineValue: baseline.averageBurstLength)
                ),
                target: .init(control: 0.85, automaticity: 0.8, consistency: 0.8, stability: 0.75),
                confidence: confidenceFor(evidenceCount: today.burstCount, baselineDays: baselineDays),
                evidenceCount: today.burstCount,
                note: "Restart control tracks how cleanly a typist re-enters forward motion after a pause."
            ),
            StudentSkillState(
                id: SkillGraphCatalog.ID.rhythmConsistency,
                title: "Rhythm consistency",
                current: SkillDimensionState(
                    control: scoreLowerIsBetter(backspaceRatio, good: 1.0, bad: 1.6),
                    automaticity: scoreLowerIsBetter(ratio(today: today.flightStats.p50Milliseconds, reference: baseline.flightStats.p50Milliseconds ?? today.flightStats.p50Milliseconds), good: 1.0, bad: 1.3),
                    consistency: scoreLowerIsBetter(ratio(today: today.flightStats.iqrMilliseconds, reference: baseline.flightStats.iqrMilliseconds ?? today.flightStats.iqrMilliseconds), good: 1.0, bad: 1.35),
                    stability: scoreLowerIsBetter(flightTailRatio, good: 1.0, bad: 1.25)
                ),
                target: .init(control: 0.85, automaticity: 0.85, consistency: 0.85, stability: 0.8),
                confidence: confidenceFor(evidenceCount: today.flightStats.sampleCount, baselineDays: baselineDays),
                evidenceCount: today.flightStats.sampleCount,
                note: "Rhythm consistency tracks whether timing stays stable inside normal bursts."
            )
        ]
    }

    private static func buildAggregateStates(from leafStates: [StudentSkillState]) -> [StudentSkillState] {
        [
            aggregateState(
                id: SkillGraphCatalog.ID.handCoordination,
                title: "Hand coordination",
                leafStates: leafStates,
                memberIDs: [SkillGraphCatalog.ID.sameHandShort, SkillGraphCatalog.ID.sameHandMedium, SkillGraphCatalog.ID.sameHandLong, SkillGraphCatalog.ID.crossHandHandoff],
                note: "Rolls up same-hand and cross-hand coordination skills."
            ),
            aggregateState(
                id: SkillGraphCatalog.ID.reachPrecision,
                title: "Reach execution",
                leafStates: leafStates,
                memberIDs: [SkillGraphCatalog.ID.farReachPrecision],
                note: "Rolls up outer-zone and larger-travel control."
            ),
            aggregateState(
                id: SkillGraphCatalog.ID.repairEfficiency,
                title: "Repair efficiency",
                leafStates: leafStates,
                memberIDs: [SkillGraphCatalog.ID.correctionRecovery],
                note: "Rolls up repair and correction recovery quality."
            ),
            aggregateState(
                id: SkillGraphCatalog.ID.flowFluency,
                title: "Flow fluency",
                leafStates: leafStates,
                memberIDs: [SkillGraphCatalog.ID.burstRestartControl],
                note: "Rolls up how smoothly pauses and restarts are handled."
            ),
            aggregateState(
                id: SkillGraphCatalog.ID.rhythmStability,
                title: "Rhythm stability",
                leafStates: leafStates,
                memberIDs: [SkillGraphCatalog.ID.rhythmConsistency],
                note: "Rolls up core rhythm stability."
            )
        ]
    }

    private static func buildOutcomeStates(from aggregateStates: [StudentSkillState]) -> [StudentSkillState] {
        [
            aggregateState(
                id: SkillGraphCatalog.ID.sustainableAccuracy,
                title: "Sustainable accuracy",
                leafStates: aggregateStates,
                memberIDs: [SkillGraphCatalog.ID.repairEfficiency, SkillGraphCatalog.ID.reachPrecision],
                note: "Outcome state based on repair and reach quality."
            ),
            aggregateState(
                id: SkillGraphCatalog.ID.sustainableFluency,
                title: "Sustainable fluency",
                leafStates: aggregateStates,
                memberIDs: [SkillGraphCatalog.ID.handCoordination, SkillGraphCatalog.ID.flowFluency, SkillGraphCatalog.ID.rhythmStability],
                note: "Outcome state based on coordination, flow, and rhythm."
            ),
            aggregateState(
                id: SkillGraphCatalog.ID.transferQuality,
                title: "Transfer quality",
                leafStates: aggregateStates,
                memberIDs: [SkillGraphCatalog.ID.handCoordination, SkillGraphCatalog.ID.repairEfficiency],
                note: "Future-facing outcome state for whether practice gains transfer back into passive typing."
            )
        ]
    }

    private static func aggregateState(
        id: String,
        title: String,
        leafStates: [StudentSkillState],
        memberIDs: [String],
        note: String
    ) -> StudentSkillState {
        let members = leafStates.filter { memberIDs.contains($0.id) }
        guard !members.isEmpty else {
            return StudentSkillState(
                id: id,
                title: title,
                current: .init(control: 0, automaticity: 0, consistency: 0, stability: 0),
                target: .init(control: 0.9, automaticity: 0.9, consistency: 0.9, stability: 0.8),
                confidence: .low,
                evidenceCount: 0,
                note: note
            )
        }

        let dimension = SkillDimensionState(
            control: average(of: members.map { $0.current.control }),
            automaticity: average(of: members.map { $0.current.automaticity }),
            consistency: average(of: members.map { $0.current.consistency }),
            stability: average(of: members.map { $0.current.stability })
        )

        let confidence: WeaknessConfidence = members.map(\.confidence).contains(.high)
            ? .high
            : members.map(\.confidence).contains(.medium) ? .medium : .low

        return StudentSkillState(
            id: id,
            title: title,
            current: dimension,
            target: .init(control: 0.9, automaticity: 0.9, consistency: 0.85, stability: 0.8),
            confidence: confidence,
            evidenceCount: members.map(\.evidenceCount).reduce(0, +),
            note: note
        )
    }

    private static func detectWeaknesses(from snapshot: TypingProfileSnapshot) -> [WeaknessAssessment] {
        let today = snapshot.today
        let baseline = snapshot.baseline
        let baselineDays = snapshot.baselineDayCount

        var weaknesses: [WeaknessAssessment] = []

        let sameHand = today.flightStats(for: .sameHand)
        let crossHand = today.flightStats(for: .crossHand)
        let sameHandRatio = ratio(today: sameHand.p50Milliseconds, reference: crossHand.p50Milliseconds)
        if min(sameHand.sampleCount, crossHand.sampleCount) >= 40, sameHandRatio >= 1.18 {
            weaknesses.append(
                WeaknessAssessment(
                    category: .sameHandSequences,
                    title: "Same-hand sequences are slowing you down",
                    summary: "Same-hand transitions are meaningfully slower than matched cross-hand transitions.",
                    severity: severity(for: sameHandRatio, trigger: 1.18),
                    confidence: confidenceFor(evidenceCount: min(sameHand.sampleCount, crossHand.sampleCount), baselineDays: baselineDays),
                    lifecycleState: lifecycleState(for: min(sameHand.sampleCount, crossHand.sampleCount), baselineDays: baselineDays),
                    supportingSignals: [
                        signal("Same-hand p50", value: sameHand.p50Milliseconds),
                        signal("Cross-hand p50", value: crossHand.p50Milliseconds),
                        "ratio \(String(format: "%.2f", sameHandRatio))"
                    ],
                    targetSkillIDs: [SkillGraphCatalog.ID.sameHandShort, SkillGraphCatalog.ID.sameHandMedium],
                    recommendedDrill: .sameHandLadders,
                    rationale: "This usually points to rollover and hand-preparation friction more than pure reach cost."
                )
            )
        }

        let near = today.flightStats(for: .near)
        let far = today.flightStats(for: .far)
        let farRatio = ratio(today: far.p50Milliseconds, reference: near.p50Milliseconds)
        if min(near.sampleCount, far.sampleCount) >= 30, farRatio >= 1.22 {
            weaknesses.append(
                WeaknessAssessment(
                    category: .reachPrecision,
                    title: "Longer reach execution is your primary friction point",
                    summary: "Farther travel buckets are materially slower than near buckets.",
                    severity: severity(for: farRatio, trigger: 1.22),
                    confidence: confidenceFor(evidenceCount: min(near.sampleCount, far.sampleCount), baselineDays: baselineDays),
                    lifecycleState: lifecycleState(for: min(near.sampleCount, far.sampleCount), baselineDays: baselineDays),
                    supportingSignals: [
                        signal("Far p50", value: far.p50Milliseconds),
                        signal("Near p50", value: near.p50Milliseconds),
                        "ratio \(String(format: "%.2f", farRatio))"
                    ],
                    targetSkillIDs: [SkillGraphCatalog.ID.farReachPrecision],
                    recommendedDrill: .reachAndReturn,
                    rationale: "This pattern usually reflects outer-zone or longer-travel precision rather than general rhythm issues."
                )
            )
        }

        let baselineBackspaceReference = max(baseline.backspaceDensity, 0.04)
        let backspaceRatio = ratio(today: max(today.backspaceDensity, 0.0001), reference: baselineBackspaceReference)
        let preCorrectionRatio = ratio(today: today.preCorrectionStats.p50Milliseconds, reference: baseline.preCorrectionStats.p50Milliseconds ?? 260)
        let recoveryRatio = ratio(today: today.recoveryStats.p50Milliseconds, reference: baseline.recoveryStats.p50Milliseconds ?? 350)
        if today.includedKeyDownCount >= 200,
           today.backspaceDensity >= max(0.06, baselineBackspaceReference * 1.15),
           (preCorrectionRatio >= 1.12 || recoveryRatio >= 1.12 || today.heldDeleteBurstCount > baseline.heldDeleteBurstCount) {
            weaknesses.append(
                WeaknessAssessment(
                    category: .accuracyRecovery,
                    title: "Accuracy and recovery need attention",
                    summary: "Corrections are taking more time or happening more often than your baseline suggests they should.",
                    severity: severity(for: max(backspaceRatio, preCorrectionRatio, recoveryRatio), trigger: 1.12),
                    confidence: confidenceFor(evidenceCount: max(today.preCorrectionStats.sampleCount, today.recoveryStats.sampleCount, today.includedKeyDownCount / 10), baselineDays: baselineDays),
                    lifecycleState: lifecycleState(for: max(today.preCorrectionStats.sampleCount, today.recoveryStats.sampleCount, today.includedKeyDownCount / 10), baselineDays: baselineDays),
                    supportingSignals: [
                        "backspace density \(String(format: "%.1f%%", today.backspaceDensity * 100))",
                        signal("Pre-correction p50", value: today.preCorrectionStats.p50Milliseconds),
                        signal("Recovery p50", value: today.recoveryStats.p50Milliseconds),
                        "held delete bursts \(today.heldDeleteBurstCount)"
                    ],
                    targetSkillIDs: [SkillGraphCatalog.ID.correctionRecovery],
                    recommendedDrill: .accuracyReset,
                    rationale: "High correction burden should usually be handled before speed-first drills because it contaminates other timing signals."
                )
            )
        }

        let crossRatio = ratio(today: crossHand.p50Milliseconds, reference: sameHand.p50Milliseconds)
        if min(sameHand.sampleCount, crossHand.sampleCount) >= 40, crossRatio >= 1.08 {
            weaknesses.append(
                WeaknessAssessment(
                    category: .handHandoffs,
                    title: "Cross-hand handoffs are missing their usual advantage",
                    summary: "Cross-hand transitions are not outperforming same-hand transitions the way they usually should.",
                    severity: severity(for: crossRatio, trigger: 1.08),
                    confidence: confidenceFor(evidenceCount: min(sameHand.sampleCount, crossHand.sampleCount), baselineDays: baselineDays),
                    lifecycleState: lifecycleState(for: min(sameHand.sampleCount, crossHand.sampleCount), baselineDays: baselineDays),
                    supportingSignals: [
                        signal("Cross-hand p50", value: crossHand.p50Milliseconds),
                        signal("Same-hand p50", value: sameHand.p50Milliseconds),
                        "ratio \(String(format: "%.2f", crossRatio))"
                    ],
                    targetSkillIDs: [SkillGraphCatalog.ID.crossHandHandoff],
                    recommendedDrill: .alternationRails,
                    rationale: "This often means the alternation advantage is not showing up cleanly in current typing."
                )
            )
        }

        let burstRatio = inverseRatio(today: max(today.averageBurstLength, 0.1), reference: max(baseline.averageBurstLength, 20))
        let flightTailRatio = ratio(today: today.flightStats.iqrMilliseconds, reference: baseline.flightStats.iqrMilliseconds ?? today.flightStats.iqrMilliseconds)
        if today.burstCount >= 4,
           baselineDays >= 2,
           (burstRatio >= 1.15 || flightTailRatio >= 1.12) {
            weaknesses.append(
                WeaknessAssessment(
                    category: .flowConsistency,
                    title: "Typing flow is more fragmented than usual",
                    summary: "Burst length and rhythm spread suggest a more stop-start typing pattern than your baseline.",
                    severity: severity(for: max(burstRatio, flightTailRatio), trigger: 1.12),
                    confidence: confidenceFor(evidenceCount: today.burstCount, baselineDays: baselineDays),
                    lifecycleState: lifecycleState(for: today.burstCount, baselineDays: baselineDays),
                    supportingSignals: [
                        "avg burst \(String(format: "%.1f", today.averageBurstLength))",
                        signal("Flight IQR", value: today.flightStats.iqrMilliseconds),
                        signal("Pause p90", value: today.pauseStats.p90Milliseconds)
                    ],
                    targetSkillIDs: [SkillGraphCatalog.ID.burstRestartControl, SkillGraphCatalog.ID.rhythmConsistency],
                    recommendedDrill: .meteredFlow,
                    rationale: "This category is broader and more context-sensitive, so it should usually sit below the more specific motor weaknesses."
                )
            )
        }

        return weaknesses.sorted(by: weaknessPrioritySort)
    }

    private static func selectPrimaryWeakness(from weaknesses: [WeaknessAssessment]) -> WeaknessAssessment? {
        weaknesses.sorted(by: weaknessPrioritySort).first
    }

    private static func manualWeakness(for family: PracticeDrillFamily) -> WeaknessAssessment {
        switch family {
        case .sameHandLadders:
            return WeaknessAssessment(
                category: .sameHandSequences,
                title: "Manual tester override · Same-hand sequences",
                summary: "Run a controlled same-hand session even if passive evidence is not yet strong enough to recommend it automatically.",
                severity: .moderate,
                confidence: .low,
                lifecycleState: .monitoring,
                supportingSignals: ["manualOverride"],
                targetSkillIDs: [SkillGraphCatalog.ID.sameHandShort, SkillGraphCatalog.ID.sameHandMedium],
                recommendedDrill: .sameHandLadders,
                rationale: "Tester override for same-hand coordination and rollover friction."
            )
        case .reachAndReturn:
            return WeaknessAssessment(
                category: .reachPrecision,
                title: "Manual tester override · Reach execution",
                summary: "Run a controlled reach session even if passive evidence is not yet strong enough to recommend it automatically.",
                severity: .moderate,
                confidence: .low,
                lifecycleState: .monitoring,
                supportingSignals: ["manualOverride"],
                targetSkillIDs: [SkillGraphCatalog.ID.farReachPrecision],
                recommendedDrill: .reachAndReturn,
                rationale: "Tester override for longer reach execution."
            )
        case .alternationRails:
            return WeaknessAssessment(
                category: .handHandoffs,
                title: "Manual tester override · Hand handoffs",
                summary: "Run a controlled cross-hand handoff session even if passive evidence is not yet strong enough to recommend it automatically.",
                severity: .moderate,
                confidence: .low,
                lifecycleState: .monitoring,
                supportingSignals: ["manualOverride"],
                targetSkillIDs: [SkillGraphCatalog.ID.crossHandHandoff],
                recommendedDrill: .alternationRails,
                rationale: "Tester override for alternation and handoff timing."
            )
        case .accuracyReset:
            return WeaknessAssessment(
                category: .accuracyRecovery,
                title: "Manual tester override · Accuracy recovery",
                summary: "Run a controlled recovery-focused session even if passive evidence is not yet strong enough to recommend it automatically.",
                severity: .moderate,
                confidence: .low,
                lifecycleState: .monitoring,
                supportingSignals: ["manualOverride"],
                targetSkillIDs: [SkillGraphCatalog.ID.correctionRecovery],
                recommendedDrill: .accuracyReset,
                rationale: "Tester override for correction recovery and reset control."
            )
        case .meteredFlow:
            return WeaknessAssessment(
                category: .flowConsistency,
                title: "Manual tester override · Flow consistency",
                summary: "Run a controlled flow session even if passive evidence is not yet strong enough to recommend it automatically.",
                severity: .mild,
                confidence: .low,
                lifecycleState: .monitoring,
                supportingSignals: ["manualOverride"],
                targetSkillIDs: [SkillGraphCatalog.ID.burstRestartControl, SkillGraphCatalog.ID.rhythmConsistency],
                recommendedDrill: .meteredFlow,
                rationale: "Tester override for flow and cadence stability."
            )
        case .mixedTransfer:
            return WeaknessAssessment(
                category: .sameHandSequences,
                title: "Manual tester override · Mixed transfer",
                summary: "Run a mixed session for neutral tester coverage.",
                severity: .mild,
                confidence: .low,
                lifecycleState: .monitoring,
                supportingSignals: ["manualOverride"],
                targetSkillIDs: [SkillGraphCatalog.ID.sameHandShort],
                recommendedDrill: .mixedTransfer,
                rationale: "Tester override for neutral mixed transfer coverage."
            )
        }
    }

    private static func makePracticePlan(for weakness: WeaknessAssessment) -> PracticeSessionPlan {
        let drillCount = 2

        let confirmatoryProbe = PracticeBlock(
            kind: .confirmatoryProbe,
            title: "Confirmatory probe",
            detail: confirmatoryProbeDescription(for: weakness.category),
            durationSeconds: 25,
            drillFamily: nil,
            targetSkillIDs: weakness.targetSkillIDs
        )

        let drillBlocks = (0..<drillCount).map { index in
            PracticeBlock(
                kind: .drill,
                title: drillTitle(for: weakness.recommendedDrill, blockIndex: index),
                detail: drillDetail(for: weakness.recommendedDrill),
                durationSeconds: 55,
                drillFamily: weakness.recommendedDrill,
                targetSkillIDs: weakness.targetSkillIDs
            )
        }

        let postCheck = PracticeBlock(
            kind: .postCheck,
            title: "Immediate post-check",
            detail: "Run a short probe on the same abstract skill family to see whether the targeted ratio improved without increasing correction cost.",
            durationSeconds: 25,
            drillFamily: .mixedTransfer,
            targetSkillIDs: weakness.targetSkillIDs
        )

        let nearTransferCheck = PracticeBlock(
            kind: .nearTransferCheck,
            title: "Near-transfer check",
            detail: "Run a short adjacent-material check to see whether gains hold on similar but not identical prompt patterns.",
            durationSeconds: 25,
            drillFamily: .mixedTransfer,
            targetSkillIDs: weakness.targetSkillIDs
        )

        return PracticeSessionPlan(
            primaryFocusTitle: weakness.title,
            rationale: weakness.rationale,
            blocks: [confirmatoryProbe] + drillBlocks + [postCheck, nearTransferCheck],
            followUp: "Stay with one primary weakness at a time. If immediate checks improve but later passive transfer does not, keep the same drill family and lower the intensity before adding a second weakness.",
            passiveTransferNote: "Later passive typing should show at least a small improvement in the same abstract skill bucket before this weakness is treated as transferring."
        )
    }

    private static func confirmatoryProbeDescription(for category: WeaknessCategory) -> String {
        switch category {
        case .sameHandSequences:
            return "Run a short same-hand versus cross-hand contrast probe to confirm rollover and preparation friction before prescribing drills."
        case .reachPrecision:
            return "Run a short near-versus-far reach probe so the recommendation is anchored in travel distance rather than generic speed."
        case .accuracyRecovery:
            return "Run a short accuracy-first probe and check whether hesitation or restart lag is the bigger issue."
        case .handHandoffs:
            return "Run a short alternation probe to check whether cross-hand handoff timing is really missing its usual advantage."
        case .flowConsistency:
            return "Run a short cadence probe to see whether burst restarts and timing spread remain unstable inside guided pacing."
        }
    }

    private static func drillTitle(for family: PracticeDrillFamily, blockIndex: Int) -> String {
        let suffix = blockIndex + 1
        switch family {
        case .sameHandLadders:
            return "Same-Hand Ladders · Block \(suffix)"
        case .reachAndReturn:
            return "Reach & Return · Block \(suffix)"
        case .alternationRails:
            return "Alternation Rails · Block \(suffix)"
        case .accuracyReset:
            return "Accuracy Reset · Block \(suffix)"
        case .meteredFlow:
            return "Metered Flow · Block \(suffix)"
        case .mixedTransfer:
            return "Mixed Transfer · Block \(suffix)"
        }
    }

    private static func drillDetail(for family: PracticeDrillFamily) -> String {
        switch family {
        case .sameHandLadders:
            return "Use dense same-hand patterns first, then gradually contrast them against easier alternation patterns without chasing raw speed."
        case .reachAndReturn:
            return "Use home-zone to outer-zone travel and clean return patterns so far reaches improve without increasing repair cost."
        case .alternationRails:
            return "Use left-right handoff patterns that reinforce the alternation advantage before re-embedding them into mixed typing."
        case .accuracyReset:
            return "Use tempo-capped blocks with explicit accuracy goals so correction burden drops before speed pressure returns."
        case .meteredFlow:
            return "Use paced bursts and controlled restart timing to smooth out fragmentation without overfitting to speed alone."
        case .mixedTransfer:
            return "Use neutral mixed material that checks whether the targeted skill still holds outside the isolated drill context."
        }
    }

    private static func weaknessPrioritySort(_ lhs: WeaknessAssessment, _ rhs: WeaknessAssessment) -> Bool {
        let lhsPriority = priority(for: lhs.category)
        let rhsPriority = priority(for: rhs.category)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        let lhsConfidence = confidenceRank(lhs.confidence)
        let rhsConfidence = confidenceRank(rhs.confidence)
        if lhsConfidence != rhsConfidence {
            return lhsConfidence > rhsConfidence
        }

        return severityRank(lhs.severity) > severityRank(rhs.severity)
    }

    private static func priority(for category: WeaknessCategory) -> Int {
        switch category {
        case .accuracyRecovery:
            return 0
        case .reachPrecision:
            return 1
        case .sameHandSequences:
            return 2
        case .handHandoffs:
            return 3
        case .flowConsistency:
            return 4
        }
    }

    private static func severity(for ratio: Double, trigger: Double) -> WeaknessSeverity {
        if ratio >= trigger + 0.22 {
            return .strong
        }
        if ratio >= trigger + 0.1 {
            return .moderate
        }
        return .mild
    }

    private static func confidenceFor(evidenceCount: Int, baselineDays: Int) -> WeaknessConfidence {
        if evidenceCount >= 120 && baselineDays >= 3 {
            return .high
        }
        if evidenceCount >= 50 || baselineDays >= 2 {
            return .medium
        }
        return .low
    }

    private static func lifecycleState(for evidenceCount: Int, baselineDays: Int) -> WeaknessLifecycleState {
        if evidenceCount >= 120 && baselineDays >= 3 {
            return .confirmed
        }
        return .monitoring
    }

    private static func confidenceRank(_ confidence: WeaknessConfidence) -> Int {
        switch confidence {
        case .low:
            return 0
        case .medium:
            return 1
        case .high:
            return 2
        }
    }

    private static func severityRank(_ severity: WeaknessSeverity) -> Int {
        switch severity {
        case .mild:
            return 0
        case .moderate:
            return 1
        case .strong:
            return 2
        }
    }

    private static func ratio(today: Double?, reference: Double?) -> Double {
        guard let today, let reference, reference > 0 else { return 1.0 }
        return today / reference
    }

    private static func inverseRatio(today: Double, reference: Double) -> Double {
        guard today > 0 else { return 1.0 }
        return reference / today
    }

    private static func scoreLowerIsBetter(_ ratio: Double, good: Double, bad: Double) -> Double {
        guard bad > good else { return 0.5 }
        if ratio <= good { return 1.0 }
        if ratio >= bad { return 0.0 }
        return 1.0 - ((ratio - good) / (bad - good))
    }

    private static func scoreHigherIsBetter(_ value: Double, good: Double, bad: Double) -> Double {
        guard good > bad else { return 0.5 }
        if value >= good { return 1.0 }
        if value <= bad { return 0.0 }
        return (value - bad) / (good - bad)
    }

    private static func stabilityScore(
        baselineDays: Int,
        todayValue: Double?,
        baselineValue: Double?
    ) -> Double {
        guard baselineDays > 0, let todayValue, let baselineValue, baselineValue > 0 else {
            return baselineDays > 0 ? 0.45 : 0.25
        }

        let driftRatio = max(todayValue, baselineValue) / min(todayValue, baselineValue)
        let closeness = scoreLowerIsBetter(driftRatio, good: 1.0, bad: 1.3)
        let baselineFactor = min(Double(baselineDays) / 7.0, 1.0)
        return (closeness * 0.7) + (baselineFactor * 0.3)
    }

    private static func signal(_ title: String, value: Double?) -> String {
        guard let value else { return "\(title): n/a" }
        return "\(title): \(String(format: "%.0f ms", value))"
    }

    private static func average(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
