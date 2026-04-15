import Core
import Foundation

enum PracticeEvaluationEngine {
    static let passiveFeatureVersion = 2
    static let practiceScorerVersion = 2
    static let skillGraphVersion = 1
    static let assessmentBlueprintVersion = 2
    static let immediateEvaluatorVersion = 1
    static let passiveTransferEvaluatorVersion = 1
    static let learnerUpdatePolicyVersion = 1
    static let keyboardMapVersion = 1

    static var currentModelVersionStamp: ModelVersionStamp {
        let appBuild = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let id = [
            "build:\(appBuild)",
            "passive:\(passiveFeatureVersion)",
            "practice:\(practiceScorerVersion)",
            "skill:\(skillGraphVersion)",
            "assess:\(assessmentBlueprintVersion)",
            "immediate:\(immediateEvaluatorVersion)",
            "transfer:\(passiveTransferEvaluatorVersion)",
            "update:\(learnerUpdatePolicyVersion)",
            "keymap:\(keyboardMapVersion)"
        ].joined(separator: "|")

        return ModelVersionStamp(
            id: id,
            createdAt: Date(),
            appBuild: appBuild,
            passiveFeatureVersion: passiveFeatureVersion,
            practiceScorerVersion: practiceScorerVersion,
            skillGraphVersion: skillGraphVersion,
            assessmentBlueprintVersion: assessmentBlueprintVersion,
            immediateEvaluatorVersion: immediateEvaluatorVersion,
            passiveTransferEvaluatorVersion: passiveTransferEvaluatorVersion,
            learnerUpdatePolicyVersion: learnerUpdatePolicyVersion,
            keyboardMapVersion: keyboardMapVersion
        )
    }

    static func evaluateImmediateSession(
        sessionID: UUID,
        selectedSkillID: String,
        weakness: WeaknessAssessment,
        blocks: [PracticeBlockSummaryRecord]
    ) -> (
        targetConfirmationStatus: TargetConfirmationStatus,
        evaluations: [ImmediateEvaluationRecord],
        immediateOutcome: PracticeEvaluationOutcome?,
        nearTransferOutcome: PracticeEvaluationOutcome?,
        updates: [LearnerStateUpdateRecord]
    ) {
        let confirmationBlock = blocks.first(where: { $0.role == .confirmatoryProbe })
        let postCheckBlock = blocks.first(where: { $0.role == .postCheck })
        let nearTransferBlock = blocks.first(where: { $0.role == .nearTransferCheck })

        let targetConfirmationStatus = targetConfirmationStatus(for: weakness, baseline: confirmationBlock)

        var evaluations: [ImmediateEvaluationRecord] = []
        var updates: [LearnerStateUpdateRecord] = []

        let postEvaluation: ImmediateEvaluationRecord? = {
            guard let confirmationBlock, let postCheckBlock else { return nil }
            return compare(
                sessionID: sessionID,
                evaluationType: .postCheck,
                skillID: selectedSkillID,
                weakness: weakness.category,
                baseline: confirmationBlock,
                candidate: postCheckBlock
            )
        }()

        if let postEvaluation, shouldCreateImmediateUpdate(for: weakness.category, targetConfirmationStatus: targetConfirmationStatus) {
            evaluations.append(postEvaluation)
            if weakness.category != .flowConsistency {
                updates.append(
                    makeUpdate(
                        skillID: selectedSkillID,
                        sourceType: .sessionImmediate,
                        sessionID: sessionID,
                        evaluationID: postEvaluation.id,
                        outcome: postEvaluation.outcome,
                        focus: .control,
                        applied: false
                    )
                )
            }
        } else if let postEvaluation {
            evaluations.append(postEvaluation)
        }

        let nearTransferEvaluation: ImmediateEvaluationRecord? = {
            guard let confirmationBlock, let nearTransferBlock else { return nil }
            return compare(
                sessionID: sessionID,
                evaluationType: .nearTransferCheck,
                skillID: selectedSkillID,
                weakness: weakness.category,
                baseline: confirmationBlock,
                candidate: nearTransferBlock
            )
        }()

        if let nearTransferEvaluation {
            evaluations.append(nearTransferEvaluation)
            if weakness.category != .flowConsistency,
               shouldCreateImmediateUpdate(for: weakness.category, targetConfirmationStatus: targetConfirmationStatus) {
                updates.append(
                    makeUpdate(
                        skillID: selectedSkillID,
                        sourceType: .nearTransfer,
                        sessionID: sessionID,
                        evaluationID: nearTransferEvaluation.id,
                        outcome: nearTransferEvaluation.outcome,
                        focus: .consistency,
                        applied: false
                    )
                )
            }
        }

        return (
            targetConfirmationStatus,
            evaluations,
            postEvaluation?.outcome,
            nearTransferEvaluation?.outcome,
            updates
        )
    }

    static func makeTransferTicket(
        sessionID: UUID,
        selectedSkillID: String,
        weakness: WeaknessAssessment,
        sessionEndedAt: Date,
        keyboardLayoutID: String,
        keyboardDeviceClass: String,
        baselineSlices: [PassiveActiveSliceRecord]
    ) -> PassiveTransferTicketRecord? {
        guard weakness.category != .flowConsistency,
              keyboardLayoutID != "unknown",
              keyboardDeviceClass != "unknown-device",
              !baselineSlices.isEmpty else {
            return nil
        }

        let mergedBaseline = merge(sliceRecords: baselineSlices)
        guard let primaryMetric = passivePrimaryMetric(for: weakness.category, summary: mergedBaseline) else {
            return nil
        }

        return PassiveTransferTicketRecord(
            sessionID: sessionID,
            skillID: selectedSkillID,
            weakness: weakness.category,
            createdAt: sessionEndedAt,
            keyboardLayoutID: keyboardLayoutID,
            keyboardDeviceClass: keyboardDeviceClass,
            baselineSliceIDs: baselineSlices.map(\.id),
            baselineMetricSnapshot: [primaryMetric.key: primaryMetric.value],
            earliestEligibleAt: sessionEndedAt.addingTimeInterval(60 * 60),
            expiresAt: sessionEndedAt.addingTimeInterval(7 * 24 * 60 * 60),
            requiredPostSliceCount: 2,
            requiredSampleCounts: [primaryMetric.key: minimumPassiveSampleCount(for: weakness.category)],
            status: .pending
        )
    }

    static func evaluatePassiveTransfer(
        ticket: PassiveTransferTicketRecord,
        postSlices: [PassiveActiveSliceRecord]
    ) -> (result: PassiveTransferResultRecord, update: LearnerStateUpdateRecord)? {
        guard postSlices.count >= ticket.requiredPostSliceCount else {
            return nil
        }

        let mergedPost = merge(sliceRecords: postSlices)
        guard let primaryMetric = passivePrimaryMetric(for: ticket.weakness, summary: mergedPost) else {
            return nil
        }

        let baselineValue = ticket.baselineMetricSnapshot[primaryMetric.key]
        let outcome = outcomeForMetric(
            key: primaryMetric.key,
            baselineValue: baselineValue,
            candidateValue: primaryMetric.value,
            betterDirection: primaryMetric.direction,
            weakness: ticket.weakness,
            sampleCount: primaryMetric.sampleCount,
            minimumSampleCount: minimumPassiveSampleCount(for: ticket.weakness)
        )

        let result = PassiveTransferResultRecord(
            ticketID: ticket.id,
            resolvedAt: Date(),
            baselineSliceIDs: ticket.baselineSliceIDs,
            postSliceIDs: postSlices.map(\.id),
            outcome: outcome.outcome,
            evidenceWeight: outcome.evidenceWeight,
            reasonCodes: outcome.reasonCodes,
            metricDeltaSummary: [
                primaryMetric.key: primaryMetric.value,
                "baseline::\(primaryMetric.key)": baselineValue ?? 0,
                "deltaAbs::\(primaryMetric.key)": outcome.deltaAbsolute ?? 0,
                "deltaRel::\(primaryMetric.key)": outcome.deltaRelative ?? 0
            ],
            evaluatorVersion: passiveTransferEvaluatorVersion
        )

        let update = makeUpdate(
            skillID: ticket.skillID,
            sourceType: .passiveTransfer,
            sessionID: ticket.sessionID,
            evaluationID: nil,
            outcome: outcome.outcome,
            focus: .automaticity,
            applied: false
        )

        return (result, update)
    }

    private static func compare(
        sessionID: UUID,
        evaluationType: PracticeEvaluationType,
        skillID: String,
        weakness: WeaknessCategory,
        baseline: PracticeBlockSummaryRecord,
        candidate: PracticeBlockSummaryRecord
    ) -> ImmediateEvaluationRecord {
        let primaryMetricInfo = primaryMetric(for: weakness)
        let baselineMetric = metricValue(in: baseline, key: primaryMetricInfo.metricKey, cohort: primaryMetricInfo.cohortKey)
        let candidateMetric = metricValue(in: candidate, key: primaryMetricInfo.metricKey, cohort: primaryMetricInfo.cohortKey)
        let sampleCount = min(
            metricSampleCount(in: baseline, key: primaryMetricInfo.metricKey, cohort: primaryMetricInfo.cohortKey),
            metricSampleCount(in: candidate, key: primaryMetricInfo.metricKey, cohort: primaryMetricInfo.cohortKey)
        )

        var reasonCodes: [String] = []
        var guardOutcomeCodes: [String] = []
        var specificityOutcome: String?

        let outcome = outcomeForMetric(
            key: primaryMetricInfo.metricKey,
            baselineValue: baselineMetric,
            candidateValue: candidateMetric,
            betterDirection: primaryMetricInfo.direction,
            weakness: weakness,
            sampleCount: sampleCount,
            minimumSampleCount: minimumImmediateSampleCount(for: weakness)
        )
        reasonCodes.append(contentsOf: outcome.reasonCodes)

        if let guardMetric = primaryMetricInfo.guardMetric {
            let baselineGuard = metricValue(in: baseline, key: guardMetric.metricKey, cohort: guardMetric.cohortKey)
            let candidateGuard = metricValue(in: candidate, key: guardMetric.metricKey, cohort: guardMetric.cohortKey)
            let guardCheck = guardrailOutcome(
                metricKey: guardMetric.metricKey,
                baselineValue: baselineGuard,
                candidateValue: candidateGuard,
                direction: guardMetric.direction
            )
            guardOutcomeCodes.append(guardCheck)
        }

        if let specificity = primaryMetricInfo.specificityControl {
            let baselineSpecificity = metricValue(in: baseline, key: specificity.metricKey, cohort: specificity.cohortKey)
            let candidateSpecificity = metricValue(in: candidate, key: specificity.metricKey, cohort: specificity.cohortKey)
            specificityOutcome = specificityCheck(
                weakness: weakness,
                primaryBaseline: baselineMetric,
                primaryCandidate: candidateMetric,
                controlBaseline: baselineSpecificity,
                controlCandidate: candidateSpecificity,
                direction: specificity.direction
            )
            if let specificityOutcome {
                reasonCodes.append(specificityOutcome)
            }
        }

        let finalOutcome = applyGuards(
            initial: outcome.outcome,
            guardOutcomeCodes: guardOutcomeCodes,
            specificityOutcome: specificityOutcome
        )

        return ImmediateEvaluationRecord(
            sessionID: sessionID,
            evaluationType: evaluationType,
            baselineBlockID: baseline.id,
            candidateBlockID: candidate.id,
            skillID: skillID,
            weakness: weakness,
            primaryMetricKey: "\(primaryMetricInfo.metricKey)::\(primaryMetricInfo.cohortKey)",
            baselineValue: baselineMetric,
            candidateValue: candidateMetric,
            deltaAbsolute: outcome.deltaAbsolute,
            deltaRelative: outcome.deltaRelative,
            guardOutcomeCodes: guardOutcomeCodes,
            specificityControlOutcome: specificityOutcome,
            outcome: finalOutcome,
            evidenceWeight: evidenceWeight(for: finalOutcome),
            reasonCodes: reasonCodes,
            evaluatorVersion: immediateEvaluatorVersion
        )
    }

    private static func targetConfirmationStatus(
        for weakness: WeaknessAssessment,
        baseline: PracticeBlockSummaryRecord?
    ) -> TargetConfirmationStatus {
        guard let baseline else { return .inconclusive }
        let metricInfo = primaryMetric(for: weakness.category)
        let sampleCount = metricSampleCount(in: baseline, key: metricInfo.metricKey, cohort: metricInfo.cohortKey)
        if weakness.category == .accuracyRecovery {
            let correctedEpisodes = metricValue(in: baseline, key: "correctedErrorEpisodeCount", cohort: "overall") ?? 0
            if sampleCount >= minimumImmediateSampleCount(for: weakness.category), correctedEpisodes >= 2 {
                return .confirmed
            }
            return .unconfirmed
        }

        if weakness.category == .flowConsistency {
            if sampleCount >= 16, baseline.activeTypingMilliseconds >= 45_000 {
                return .confirmed
            }
            return .inconclusive
        }

        if sampleCount >= minimumImmediateSampleCount(for: weakness.category) {
            return .confirmed
        }
        return .unconfirmed
    }

    private static func shouldCreateImmediateUpdate(
        for weakness: WeaknessCategory,
        targetConfirmationStatus: TargetConfirmationStatus
    ) -> Bool {
        weakness != .flowConsistency && targetConfirmationStatus == .confirmed
    }

    private static func minimumImmediateSampleCount(for weakness: WeaknessCategory) -> Int {
        switch weakness {
        case .sameHandSequences, .handHandoffs:
            return 8
        case .reachPrecision:
            return 6
        case .accuracyRecovery:
            return 3
        case .flowConsistency:
            return 8
        }
    }

    private static func minimumPassiveSampleCount(for weakness: WeaknessCategory) -> Int {
        switch weakness {
        case .sameHandSequences, .handHandoffs:
            return 30
        case .reachPrecision:
            return 20
        case .accuracyRecovery:
            return 8
        case .flowConsistency:
            return 20
        }
    }

    private static func passivePrimaryMetric(for weakness: WeaknessCategory, summary: TypingProfileSummary) -> (key: String, value: Double, sampleCount: Int, direction: PracticeMetricDirection)? {
        switch weakness {
        case .sameHandSequences:
            let stats = summary.flightStats(for: .sameHand)
            guard let value = stats.p50Milliseconds else { return nil }
            return ("flightMedianMs::sameHand", value, stats.sampleCount, .lowerIsBetter)
        case .handHandoffs:
            let stats = summary.flightStats(for: .crossHand)
            guard let value = stats.p50Milliseconds else { return nil }
            return ("flightMedianMs::crossHand", value, stats.sampleCount, .lowerIsBetter)
        case .reachPrecision:
            let stats = summary.flightStats(for: .far)
            guard let value = stats.p50Milliseconds else { return nil }
            return ("flightMedianMs::farDistance", value, stats.sampleCount, .lowerIsBetter)
        case .accuracyRecovery:
            let stats = summary.recoveryStats
            guard let value = stats.p50Milliseconds else { return nil }
            return ("recoveryLatencyMedianMs::correctionEpisode", value, stats.sampleCount, .lowerIsBetter)
        case .flowConsistency:
            let stats = summary.flightStats
            guard let value = stats.iqrMilliseconds else { return nil }
            return ("cadenceIQRMs::overall", value, stats.sampleCount, .lowerIsBetter)
        }
    }

    private static func merge(sliceRecords: [PassiveActiveSliceRecord]) -> TypingProfileSummary {
        var summary = TypingProfileSummary()
        for slice in sliceRecords {
            summary.merge(slice.summary)
        }
        return summary
    }

    private static func metricValue(in block: PracticeBlockSummaryRecord, key: String, cohort: String) -> Double? {
        let metric = block.metrics.first(where: { $0.metricKey == key && $0.cohortKey == cohort })
        return metric?.scalarValue ?? metric?.dispersionValue
    }

    private static func metricSampleCount(in block: PracticeBlockSummaryRecord, key: String, cohort: String) -> Int {
        block.metrics.first(where: { $0.metricKey == key && $0.cohortKey == cohort })?.sampleCount ?? 0
    }

    private static func outcomeForMetric(
        key: String,
        baselineValue: Double?,
        candidateValue: Double?,
        betterDirection: PracticeMetricDirection,
        weakness: WeaknessCategory,
        sampleCount: Int,
        minimumSampleCount: Int
    ) -> (outcome: PracticeEvaluationOutcome, deltaAbsolute: Double?, deltaRelative: Double?, reasonCodes: [String], evidenceWeight: Int) {
        guard sampleCount >= minimumSampleCount else {
            return (.insufficientData, nil, nil, ["insufficientSampleCount"], 0)
        }
        guard let baselineValue, let candidateValue else {
            return (.inconclusive, nil, nil, ["missingMetricValue"], 0)
        }

        let deltaAbsolute = candidateValue - baselineValue
        let deltaRelative = baselineValue != 0 ? deltaAbsolute / baselineValue : nil
        let normalizedImprovement = switch betterDirection {
        case .lowerIsBetter:
            -deltaAbsolute
        case .higherIsBetter:
            deltaAbsolute
        }
        let normalizedRelativeImprovement = switch betterDirection {
        case .lowerIsBetter:
            -(deltaRelative ?? 0)
        case .higherIsBetter:
            deltaRelative ?? 0
        }

        let threshold = thresholds(for: key, weakness: weakness)
        let reasonCodes = [
            "deltaAbs:\(String(format: "%.3f", deltaAbsolute))",
            "deltaRel:\(String(format: "%.3f", deltaRelative ?? 0))"
        ]

        if normalizedImprovement >= threshold.strongAbsolute || normalizedRelativeImprovement >= threshold.strongRelative {
            let outcome: PracticeEvaluationOutcome = weakness == .flowConsistency ? .improvedWeak : .improvedStrong
            return (outcome, deltaAbsolute, deltaRelative, reasonCodes, 2)
        }
        if normalizedImprovement >= threshold.weakAbsolute || normalizedRelativeImprovement >= threshold.weakRelative {
            let outcome: PracticeEvaluationOutcome = weakness == .flowConsistency ? .flat : .improvedWeak
            return (outcome, deltaAbsolute, deltaRelative, reasonCodes, 1)
        }
        if normalizedImprovement <= -threshold.strongAbsolute || normalizedRelativeImprovement <= -threshold.strongRelative {
            let outcome: PracticeEvaluationOutcome = weakness == .flowConsistency ? .worseWeak : .worseStrong
            return (outcome, deltaAbsolute, deltaRelative, reasonCodes, -2)
        }
        if normalizedImprovement <= -threshold.weakAbsolute || normalizedRelativeImprovement <= -threshold.weakRelative {
            let outcome: PracticeEvaluationOutcome = weakness == .flowConsistency ? .flat : .worseWeak
            return (outcome, deltaAbsolute, deltaRelative, reasonCodes, -1)
        }
        return (.flat, deltaAbsolute, deltaRelative, reasonCodes, 0)
    }

    private static func thresholds(for metricKey: String, weakness: WeaknessCategory) -> (weakAbsolute: Double, weakRelative: Double, strongAbsolute: Double, strongRelative: Double) {
        switch weakness {
        case .sameHandSequences, .handHandoffs:
            return (10, 0.07, 18, 0.12)
        case .reachPrecision:
            if metricKey == "incorrectRate" {
                return (0.02, 0.15, 0.03, 0.22)
            }
            return (12, 0.08, 20, 0.14)
        case .accuracyRecovery:
            return (80, 0.12, 130, 0.2)
        case .flowConsistency:
            return (16, 0.14, 28, 0.24)
        }
    }

    private static func guardrailOutcome(
        metricKey: String,
        baselineValue: Double?,
        candidateValue: Double?,
        direction: PracticeMetricDirection
    ) -> String {
        guard let baselineValue, let candidateValue else {
            return "guardMissingData:\(metricKey)"
        }
        let delta = candidateValue - baselineValue
        switch (metricKey, direction) {
        case ("incorrectRate", .lowerIsBetter):
            return delta > 0.012 ? "guardFailed:accuracyRegressed" : "guardPassed:accuracy"
        case ("charsPerSecond", .higherIsBetter):
            let relative = baselineValue > 0 ? delta / baselineValue : 0
            return relative < -0.05 ? "guardFailed:speedRegressed" : "guardPassed:speed"
        default:
            return "guardPassed:\(metricKey)"
        }
    }

    private static func specificityCheck(
        weakness: WeaknessCategory,
        primaryBaseline: Double?,
        primaryCandidate: Double?,
        controlBaseline: Double?,
        controlCandidate: Double?,
        direction: PracticeMetricDirection
    ) -> String? {
        guard let primaryBaseline, let primaryCandidate, let controlBaseline, let controlCandidate else {
            return nil
        }
        let primaryDelta = switch direction {
        case .lowerIsBetter:
            primaryBaseline - primaryCandidate
        case .higherIsBetter:
            primaryCandidate - primaryBaseline
        }
        let controlDelta = switch direction {
        case .lowerIsBetter:
            controlBaseline - controlCandidate
        case .higherIsBetter:
            controlCandidate - controlBaseline
        }
        if primaryDelta <= 0 {
            return "specificity:none"
        }
        if controlDelta >= primaryDelta * 0.9 {
            return "specificity:warmupLike"
        }
        return "specificity:targeted"
    }

    private static func applyGuards(
        initial: PracticeEvaluationOutcome,
        guardOutcomeCodes: [String],
        specificityOutcome: String?
    ) -> PracticeEvaluationOutcome {
        if guardOutcomeCodes.contains("guardFailed:accuracyRegressed") || guardOutcomeCodes.contains("guardFailed:speedRegressed") {
            return .flat
        }
        if specificityOutcome == "specificity:warmupLike", initial == .improvedStrong {
            return .improvedWeak
        }
        return initial
    }

    private enum UpdateFocus {
        case control
        case consistency
        case automaticity
    }

    private static func makeUpdate(
        skillID: String,
        sourceType: LearnerStateUpdateSource,
        sessionID: UUID?,
        evaluationID: UUID?,
        outcome: PracticeEvaluationOutcome,
        focus: UpdateFocus,
        applied: Bool
    ) -> LearnerStateUpdateRecord {
        let magnitude = switch outcome {
        case .improvedStrong:
            0.08
        case .improvedWeak:
            0.04
        case .worseWeak:
            -0.03
        case .worseStrong:
            -0.06
        default:
            0.0
        }

        return LearnerStateUpdateRecord(
            createdAt: Date(),
            skillID: skillID,
            sourceType: sourceType,
            sourceSessionID: sessionID,
            sourceEvaluationID: evaluationID,
            deltaControl: focus == .control ? magnitude : 0,
            deltaConsistency: focus == .consistency ? magnitude : 0,
            deltaAutomaticity: focus == .automaticity ? magnitude : 0,
            deltaStability: 0,
            evidenceWeight: evidenceWeight(for: outcome),
            reasonCodes: ["shadowMode", "outcome:\(outcome.rawValue)"],
            policyVersion: learnerUpdatePolicyVersion,
            appliedToRecommendations: applied
        )
    }

    private static func evidenceWeight(for outcome: PracticeEvaluationOutcome) -> Int {
        switch outcome {
        case .improvedStrong, .worseStrong:
            return 2
        case .improvedWeak, .worseWeak:
            return 1
        default:
            return 0
        }
    }

    private struct MetricReference {
        let metricKey: String
        let cohortKey: String
        let direction: PracticeMetricDirection
    }

    private struct MetricDescriptor {
        let metricKey: String
        let cohortKey: String
        let direction: PracticeMetricDirection
        let guardMetric: MetricReference?
        let specificityControl: MetricReference?
    }

    private static func primaryMetric(for weakness: WeaknessCategory) -> MetricDescriptor {
        switch weakness {
        case .sameHandSequences:
            return MetricDescriptor(
                metricKey: "flightMedianMs",
                cohortKey: "sameHand",
                direction: .lowerIsBetter,
                guardMetric: MetricReference(metricKey: "incorrectRate", cohortKey: "overall", direction: .lowerIsBetter),
                specificityControl: MetricReference(metricKey: "flightMedianMs", cohortKey: "crossHand", direction: .lowerIsBetter)
            )
        case .handHandoffs:
            return MetricDescriptor(
                metricKey: "flightMedianMs",
                cohortKey: "crossHand",
                direction: .lowerIsBetter,
                guardMetric: MetricReference(metricKey: "incorrectRate", cohortKey: "overall", direction: .lowerIsBetter),
                specificityControl: MetricReference(metricKey: "flightMedianMs", cohortKey: "sameHand", direction: .lowerIsBetter)
            )
        case .reachPrecision:
            return MetricDescriptor(
                metricKey: "flightMedianMs",
                cohortKey: "farDistance",
                direction: .lowerIsBetter,
                guardMetric: MetricReference(metricKey: "incorrectRate", cohortKey: "overall", direction: .lowerIsBetter),
                specificityControl: MetricReference(metricKey: "flightMedianMs", cohortKey: "nearDistance", direction: .lowerIsBetter)
            )
        case .accuracyRecovery:
            return MetricDescriptor(
                metricKey: "recoveryLatencyMedianMs",
                cohortKey: "correctionEpisode",
                direction: .lowerIsBetter,
                guardMetric: MetricReference(metricKey: "incorrectRate", cohortKey: "overall", direction: .lowerIsBetter),
                specificityControl: nil
            )
        case .flowConsistency:
            return MetricDescriptor(
                metricKey: "cadenceIQRMs",
                cohortKey: "overall",
                direction: .lowerIsBetter,
                guardMetric: MetricReference(metricKey: "incorrectRate", cohortKey: "overall", direction: .lowerIsBetter),
                specificityControl: nil
            )
        }
    }
}
