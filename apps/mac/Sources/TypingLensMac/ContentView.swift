import Capture
import Core
import SwiftUI

struct ContentView: View {
    @ObservedObject var captureService: CaptureService

    // Future seam: the macOS app owns presentation only; later engineers can replace
    // sections below with richer flows without moving capture code out of the package.
    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                statusOverview
                controlsCard
                metricsRow
                tapHealthCard
                debugPreviewCard
                recentEventsCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heroCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Typing Lens · M1 Trustable Capture Demo")
                    .font(.system(size: 28, weight: .bold))

                Text("This first milestone is intentionally tiny: it asks for Input Monitoring, installs a listen-only keyboard event tap after approval, and shows live debug-only capture state. Raw captured text stays in memory only and is never written to disk by this app.")
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
                    StatusPill(title: "Tap", value: state.tapHealth.isInstalled ? "installed" : "not installed", tint: state.tapHealth.isInstalled ? .green : .gray)
                }

                Text(state.guidanceText)
                    .foregroundStyle(.primary)
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

                Button("Clear Debug Buffer + Counters") {
                    captureService.resetDebugData()
                }

                Spacer()

                Text("No disk persistence · No network activity")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 16) {
            MetricCard(title: "Total keydown events", value: "\(state.counters.totalKeyDownEvents)")
            MetricCard(title: "Total backspaces", value: "\(state.counters.totalBackspaces)")
            MetricCard(title: "Last event", value: lastEventLabel)
        }
    }

    private var tapHealthCard: some View {
        GroupBox("Tap Health") {
            VStack(alignment: .leading, spacing: 10) {
                KeyValueRow(label: "Installed", value: state.tapHealth.isInstalled ? "Yes" : "No")
                KeyValueRow(label: "Enabled", value: state.tapHealth.isEnabled ? "Yes" : "No")
                KeyValueRow(label: "Last event timestamp", value: lastEventLabel)
                KeyValueRow(label: "Status note", value: state.tapHealth.statusNote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var debugPreviewCard: some View {
        GroupBox("Debug-Only In-Memory Preview") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This preview exists only to prove the listen-only tap is observing keys. It stays in RAM only and must not be used as a persistent log.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    Text(state.debugPreviewText.isEmpty ? "No captured debug text yet." : state.debugPreviewText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                        .padding(12)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recentEventsCard: some View {
        GroupBox("Recent Captured Events") {
            VStack(alignment: .leading, spacing: 8) {
                if state.recentEvents.isEmpty {
                    Text("No recent events yet. Grant access, type in another app, then come back here.")
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
                                .frame(width: 140, alignment: .leading)
                            Text("keyCode \(event.keyCode)")
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)

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
        if state.permissionState != .granted {
            return "waiting"
        }
        return state.isPaused ? "paused" : "live"
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
        if state.permissionState != .granted {
            return .gray
        }
        return state.isPaused ? .orange : .green
    }

    private var lastEventLabel: String {
        guard let lastEventAt = state.tapHealth.lastEventAt else {
            return "No events yet"
        }
        return lastEventAt.formatted(date: .omitted, time: .standard)
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

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .frame(width: 150, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
