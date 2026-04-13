import Capture
import Core
import SwiftUI

struct ContentView: View {
    @ObservedObject var captureService: CaptureService
    @State private var isShowingDebug = false
    @State private var manualBundleIdentifier = ""

    // Future seam: the macOS app owns presentation only; the aggregate state below is
    // the product-facing source of truth for future diagnostics and coaching flows.
    private var state: CaptureDashboardState {
        captureService.state
    }

    private let summaryColumns = [
        GridItem(.flexible(minimum: 160), spacing: 16),
        GridItem(.flexible(minimum: 160), spacing: 16),
        GridItem(.flexible(minimum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                statusOverview
                controlsCard
                whatTypingLensKnowsCard
                ngramInsightsRow
                exclusionsCard
                tapHealthCard
                debugOnlyCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heroCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Typing Lens · M2 Aggregate Diagnostics Prototype")
                    .font(.system(size: 28, weight: .bold))

                Text("This iteration keeps the same listen-only keyboard permission flow, but shifts the product UI toward privacy-safer aggregates. Typing Lens now emphasizes counts, backspace density, and top n-grams instead of raw captured text. Any raw preview remains debug-only, transient, and in memory only.")
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
                    StatusPill(title: "Exclusions", value: "\(state.exclusionStatus.excludedAppDisplayNames.count) apps", tint: .blue)
                }

                Text(state.guidanceText)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("What this MVP keeps: aggregate typing metrics, exclusion counts, and tap health. What it does not persist: raw typed text, raw event streams, or full timing sequences.")
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

                Button("Reset Aggregates + Debug State") {
                    captureService.resetCaptureData()
                }

                Spacer()

                Text("Aggregate JSON may persist locally · Raw debug preview never does")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var whatTypingLensKnowsCard: some View {
        GroupBox("What Typing Lens Knows") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Typing Lens is observing typing activity to build a small aggregate profile for this MVP. The app is not trying to reconstruct full raw text in the main product UI.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 16) {
                    MetricCard(title: "Observed keydowns", value: "\(state.aggregateMetrics.totalKeyDownEvents)")
                    MetricCard(title: "Backspaces", value: "\(state.aggregateMetrics.totalBackspaces)")
                    MetricCard(title: "Backspace density", value: percentString(state.aggregateMetrics.backspaceDensity))
                    MetricCard(title: "Excluded events", value: "\(state.aggregateMetrics.excludedEventCount)")
                    MetricCard(title: "Last included event", value: timestampLabel(state.aggregateMetrics.lastIncludedEventAt))
                    MetricCard(title: "Last aggregate update", value: timestampLabel(state.aggregateMetrics.lastUpdatedAt))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ngramInsightsRow: some View {
        HStack(alignment: .top, spacing: 16) {
            NGramInsightsCard(
                title: "Top bigrams",
                subtitle: "Counts and simple average latency between two included tokens.",
                metrics: state.aggregateMetrics.topBigrams(limit: 6)
            )

            NGramInsightsCard(
                title: "Top trigrams",
                subtitle: "Counts and simple end-to-end latency across a three-token window.",
                metrics: state.aggregateMetrics.topTrigrams(limit: 6)
            )
        }
    }

    private var exclusionsCard: some View {
        GroupBox("Excluded Apps") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Built-in exclusions still protect obvious defaults like Terminal and some password / remote desktop tools. You can now add your own manual exclusions by bundle ID or from the last app Typing Lens observed.")
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
                        Text("The easiest path is: type in another app, return here, and add the last observed app. If needed, you can also paste a bundle identifier manually.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        KeyValueRow(
                            label: "Last observed app",
                            value: state.exclusionStatus.lastObservedApplication?.displayName ?? "No recent app observed yet"
                        )
                        KeyValueRow(
                            label: "Bundle ID",
                            value: state.exclusionStatus.lastObservedApplication?.bundleIdentifier ?? "No bundle identifier observed yet"
                        )

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

    private var tapHealthCard: some View {
        GroupBox("Tap Health") {
            VStack(alignment: .leading, spacing: 10) {
                KeyValueRow(label: "Capture state", value: captureLabel)
                KeyValueRow(label: "Installed", value: state.tapHealth.isInstalled ? "Yes" : "No")
                KeyValueRow(label: "Enabled", value: state.tapHealth.isEnabled ? "Yes" : "No")
                KeyValueRow(label: "Last observed keydown", value: timestampLabel(state.tapHealth.lastEventAt))
                KeyValueRow(label: "Status note", value: state.tapHealth.statusNote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var debugOnlyCard: some View {
        GroupBox {
            DisclosureGroup("Debug only: transient raw preview", isExpanded: $isShowingDebug) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This section exists only to help local development prove the tap is observing events. It stays in RAM only, is intentionally demoted below the aggregate view, and is never persisted by the aggregate store.")
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
                                        .frame(width: 90, alignment: .leading)
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
        case .tapUnavailable:
            return "tap unavailable"
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
        case .tapUnavailable:
            return .red
        }
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

    private func timestampLabel(_ date: Date?) -> String {
        guard let date else {
            return "No data yet"
        }
        return date.formatted(date: .omitted, time: .standard)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    Text("No aggregate n-grams yet. Type in a non-excluded app to build some signal.")
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
                .frame(width: 170, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
