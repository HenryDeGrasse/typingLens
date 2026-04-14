import Capture
import Core
import SwiftUI

struct ContentView: View {
    @ObservedObject var captureService: CaptureService
    @State private var isShowingAdvancedDiagnostics = false
    @State private var isShowingDebug = false
    @State private var manualBundleIdentifier = ""

    private var state: CaptureDashboardState {
        captureService.state
    }

    private let summaryColumns = [
        GridItem(.flexible(minimum: 180), spacing: 16),
        GridItem(.flexible(minimum: 180), spacing: 16),
        GridItem(.flexible(minimum: 180), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                statusOverview
                controlsCard
                profileOverviewCard
                insightCard
                weaknessesCard
                practicePlanCard
                skillStateCard
                rhythmAndFlowRow
                accuracyAndReachRow
                exclusionsCard
                trustAndTapCard
                advancedDiagnosticsCard
                #if DEBUG
                debugOnlyCard
                #endif
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heroCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Typing Lens · M4 Skill Graph + Practice Prescription")
                    .font(.system(size: 28, weight: .bold))

                Text("Typing Lens now pairs its local profile engine with a first deterministic learning model. The app estimates skill state from rhythm, flow, correction, and reach; detects likely weaknesses; and proposes a small explainable practice session without storing raw text or persistent literal n-grams.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Request Access / Open Settings") {
                        captureService.requestPermissionFlow()
                    }
                    .keyboardShortcut(.defaultAction)

                    Button("Re-check Access") {
                        captureService.refreshPermissionState()
                        captureService.startTapIfPossible()
                    }

                    Button("Open Input Monitoring Settings") {
                        captureService.openInputMonitoringSettings()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusOverview: some View {
        GroupBox("Current State") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    StatusPill(title: "Permission", value: permissionLabel, tint: permissionTint)
                    StatusPill(title: "Capture", value: captureLabel, tint: captureTint)
                    StatusPill(title: "Baseline", value: baselineLabel, tint: baselineTint)
                    StatusPill(title: "Secure input", value: secureInputLabel, tint: secureInputTint)
                }

                Text(state.guidanceText)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Product source of truth: content-free local profile summaries plus a deterministic skill graph and learner state model. Not persisted: raw typed text, raw preview text, raw event streams, or persistent literal n-grams.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if state.permissionState == .denied {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Denied-state guidance")
                            .font(.headline)
                        Text("1. Open System Settings → Privacy & Security → Input Monitoring.")
                        Text("2. Enable Typing Lens in the list, or add the built app if it does not appear.")
                        Text("3. Return here and click Re-check Access.")
                        Text("4. If macOS still blocks the tap, quit and reopen the app once.")
                    }
                    .padding(12)
                    .background(permissionTint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controlsCard: some View {
        GroupBox("Controls") {
            HStack(spacing: 12) {
                Button(state.isPaused ? "Resume Capture" : "Pause Capture") {
                    captureService.togglePause()
                }
                .disabled(state.permissionState != .granted || !state.tapHealth.isInstalled)

                Button("Reset Profile + Diagnostics") {
                    captureService.resetCaptureData()
                }

                Spacer()

                Text("Profile summaries may persist locally · debug preview stays in memory only")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var profileOverviewCard: some View {
        GroupBox("Profile Overview") {
            VStack(alignment: .leading, spacing: 16) {
                Text("The main profile compares today’s local typing behavior with your rolling baseline. Until enough days are collected, Typing Lens shows a baseline-building state instead of pretending the profile is stable.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 16) {
                    MetricCard(title: "Included keydowns", value: "\(state.profileSnapshot.today.includedKeyDownCount)", footnote: baselineFootnote(for: Double(state.profileSnapshot.baseline.includedKeyDownCount)))
                    MetricCard(title: "Backspace density", value: percentString(state.profileSnapshot.today.backspaceDensity), footnote: baselineFootnote(for: state.profileSnapshot.baseline.backspaceDensity))
                    MetricCard(title: "Sessions today", value: "\(state.profileSnapshot.today.sessionCount)", footnote: baselineFootnote(for: Double(state.profileSnapshot.baseline.sessionCount)))
                    MetricCard(title: "Avg burst length", value: decimalString(state.profileSnapshot.today.averageBurstLength), footnote: baselineFootnote(for: state.profileSnapshot.baseline.averageBurstLength))
                    MetricCard(title: "Last included event", value: timestampLabel(state.profileSnapshot.today.lastIncludedEventAt), footnote: "Baseline days: \(state.profileSnapshot.baselineDayCount)")
                    MetricCard(title: "Confidence", value: confidenceLabel, footnote: confidenceFootnote)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var insightCard: some View {
        GroupBox("What Changed") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(state.profileSnapshot.insights) { insight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.headline)
                        Text(insight.detail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Divider()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weaknessesCard: some View {
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

    private var practicePlanCard: some View {
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
                } else {
                    Text("No primary practice session is recommended yet. The app needs a little more evidence before it should prescribe a focused drill.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var skillStateCard: some View {
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

    private var rhythmAndFlowRow: some View {
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

    private var accuracyAndReachRow: some View {
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

    private var exclusionsCard: some View {
        GroupBox("Excluded Apps") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Built-in exclusions still protect obvious defaults like Terminal and some password / remote desktop tools. You can add your own manual exclusions by bundle ID or from the last app Typing Lens observed.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let note = state.exclusionStatus.note {
                    Text(note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                GroupBox("Add Manual Exclusions") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type in another app, return here, and add the last observed app. If needed, you can also paste a bundle identifier manually.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        KeyValueRow(label: "Last observed app", value: state.exclusionStatus.lastObservedApplication?.displayName ?? "No recent app observed yet")
                        KeyValueRow(label: "Bundle ID", value: state.exclusionStatus.lastObservedApplication?.bundleIdentifier ?? "No bundle identifier observed yet")

                        HStack(spacing: 12) {
                            Button("Exclude Last Observed App") {
                                captureService.addManualExclusionFromLastObservedApp()
                            }
                            .disabled(
                                state.exclusionStatus.lastObservedApplication?.bundleIdentifier == nil
                                    || state.exclusionStatus.isLastObservedApplicationExcluded
                            )

                            if state.exclusionStatus.isLastObservedApplicationExcluded {
                                Text("Last observed app is already excluded.")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 12) {
                            TextField("com.example.app", text: $manualBundleIdentifier)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 320)
                                .onSubmit(addManualBundleIdentifier)

                            Button("Add Bundle ID") {
                                addManualBundleIdentifier()
                            }
                            .disabled(manualBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 16) {
                    ExclusionListCard(
                        title: "Built-in exclusions",
                        subtitle: "Default safety list shipped with this MVP.",
                        applications: state.exclusionStatus.builtInExcludedApplications
                    )

                    ManualExclusionListCard(
                        title: "Manual exclusions",
                        subtitle: "Your locally configured bundle IDs.",
                        applications: state.exclusionStatus.manualExcludedApplications,
                        onRemove: { application in
                            captureService.removeManualExclusion(bundleIdentifier: application.bundleIdentifier)
                        }
                    )
                }

                KeyValueRow(label: "Excluded event count", value: "\(state.exclusionStatus.excludedEventCount)")
                KeyValueRow(label: "Last excluded app", value: state.exclusionStatus.lastExcludedAppName ?? "None yet")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var trustAndTapCard: some View {
        GroupBox("Trust + Tap Health") {
            VStack(alignment: .leading, spacing: 12) {
                KeyValueRow(label: "Capture state", value: captureLabel)
                KeyValueRow(label: "Tap installed", value: state.tapHealth.isInstalled ? "Yes" : "No")
                KeyValueRow(label: "Tap enabled", value: state.tapHealth.isEnabled ? "Yes" : "No")
                KeyValueRow(label: "Last observed key event", value: timestampLabel(state.tapHealth.lastEventAt))
                KeyValueRow(label: "Tap note", value: state.tapHealth.statusNote)
                KeyValueRow(label: "Secure input", value: secureInputLabel)
                KeyValueRow(label: "Profile store", value: state.trustState.profileStorePath)
                KeyValueRow(label: "Manual exclusions store", value: state.trustState.manualExclusionsStorePath)
                KeyValueRow(label: "Stores raw text", value: state.trustState.storesRawText ? "Yes" : "No")
                KeyValueRow(label: "Stores literal n-grams", value: state.trustState.storesLiteralNGrams ? "Yes" : "No")
                KeyValueRow(label: "Trust note", value: state.trustState.note)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var advancedDiagnosticsCard: some View {
        GroupBox {
            DisclosureGroup("Advanced diagnostics (transient only)", isExpanded: $isShowingAdvancedDiagnostics) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("These views are intentionally demoted. They exist to help local analysis, but they are not the long-term stored profile and should not be treated as the main product truth.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .top, spacing: 16) {
                        NGramInsightsCard(
                            title: "Transient top bigrams",
                            subtitle: "Available for local inspection only. Not persisted in the M4 learner model.",
                            metrics: state.advancedDiagnostics.topBigrams(limit: 6)
                        )

                        NGramInsightsCard(
                            title: "Transient top trigrams",
                            subtitle: "Secondary diagnostics only. Not persisted in the M4 learner model.",
                            metrics: state.advancedDiagnostics.topTrigrams(limit: 6)
                        )
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    #if DEBUG
    private var debugOnlyCard: some View {
        GroupBox {
            DisclosureGroup("Debug only: transient raw preview (DEBUG builds only)", isExpanded: $isShowingDebug) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This preview exists only to validate local capture during development. It stays in RAM only, is absent from the persisted profile, and should not appear in release-oriented builds.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView {
                        Text(state.debugPreviewText.isEmpty ? "No transient debug text captured yet." : state.debugPreviewText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                            .padding(12)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        if state.recentEvents.isEmpty {
                            Text("No recent transient events yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(state.recentEvents) { event in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                        .frame(width: 110, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                    Text(event.kind)
                                        .frame(width: 100, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                    Text(event.renderedValue)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(width: 120, alignment: .leading)
                                    Text("keyCode \(event.keyCode)")
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 3)

                                Divider()
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }
    #endif

    private var permissionLabel: String {
        switch state.permissionState {
        case .unknown:
            return "unknown"
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        }
    }

    private var captureLabel: String {
        switch state.captureActivityState {
        case .needsPermission:
            return "needs permission"
        case .permissionDenied:
            return "permission denied"
        case .recording:
            return "recording"
        case .paused:
            return "paused"
        case .secureInputBlocked:
            return "secure input blocked"
        case .tapUnavailable:
            return "tap unavailable"
        }
    }

    private var baselineLabel: String {
        switch state.profileSnapshot.confidence {
        case .warmingUp:
            return "warming up"
        case .buildingBaseline:
            return "building"
        case .ready:
            return "ready"
        }
    }

    private var confidenceLabel: String {
        switch state.profileSnapshot.confidence {
        case .warmingUp:
            return "Warming up"
        case .buildingBaseline:
            return "Building baseline"
        case .ready:
            return "Ready"
        }
    }

    private var confidenceFootnote: String {
        switch state.profileSnapshot.confidence {
        case .warmingUp:
            return "Use a few non-excluded sessions first"
        case .buildingBaseline:
            return "Needs a few active days for stable deltas"
        case .ready:
            return "Baseline days: \(state.profileSnapshot.baselineDayCount)"
        }
    }

    private var secureInputLabel: String {
        switch state.trustState.secureInputState {
        case .unavailable:
            return "not surfaced"
        case .disabled:
            return "not active"
        case .enabled:
            return "active"
        }
    }

    private var permissionTint: Color {
        switch state.permissionState {
        case .unknown:
            return .orange
        case .granted:
            return .green
        case .denied:
            return .red
        }
    }

    private var captureTint: Color {
        switch state.captureActivityState {
        case .needsPermission:
            return .gray
        case .permissionDenied:
            return .red
        case .recording:
            return .green
        case .paused:
            return .orange
        case .secureInputBlocked:
            return .yellow
        case .tapUnavailable:
            return .red
        }
    }

    private var baselineTint: Color {
        switch state.profileSnapshot.confidence {
        case .warmingUp:
            return .gray
        case .buildingBaseline:
            return .orange
        case .ready:
            return .green
        }
    }

    private var secureInputTint: Color {
        switch state.trustState.secureInputState {
        case .unavailable:
            return .gray
        case .disabled:
            return .green
        case .enabled:
            return .yellow
        }
    }

    private var prioritizedStudentStates: [StudentSkillState] {
        state.learningModel.studentStates
            .sorted {
                averageSkillValue($0.current) < averageSkillValue($1.current)
            }
            .prefix(6)
            .map { $0 }
    }

    private func addManualBundleIdentifier() {
        let trimmedValue = manualBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return }
        captureService.addManualExclusion(bundleIdentifier: trimmedValue)
        manualBundleIdentifier = ""
    }

    private func percentString(_ value: Double) -> String {
        "\(String(format: "%.1f", value * 100))%"
    }

    private func decimalString(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func millisecondsString(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.0f ms", value)
    }

    private func timestampLabel(_ date: Date?) -> String {
        guard let date else {
            return "No data yet"
        }
        return date.formatted(date: .omitted, time: .standard)
    }

    private func baselineFootnote(for baselineValue: Double) -> String {
        baselineValue > 0 ? "Baseline \(String(format: "%.1f", baselineValue))" : "Baseline building"
    }

    private func averageSkillValue(_ value: SkillDimensionState) -> Double {
        (value.control + value.automaticity + value.consistency + value.stability) / 4.0
    }

    private func skillValueLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func displayName(for confidence: WeaknessConfidence) -> String {
        switch confidence {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    private func displayName(for severity: WeaknessSeverity) -> String {
        switch severity {
        case .mild:
            return "Mild"
        case .moderate:
            return "Moderate"
        case .strong:
            return "Strong"
        }
    }

    private func displayName(for family: PracticeDrillFamily) -> String {
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
}

private struct StatusPill: View {
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

private struct MetricCard: View {
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

private struct StatsRow {
    let title: String
    let today: TimingStatsSummary
    let baseline: TimingStatsSummary
}

private struct StatsGrid: View {
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

private struct HistogramCard: View {
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

private struct NGramInsightsCard: View {
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

private struct ExclusionListCard: View {
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

private struct ManualExclusionListCard: View {
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

private struct KeyValueRow: View {
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
    }
}
