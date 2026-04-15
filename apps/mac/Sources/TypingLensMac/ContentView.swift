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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                statusOverview
                controlsCard
                profileOverviewCard
                insightCard
                WeaknessesCard(captureService: captureService)
                PracticePlanCard(captureService: captureService)
                PracticeRuntimeCard(captureService: captureService)
                PracticeHistoryCard(captureService: captureService)
                SkillStateCard(captureService: captureService)
                RhythmAndFlowRow(captureService: captureService)
                AccuracyAndReachRow(captureService: captureService)
                ExclusionsCard(captureService: captureService, manualBundleIdentifier: $manualBundleIdentifier)
                TrustAndTapCard(captureService: captureService, captureLabel: captureLabel, secureInputLabel: secureInputLabel)
                AdvancedDiagnosticsCard(captureService: captureService, isShowingAdvancedDiagnostics: $isShowingAdvancedDiagnostics)
                #if DEBUG
                DebugOnlyCard(captureService: captureService, isShowingDebug: $isShowingDebug)
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
                    .accessibilityHint("Triggers macOS Input Monitoring permission prompt and opens Settings if needed")

                    Button("Re-check Access") {
                        captureService.refreshPermissionState()
                        captureService.startTapIfPossible()
                    }
                    .accessibilityHint("Re-queries permission state and re-installs the listen-only tap")

                    Button("Open Input Monitoring Settings") {
                        captureService.openInputMonitoringSettings()
                    }
                    .accessibilityHint("Opens System Settings to manage Input Monitoring permission")
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
                .accessibilityHint(state.isPaused ? "Resumes the listen-only keyboard tap" : "Pauses the listen-only keyboard tap")

                Button("Reset Profile + Diagnostics") {
                    captureService.resetCaptureData()
                }
                .accessibilityHint("Clears today's typing profile, diagnostics, and any in-progress drill state")

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

                if state.profileSnapshot.today.includedKeyDownCount == 0 {
                    EmptyStateBanner(
                        symbol: "keyboard",
                        title: "No typing observed today yet",
                        detail: "Type in any non-excluded app and these tiles will start filling in. The first few hundred characters establish today’s shape; a few days build the baseline."
                    )
                }

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
                if state.profileSnapshot.insights.isEmpty {
                    EmptyStateBanner(
                        symbol: "sparkles",
                        title: "No deltas yet",
                        detail: "Insights surface once Typing Lens has at least one full day of profile data to compare against."
                    )
                } else {
                    ForEach(state.profileSnapshot.insights) { insight in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.headline)
                            Text(insight.detail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(insight.title). \(insight.detail)")
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

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
}
