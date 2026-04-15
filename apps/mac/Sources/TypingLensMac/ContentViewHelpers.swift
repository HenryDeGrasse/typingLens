import Capture
import Core
import SwiftUI

// MARK: - Shared formatting helpers

func percentString(_ value: Double) -> String {
    "\(String(format: "%.1f", value * 100))%"
}

func decimalString(_ value: Double) -> String {
    String(format: "%.1f", value)
}

func millisecondsString(_ value: Double?) -> String {
    guard let value else { return "n/a" }
    return String(format: "%.0f ms", value)
}

func timestampLabel(_ date: Date?) -> String {
    guard let date else {
        return "No data yet"
    }
    return date.formatted(date: .omitted, time: .standard)
}

func dateTimeLabel(_ date: Date?) -> String {
    guard let date else {
        return "No data yet"
    }
    return date.formatted(date: .abbreviated, time: .shortened)
}

func baselineFootnote(for baselineValue: Double) -> String {
    baselineValue > 0 ? "Baseline \(String(format: "%.1f", baselineValue))" : "Baseline building"
}

func averageSkillValue(_ value: SkillDimensionState) -> Double {
    (value.control + value.automaticity + value.consistency + value.stability) / 4.0
}

func skillValueLabel(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

func timerString(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    return String(format: "%d:%02d", minutes, remainder)
}

func signedPercent(_ value: Double) -> String {
    let percent = Int((value * 100).rounded())
    return percent >= 0 ? "+\(percent)%" : "\(percent)%"
}

func formattedReasonCodes(_ codes: [String]) -> String {
    codes
        .map { code in
            code
                .replacingOccurrences(of: ":", with: " = ")
                .replacingOccurrences(of: "guardFailed", with: "guard failed")
                .replacingOccurrences(of: "guardPassed", with: "guard passed")
                .replacingOccurrences(of: "specificity", with: "specificity")
                .replacingOccurrences(of: "warmupLike", with: "warm-up-like")
                .replacingOccurrences(of: "insufficientSampleCount", with: "insufficient sample count")
                .replacingOccurrences(of: "missingMetricValue", with: "missing metric value")
                .replacingOccurrences(of: "appliedGatePassed", with: "applied gate passed")
                .replacingOccurrences(of: "appliedGateDeferred", with: "applied gate deferred")
        }
        .joined(separator: " · ")
}

// MARK: - Display name helpers

func displayName(for confidence: WeaknessConfidence) -> String {
    switch confidence {
    case .low:
        return "Low"
    case .medium:
        return "Medium"
    case .high:
        return "High"
    }
}

func displayName(for severity: WeaknessSeverity) -> String {
    switch severity {
    case .mild:
        return "Mild"
    case .moderate:
        return "Moderate"
    case .strong:
        return "Strong"
    }
}

func displayName(for family: PracticeDrillFamily) -> String {
    switch family {
    case .sameHandLadders:
        return "Same-Hand Ladders"
    case .reachAndReturn:
        return "Reach & Return"
    case .alternationRails:
        return "Alternation Rails"
    case .accuracyReset:
        return "Accuracy Reset"
    case .meteredFlow:
        return "Metered Flow"
    case .mixedTransfer:
        return "Mixed Transfer"
    }
}

func displayName(for weakness: WeaknessCategory) -> String {
    switch weakness {
    case .sameHandSequences:
        return "Same-hand sequences"
    case .reachPrecision:
        return "Reach execution"
    case .accuracyRecovery:
        return "Accuracy recovery"
    case .handHandoffs:
        return "Hand handoffs"
    case .flowConsistency:
        return "Flow consistency"
    }
}

func displayName(for status: TargetConfirmationStatus) -> String {
    switch status {
    case .confirmed:
        return "Confirmed"
    case .unconfirmed:
        return "Unconfirmed"
    case .inconclusive:
        return "Inconclusive"
    }
}

func displayName(for outcome: PracticeEvaluationOutcome?) -> String {
    guard let outcome else { return "n/a" }
    switch outcome {
    case .improvedStrong:
        return "Strong improvement"
    case .improvedWeak:
        return "Weak improvement"
    case .flat:
        return "No meaningful change"
    case .worseWeak:
        return "Weak regression"
    case .worseStrong:
        return "Strong regression"
    case .inconclusive:
        return "Inconclusive"
    case .insufficientData:
        return "Insufficient data"
    case .expired:
        return "Expired"
    case .unavailable:
        return "Unavailable"
    }
}

func displayName(for status: PassiveTransferTicketStatus) -> String {
    switch status {
    case .pending:
        return "Pending"
    case .resolved:
        return "Resolved"
    case .expired:
        return "Expired"
    case .unavailable:
        return "Unavailable"
    }
}

func displayName(for mode: PracticeUpdateMode) -> String {
    switch mode {
    case .shadow:
        return "Shadow only"
    case .applied:
        return "Applied"
    }
}

func displayName(for type: PracticeEvaluationType) -> String {
    switch type {
    case .postCheck:
        return "Post-check"
    case .nearTransferCheck:
        return "Near-transfer"
    }
}

func displayName(for source: LearnerStateUpdateSource) -> String {
    switch source {
    case .sessionImmediate:
        return "Immediate session"
    case .nearTransfer:
        return "Near-transfer"
    case .passiveTransfer:
        return "Passive transfer"
    case .manual:
        return "Manual"
    case .migration:
        return "Migration"
    }
}

func displayName(for kind: PracticeBlockKind) -> String {
    switch kind {
    case .confirmatoryProbe:
        return "Confirmatory probe"
    case .drill:
        return "Drill"
    case .postCheck:
        return "Post-check"
    case .nearTransferCheck:
        return "Near-transfer"
    }
}

func displayName(for sufficiency: PracticeSufficiencyStatus) -> String {
    switch sufficiency {
    case .sufficient:
        return "Sufficient"
    case .insufficient:
        return "Insufficient"
    }
}

func displayName(for status: PracticeRuntimeStatus) -> String {
    switch status {
    case .idle:
        return "Idle"
    case .running:
        return "Running"
    case .paused:
        return "Paused"
    case .completed:
        return "Completed"
    case .canceled:
        return "Canceled"
    }
}

func displaySkillTitle(for skillID: String, in state: CaptureDashboardState) -> String {
    state.learningModel.studentStates.first(where: { $0.id == skillID })?.title
        ?? state.learningModel.skillNodes.first(where: { $0.id == skillID })?.name
        ?? skillID
}

func transferTicketStatusLabel(_ progress: PassiveTransferProgressSnapshot) -> String {
    let now = Date()
    if now < progress.earliestEligibleAt {
        return "Waiting for cooldown before passive transfer measurement. Eligible at \(dateTimeLabel(progress.earliestEligibleAt))."
    }
    if progress.incompatibleSliceCount > 0 {
        return "Collecting compatible passive slices. Some recent typing used a different layout or keyboard, so those slices do not count toward transfer."
    }
    return "Waiting for at least \(progress.requiredSliceCount) compatible passive slices before \(dateTimeLabel(progress.expiresAt))."
}

func passiveTransferSummary(for session: PracticeSessionSummaryRecord, in state: CaptureDashboardState) -> String? {
    if let ticketID = session.passiveTransferTicketID,
       let progress = state.practiceHistory.pendingTransferProgress.first(where: { $0.ticketID == ticketID }) {
        return "Passive transfer pending · \(progress.compatibleSliceCount)/\(progress.requiredSliceCount) compatible slices collected."
    }

    if let ticketID = session.passiveTransferTicketID,
       let result = state.practiceHistory.recentTransferResults.first(where: { $0.ticketID == ticketID }) {
        return "Passive transfer resolved · \(displayName(for: result.outcome))."
    }

    return session.passiveTransferStatusNote
}

let manualPracticeFamilies: [PracticeDrillFamily] = [
    .sameHandLadders, .reachAndReturn, .alternationRails, .accuracyReset, .meteredFlow
]

let summaryColumns: [GridItem] = [
    GridItem(.flexible(minimum: 180), spacing: 16),
    GridItem(.flexible(minimum: 180), spacing: 16),
    GridItem(.flexible(minimum: 180), spacing: 16)
]

// MARK: - Shared small view structs

struct StatusPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .textCase(.lowercase)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let footnote: String

    init(title: String, value: String, footnote: String = "") {
        self.title = title
        self.value = value
        self.footnote = footnote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            if !footnote.isEmpty {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct StatsRow {
    let title: String
    let today: TimingStatsSummary
    let baseline: TimingStatsSummary
}

struct StatsGrid: View {
    let rows: [StatsRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \ .offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.headline)
                    Text("Today p50 \(millisecondsLabel(row.today.p50Milliseconds)) · p90 \(millisecondsLabel(row.today.p90Milliseconds)) · IQR \(millisecondsLabel(row.today.iqrMilliseconds))")
                        .foregroundStyle(.primary)
                    Text("Baseline p50 \(millisecondsLabel(row.baseline.p50Milliseconds)) · p90 \(millisecondsLabel(row.baseline.p90Milliseconds)) · IQR \(millisecondsLabel(row.baseline.iqrMilliseconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
            }
        }
    }

    private func millisecondsLabel(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.0f ms", value)
    }
}

struct HistogramCard: View {
    let title: String
    let entries: [HistogramEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if entries.reduce(0, { $0 + $1.value }) == 0 {
                Text("No data yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries.filter { $0.value > 0 }) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(entry.value)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.75))
                                .frame(width: max(6, geometry.size.width * widthRatio(for: entry)))
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func widthRatio(for entry: HistogramEntry) -> CGFloat {
        guard let maxValue = entries.map(\.value).max(), maxValue > 0 else { return 0 }
        return CGFloat(entry.value) / CGFloat(maxValue)
    }
}

struct NGramInsightsCard: View {
    let title: String
    let subtitle: String
    let metrics: [RankedNGramMetric]

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 12) {
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if metrics.isEmpty {
                    Text("No transient n-grams yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(metrics) { metric in
                        HStack(alignment: .center, spacing: 12) {
                            Text(metric.gram)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .frame(width: 120, alignment: .leading)
                            Text("count \(metric.count)")
                                .frame(width: 90, alignment: .leading)
                                .foregroundStyle(.secondary)
                            Text(latencyLabel(for: metric.averageLatencyMilliseconds))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func latencyLabel(for milliseconds: Double?) -> String {
        guard let milliseconds else {
            return "latency n/a"
        }
        return String(format: "avg %.0f ms", milliseconds)
    }
}

struct ExclusionListCard: View {
    let title: String
    let subtitle: String
    let applications: [ExcludedApplication]

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 10) {
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(applications) { application in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(application.displayName)
                            .font(.headline)
                        Text(application.bundleIdentifier)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct ManualExclusionListCard: View {
    let title: String
    let subtitle: String
    let applications: [ExcludedApplication]
    let onRemove: (ExcludedApplication) -> Void

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 10) {
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if applications.isEmpty {
                    Text("No manual exclusions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(applications) { application in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(application.displayName)
                                    .font(.headline)
                                Text(application.bundleIdentifier)
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            Button("Remove") {
                                onRemove(application)
                            }
                            .buttonStyle(.borderless)
                        }
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .frame(width: 180, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct EmptyStateBanner: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}
