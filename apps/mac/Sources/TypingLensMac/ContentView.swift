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
                practiceRuntimeCard
                practiceHistoryCard
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

    private var practiceRuntimeCard: some View {
        GroupBox("Interactive Practice Runtime") {
            VStack(alignment: .leading, spacing: 14) {
                Text("This runtime turns the recommended plan into an in-app session. Prompt text stays transient, is never written to disk, and does not feed the passive typing profile while a practice session is active.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if state.practiceRuntime.status == .idle {
                    if state.learningModel.recommendedSession != nil {
                        HStack(spacing: 12) {
                            Button("Start Recommended Session") {
                                captureService.startRecommendedPracticeSession()
                            }
                            .buttonStyle(.borderedProminent)

                            Text("Typing inside the focus pad is app-local and transient.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No recommended session is ready yet. Build more passive evidence first, then start a guided session from here.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(state.practiceRuntime.sessionTitle ?? "Practice session")
                                .font(.title3.weight(.semibold))
                            Text(displayName(for: state.practiceRuntime.status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let rationale = state.practiceRuntime.rationale {
                                Text(rationale)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                        Button(state.learningModel.recommendedSession != nil ? "Restart Session" : "End") {
                            if state.learningModel.recommendedSession != nil {
                                captureService.startRecommendedPracticeSession()
                            } else {
                                captureService.cancelPracticeSession()
                            }
                        }
                    }

                    if let activeBlockIndex = state.practiceRuntime.activeBlockIndex,
                       let activeBlockTitle = state.practiceRuntime.activeBlockTitle {
                        Text("Block \(activeBlockIndex + 1) of \(state.practiceRuntime.interactiveBlockCount) · \(activeBlockTitle)")
                            .font(.headline)
                        if let activeBlockDetail = state.practiceRuntime.activeBlockDetail {
                            Text(activeBlockDetail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 16) {
                        MetricCard(title: "Time left", value: timerString(state.practiceRuntime.remainingSeconds), footnote: "Elapsed \(timerString(state.practiceRuntime.elapsedSeconds))")
                        MetricCard(title: "Current accuracy", value: percentString(state.practiceRuntime.currentAccuracy), footnote: "Correct \(state.practiceRuntime.correctCharacterCount) · Incorrect \(state.practiceRuntime.incorrectCharacterCount)")
                        MetricCard(title: "Prompts cleared", value: "\(state.practiceRuntime.completedPromptCount)", footnote: "Backspaces \(state.practiceRuntime.backspaceCount)")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Focus pad")
                            .font(.headline)
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accentColor.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 10) {
                                if let prompt = state.practiceRuntime.activePrompt {
                                    Text("Prompt")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(prompt.text)
                                        .font(.system(.title3, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if let cue = prompt.cue {
                                        Text(cue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("No active prompt right now.")
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                Text("Typed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(state.practiceRuntime.typedText.isEmpty ? "Start typing here…" : state.practiceRuntime.typedText)
                                    .font(.system(.title3, design: .monospaced))
                                    .foregroundStyle(state.practiceRuntime.typedText.isEmpty ? .secondary : .primary)

                                if !state.practiceRuntime.upcomingPrompts.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Up next")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        ForEach(state.practiceRuntime.upcomingPrompts.dropFirst()) { prompt in
                                            Text(prompt.text)
                                                .font(.system(.callout, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(18)

                            PracticeKeyCaptureView(
                                isActive: state.practiceRuntime.status == .running,
                                onCharacter: { character in
                                    captureService.handlePracticeCharacter(character)
                                },
                                onBackspace: {
                                    captureService.handlePracticeBackspace()
                                },
                                onDeviceClassObserved: { deviceClass in
                                    captureService.observePracticeDeviceClass(deviceClass)
                                }
                            )
                        }
                        .frame(minHeight: 220)
                    }

                    HStack(spacing: 12) {
                        switch state.practiceRuntime.status {
                        case .running:
                            Button("Pause Session") {
                                captureService.pausePracticeSession()
                            }
                        case .paused:
                            Button("Resume Session") {
                                captureService.resumePracticeSession()
                            }
                            .buttonStyle(.borderedProminent)
                        case .completed, .canceled:
                            if state.learningModel.recommendedSession != nil {
                                Button("Run Again") {
                                    captureService.startRecommendedPracticeSession()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        case .idle:
                            EmptyView()
                        }

                        if state.practiceRuntime.status == .running || state.practiceRuntime.status == .paused {
                            Button("Skip Prompt") {
                                captureService.skipPracticePrompt()
                            }

                            Button("Next Block") {
                                captureService.advancePracticeBlock()
                            }

                            Button("End Session") {
                                captureService.cancelPracticeSession()
                            }
                        }
                    }

                    Text(state.practiceRuntime.note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !state.practiceRuntime.completedBlocks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session summary")
                                .font(.headline)
                            ForEach(state.practiceRuntime.completedBlocks) { blockResult in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(blockResult.title)
                                            .font(.headline)
                                        Spacer()
                                        Text(percentString(blockResult.accuracy))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Elapsed \(timerString(blockResult.elapsedSeconds)) · Prompts \(blockResult.completedPromptCount) · Backspaces \(blockResult.backspaceCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(blockResult.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Divider()
                            }
                        }
                    }

                    if let followUp = state.practiceRuntime.followUp {
                        Text(followUp)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let passiveTransferNote = state.practiceRuntime.passiveTransferNote {
                        Text("Later passive transfer check: \(passiveTransferNote)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var practiceHistoryCard: some View {
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

                if !state.practiceHistory.recentDecisions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent recommendation decisions")
                            .font(.headline)
                        ForEach(state.practiceHistory.recentDecisions.prefix(4)) { decision in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(displaySkillTitle(for: decision.selectedSkillID)) · \(displayName(for: decision.selectedWeakness))")
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
                        ForEach(state.practiceHistory.pendingTransferTickets) { ticket in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(displaySkillTitle(for: ticket.skillID)) · \(displayName(for: ticket.weakness))")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(displayName(for: ticket.status))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(transferTicketStatusLabel(ticket))
                                    .font(.caption)
                                Text("Layout \(ticket.keyboardLayoutID) · Device \(ticket.keyboardDeviceClass)")
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
                                    Text("\(displaySkillTitle(for: session.selectedSkillID)) · \(displayName(for: session.selectedWeakness))")
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
                                    Text("\(displaySkillTitle(for: update.skillID)) · \(displayName(for: update.sourceType))")
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
                KeyValueRow(label: "Keyboard layout", value: "\(state.trustState.keyboardLayoutName) (\(state.trustState.keyboardLayoutID))")
                KeyValueRow(label: "Keyboard device class", value: state.trustState.keyboardDeviceClass)
                KeyValueRow(label: "Profile store", value: state.trustState.profileStorePath)
                KeyValueRow(label: "Manual exclusions store", value: state.trustState.manualExclusionsStorePath)
                KeyValueRow(label: "Evidence store", value: state.trustState.evidenceStorePath)
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

    private var manualPracticeFamilies: [PracticeDrillFamily] {
        [.sameHandLadders, .reachAndReturn, .alternationRails, .accuracyReset, .meteredFlow]
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

    private func dateTimeLabel(_ date: Date?) -> String {
        guard let date else {
            return "No data yet"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
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

    private func displaySkillTitle(for skillID: String) -> String {
        state.learningModel.studentStates.first(where: { $0.id == skillID })?.title
            ?? state.learningModel.skillNodes.first(where: { $0.id == skillID })?.name
            ?? skillID
    }

    private func displayName(for weakness: WeaknessCategory) -> String {
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

    private func displayName(for status: TargetConfirmationStatus) -> String {
        switch status {
        case .confirmed:
            return "Confirmed"
        case .unconfirmed:
            return "Unconfirmed"
        case .inconclusive:
            return "Inconclusive"
        }
    }

    private func displayName(for outcome: PracticeEvaluationOutcome?) -> String {
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

    private func displayName(for status: PassiveTransferTicketStatus) -> String {
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

    private func displayName(for mode: PracticeUpdateMode) -> String {
        switch mode {
        case .shadow:
            return "Shadow only"
        case .applied:
            return "Applied"
        }
    }

    private func displayName(for type: PracticeEvaluationType) -> String {
        switch type {
        case .postCheck:
            return "Post-check"
        case .nearTransferCheck:
            return "Near-transfer"
        }
    }

    private func displayName(for source: LearnerStateUpdateSource) -> String {
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

    private func displayName(for kind: PracticeBlockKind) -> String {
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

    private func displayName(for sufficiency: PracticeSufficiencyStatus) -> String {
        switch sufficiency {
        case .sufficient:
            return "Sufficient"
        case .insufficient:
            return "Insufficient"
        }
    }

    private func transferTicketStatusLabel(_ ticket: PassiveTransferTicketRecord) -> String {
        let now = Date()
        if now < ticket.earliestEligibleAt {
            return "Waiting for cooldown before passive transfer measurement. Eligible at \(dateTimeLabel(ticket.earliestEligibleAt))."
        }
        return "Waiting for at least \(ticket.requiredPostSliceCount) compatible passive slices before \(dateTimeLabel(ticket.expiresAt))."
    }

    private func formattedReasonCodes(_ codes: [String]) -> String {
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

    private func signedPercent(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
    }

    private func displayName(for status: PracticeRuntimeStatus) -> String {
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

    private func timerString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
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
