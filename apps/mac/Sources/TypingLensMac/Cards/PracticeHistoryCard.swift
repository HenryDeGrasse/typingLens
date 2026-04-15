import Capture
import Core
import SwiftUI

struct PracticeHistoryCard: View {
    @ObservedObject var captureService: CaptureService

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
        GroupBox("Evidence Ledger + Audit Trail") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This tester view shows the local SQLite evidence ledger. It stores aggregate-only recommendations, sessions, evaluations, passive transfer tickets, and learner-state update records. It does not store prompt text, typed responses, or raw keystroke streams.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let modelVersion = state.practiceHistory.modelVersionStamp {
                    Text("Model stamp: practice \(modelVersion.practiceScorerVersion) · immediate eval \(modelVersion.immediateEvaluatorVersion) · passive transfer \(modelVersion.passiveTransferEvaluatorVersion) · update policy \(modelVersion.learnerUpdatePolicyVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if state.practiceHistory.recentDecisions.isEmpty
                    && state.practiceHistory.recentSessions.isEmpty
                    && state.practiceHistory.recentEvaluations.isEmpty
                    && state.practiceHistory.pendingTransferTickets.isEmpty
                    && state.practiceHistory.recentTransferResults.isEmpty
                    && state.practiceHistory.recentStateUpdates.isEmpty {
                    EmptyStateBanner(
                        symbol: "doc.text.magnifyingglass",
                        title: "No evidence yet",
                        detail: "Once you complete a recommended or manual practice session, the recommendation, block summaries, immediate evaluation, and any passive transfer ticket will land here."
                    )
                }

                if !state.practiceHistory.recentDecisions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent recommendation decisions")
                            .font(.headline)
                        ForEach(state.practiceHistory.recentDecisions.prefix(4)) { decision in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(displaySkillTitle(for: decision.selectedSkillID, in: state)) · \(displayName(for: decision.selectedWeakness))")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(dateTimeLabel(decision.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Why chosen: \(decision.selectedBecauseReasonCode)")
                                    .font(.caption)
                                if !decision.candidateReasonCodes.isEmpty {
                                    Text(formattedReasonCodes(decision.candidateReasonCodes))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Divider()
                        }
                    }
                }

                if !state.practiceHistory.pendingTransferTickets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pending passive transfer tickets")
                            .font(.headline)
                        ForEach(state.practiceHistory.pendingTransferProgress) { progress in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(displaySkillTitle(for: progress.skillID, in: state)) · \(displayName(for: progress.weakness))")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(displayName(for: progress.status))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(transferTicketStatusLabel(progress))
                                    .font(.caption)
                                ProgressView(value: Double(progress.compatibleSliceCount), total: Double(max(progress.requiredSliceCount, 1)))
                                Text("Compatible slices \(progress.compatibleSliceCount) / \(progress.requiredSliceCount) · incompatible slices \(progress.incompatibleSliceCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Layout \(progress.keyboardLayoutID) · Device \(progress.keyboardDeviceClass)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                }

                if state.practiceHistory.recentSessions.isEmpty {
                    Text("No completed sessions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent sessions")
                            .font(.headline)
                        ForEach(state.practiceHistory.recentSessions) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(displaySkillTitle(for: session.selectedSkillID, in: state)) · \(displayName(for: session.selectedWeakness))")
                                        .font(.headline)
                                    Spacer()
                                    Text(displayName(for: session.targetConfirmationStatus))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Immediate \(displayName(for: session.immediateOutcome)) · Near transfer \(displayName(for: session.nearTransferOutcome)) · Update mode \(displayName(for: session.updateMode))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Started \(dateTimeLabel(session.startedAt)) · Ended \(dateTimeLabel(session.endedAt)) · Blocks \(session.blockSummaries.count) · Layout \(session.keyboardLayoutID) · Device \(session.keyboardDeviceClass)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let passiveTransferSummaryText = passiveTransferSummary(for: session, in: state) {
                                    Text(passiveTransferSummaryText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                DisclosureGroup("Block details") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(session.blockSummaries) { block in
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text("\(displayName(for: block.role)) · \(block.title)")
                                                        .font(.subheadline.weight(.medium))
                                                    Spacer()
                                                    Text(percentString(block.accuracy))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text("Prompts \(block.promptsCompleted) · Entered \(block.charsEntered) · Active \(timerString(block.activeTypingMilliseconds / 1000)) · Sufficiency \(displayName(for: block.sufficiencyStatus))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(block.assessmentBlueprintDescriptor)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            Divider()
                        }
                    }
                }

                if !state.practiceHistory.recentEvaluations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent evaluations")
                            .font(.headline)
                        ForEach(state.practiceHistory.recentEvaluations.prefix(6)) { evaluation in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("\(displayName(for: evaluation.evaluationType)) · \(displayName(for: evaluation.outcome))")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(evaluation.primaryMetricKey)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !evaluation.guardOutcomeCodes.isEmpty {
                                    Text("Guards: \(formattedReasonCodes(evaluation.guardOutcomeCodes))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let specificity = evaluation.specificityControlOutcome {
                                    Text("Specificity: \(formattedReasonCodes([specificity]))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(formattedReasonCodes(evaluation.reasonCodes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                }

                if !state.practiceHistory.recentTransferResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent passive transfer results")
                            .font(.headline)
                        ForEach(state.practiceHistory.recentTransferResults.prefix(4)) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(displayName(for: result.outcome))
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(dateTimeLabel(result.resolvedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(formattedReasonCodes(result.reasonCodes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                }

                if !state.practiceHistory.recentStateUpdates.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent learner-state updates")
                            .font(.headline)
                        ForEach(state.practiceHistory.recentStateUpdates.prefix(6)) { update in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(displaySkillTitle(for: update.skillID, in: state)) · \(displayName(for: update.sourceType))")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(update.appliedToRecommendations ? "Applied" : "Shadow")
                                        .font(.caption)
                                        .foregroundStyle(update.appliedToRecommendations ? .green : .secondary)
                                }
                                Text("Δ control \(signedPercent(update.deltaControl)) · Δ consistency \(signedPercent(update.deltaConsistency)) · Δ auto \(signedPercent(update.deltaAutomaticity))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formattedReasonCodes(update.reasonCodes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
