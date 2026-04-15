import Capture
import Core
import SwiftUI

struct SkillStateCard: View {
    @ObservedObject var captureService: CaptureService

    private var state: CaptureDashboardState {
        captureService.state
    }

    private var prioritizedStudentStates: [StudentSkillState] {
        state.learningModel.studentStates
            .sorted {
                averageSkillValue($0.current) < averageSkillValue($1.current)
            }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        GroupBox("Learner State Snapshot") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Each skill stores a small continuous state: control, automaticity, consistency, and stability. This is the long-term scaffold for future probes, drills, and transfer tracking.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if prioritizedStudentStates.isEmpty {
                    Text("No learner-state rows yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(prioritizedStudentStates, id: \.id) { skillState in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(skillState.title)
                                    .font(.headline)
                                Spacer()
                                Text(displayName(for: skillState.confidence))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Control \(skillValueLabel(skillState.current.control)) · Auto \(skillValueLabel(skillState.current.automaticity)) · Consistency \(skillValueLabel(skillState.current.consistency)) · Stability \(skillValueLabel(skillState.current.stability))")
                                .foregroundStyle(.primary)
                            Text(skillState.note)
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

struct RhythmAndFlowRow: View {
    @ObservedObject var captureService: CaptureService

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            GroupBox("Rhythm") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rhythm tracks how consistently you press keys and move to the next one. Pauses that cross the burst boundary are treated as flow events, not rhythm transitions, so thinking time does not dominate flight timing.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    StatsGrid(
                        rows: [
                            StatsRow(title: "Flight", today: state.profileSnapshot.today.flightStats, baseline: state.profileSnapshot.baseline.flightStats),
                            StatsRow(title: "Dwell", today: state.profileSnapshot.today.dwellStats, baseline: state.profileSnapshot.baseline.dwellStats),
                            StatsRow(title: "Letter dwell", today: state.profileSnapshot.today.dwellStats(for: .letter), baseline: state.profileSnapshot.baseline.dwellStats(for: .letter)),
                            StatsRow(title: "Punctuation dwell", today: state.profileSnapshot.today.dwellStats(for: .punctuation), baseline: state.profileSnapshot.baseline.dwellStats(for: .punctuation))
                        ]
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .top)

            GroupBox("Flow") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Flow tracks pauses and bursts so Typing Lens can separate motor friction from thinking pauses and fragmented drafting.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HistogramCard(title: "Pause distribution", entries: state.profileSnapshot.today.pauseHistogram.entries())
                    HistogramCard(title: "Burst length distribution", entries: state.profileSnapshot.today.burstLengthHistogram.entries())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

struct AccuracyAndReachRow: View {
    @ObservedObject var captureService: CaptureService

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            GroupBox("Accuracy") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Accuracy tracks how often you correct, how long corrections last, and how much hesitation surrounds those edits. Held-delete bursts are tracked separately so holding down backspace does not distort rhythm metrics.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "Backspace density", value: percentString(state.profileSnapshot.today.backspaceDensity), footnote: baselineFootnote(for: state.profileSnapshot.baseline.backspaceDensity))
                        MetricCard(title: "Held delete bursts", value: "\(state.profileSnapshot.today.heldDeleteBurstCount)", footnote: baselineFootnote(for: Double(state.profileSnapshot.baseline.heldDeleteBurstCount)))
                    }

                    StatsGrid(
                        rows: [
                            StatsRow(title: "Pre-correction hesitation", today: state.profileSnapshot.today.preCorrectionStats, baseline: state.profileSnapshot.baseline.preCorrectionStats),
                            StatsRow(title: "Recovery after correction", today: state.profileSnapshot.today.recoveryStats, baseline: state.profileSnapshot.baseline.recoveryStats),
                            StatsRow(title: "Held delete duration", today: state.profileSnapshot.today.heldDeleteStats, baseline: state.profileSnapshot.baseline.heldDeleteStats)
                        ]
                    )

                    HistogramCard(title: "Correction burst lengths", entries: state.profileSnapshot.today.correctionBurstHistogram.entries())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .top)

            GroupBox("Reach") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reach is a content-free view of movement friction. Typing Lens groups transitions by hand pattern and approximate keyboard travel distance.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    StatsGrid(
                        rows: [
                            StatsRow(title: "Same-hand flight", today: state.profileSnapshot.today.flightStats(for: .sameHand), baseline: state.profileSnapshot.baseline.flightStats(for: .sameHand)),
                            StatsRow(title: "Cross-hand flight", today: state.profileSnapshot.today.flightStats(for: .crossHand), baseline: state.profileSnapshot.baseline.flightStats(for: .crossHand)),
                            StatsRow(title: "Near reach", today: state.profileSnapshot.today.flightStats(for: .near), baseline: state.profileSnapshot.baseline.flightStats(for: .near)),
                            StatsRow(title: "Far reach", today: state.profileSnapshot.today.flightStats(for: .far), baseline: state.profileSnapshot.baseline.flightStats(for: .far))
                        ]
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
