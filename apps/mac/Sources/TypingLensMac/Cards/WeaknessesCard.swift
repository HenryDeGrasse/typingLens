import Capture
import Core
import SwiftUI

struct WeaknessesCard: View {
    @ObservedObject var captureService: CaptureService

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
        GroupBox("Current Weakness Model") {
            VStack(alignment: .leading, spacing: 12) {
                Text("M4 interprets the M3 profile through a small hand-authored skill graph. Passive typing creates candidate weaknesses, and the system recommends one primary focus at a time instead of trying to blend multiple weak spots into one session.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if state.learningModel.weaknesses.isEmpty {
                    Text("No strong weakness candidates yet. Keep typing in non-excluded apps so the learner model can build better evidence.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.learningModel.weaknesses) { weakness in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(weakness.title)
                                    .font(.headline)
                                Spacer()
                                Text("\(displayName(for: weakness.confidence)) confidence · \(displayName(for: weakness.severity))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(weakness.summary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Why: \(weakness.supportingSignals.joined(separator: " · "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Recommended drill family: \(displayName(for: weakness.recommendedDrill))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PracticePlanCard: View {
    @ObservedObject var captureService: CaptureService

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
        GroupBox("Recommended Next Practice") {
            VStack(alignment: .leading, spacing: 12) {
                Text("The first M4 slice keeps practice deterministic and explainable: confirm the weakness, run one drill family, then check immediate and later transfer.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let session = state.learningModel.recommendedSession,
                   let primaryWeakness = state.learningModel.primaryWeakness {
                    Text(session.primaryFocusTitle)
                        .font(.title3.weight(.semibold))

                    Text(primaryWeakness.rationale)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(session.blocks) { block in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(block.title)
                                    .font(.headline)
                                Spacer()
                                Text(block.durationSeconds > 0 ? "\(block.durationSeconds)s" : "later")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(block.detail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                    }

                    Text(session.followUp)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Menu("Manual tester override") {
                        ForEach(manualPracticeFamilies, id: \.self) { family in
                            Button(displayName(for: family)) {
                                captureService.startManualPracticeSession(family: family)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No primary practice session is recommended yet. The app needs a little more evidence before it should prescribe a focused drill.")
                            .foregroundStyle(.secondary)

                        Menu("Manual tester override") {
                            ForEach(manualPracticeFamilies, id: \.self) { family in
                                Button(displayName(for: family)) {
                                    captureService.startManualPracticeSession(family: family)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
