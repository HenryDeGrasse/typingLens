import AppKit
import Capture
import Core
import SwiftUI

struct MenuBarExtraView: View {
    @ObservedObject var captureService: CaptureService
    @Environment(\.openWindow) private var openWindow

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Typing Lens")
                    .font(.headline)
                Label(captureLabel, systemImage: menuBarSymbolName)
                    .foregroundStyle(captureTint)
                    .accessibilityLabel("Capture status: \(captureLabel)")
                Text(permissionLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Baseline: \(baselineLine)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .contain)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                MenuMetricRow(label: "Included keydowns", value: "\(state.profileSnapshot.today.includedKeyDownCount)")
                MenuMetricRow(label: "Backspace density", value: percentString(state.profileSnapshot.today.backspaceDensity))
                MenuMetricRow(label: "Sessions", value: "\(state.profileSnapshot.today.sessionCount)")
                MenuMetricRow(label: "Excluded events", value: "\(state.profileSnapshot.today.excludedEventCount)")
            }

            if let primaryWeakness = state.learningModel.primaryWeakness {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current focus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(primaryWeakness.title)
                        .font(.subheadline.weight(.medium))
                    Text(displayName(for: primaryWeakness.recommendedDrill))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastObserved = state.exclusionStatus.lastObservedApplication {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last observed app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastObserved.displayName)
                        .font(.subheadline.weight(.medium))
                    Text(lastObserved.bundleIdentifier ?? "No bundle identifier")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            Button("Open Typing Lens") {
                openMainWindow()
            }

            Button(state.isPaused ? "Resume Capture" : "Pause Capture") {
                captureService.togglePause()
            }
            .disabled(state.permissionState != .granted || !state.tapHealth.isInstalled)
            .accessibilityHint(state.isPaused ? "Resumes the listen-only keyboard tap" : "Pauses the listen-only keyboard tap")

            Button("Exclude Last Observed App") {
                captureService.addManualExclusionFromLastObservedApp()
            }
            .disabled(
                state.exclusionStatus.lastObservedApplication?.bundleIdentifier == nil
                    || state.exclusionStatus.isLastObservedApplicationExcluded
            )
            .accessibilityHint("Adds the most recently observed app to your manual exclusion list")

            Button("Re-check Access") {
                captureService.refreshPermissionState()
                captureService.startTapIfPossible()
            }
            .accessibilityHint("Re-queries macOS Input Monitoring permission and re-installs the tap if granted")

            Button("Open Input Monitoring Settings") {
                captureService.openInputMonitoringSettings()
            }
            .accessibilityHint("Opens System Settings to manage Input Monitoring permission")

            Button("Inspect Local Data...") {
                openWindow(id: "data-inspector")
                NSApp.activate(ignoringOtherApps: true)
            }
            .accessibilityHint("Opens a window to inspect, export, or delete locally persisted files")

            Divider()

            Button("Quit Typing Lens") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(minWidth: 300)
    }

    private var permissionLine: String {
        switch state.permissionState {
        case .unknown:
            return "Permission: unknown"
        case .granted:
            return "Permission: granted"
        case .denied:
            return "Permission: denied"
        }
    }

    private var baselineLine: String {
        switch state.profileSnapshot.confidence {
        case .warmingUp:
            return "warming up"
        case .buildingBaseline:
            return "building"
        case .ready:
            return "ready"
        }
    }

    private var captureLabel: String {
        switch state.captureActivityState {
        case .needsPermission:
            return "Needs permission"
        case .permissionDenied:
            return "Permission denied"
        case .recording:
            return "Recording"
        case .paused:
            return "Paused"
        case .secureInputBlocked:
            return "Secure input blocked"
        case .tapUnavailable:
            return "Tap unavailable"
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

    private var menuBarSymbolName: String {
        switch state.captureActivityState {
        case .needsPermission:
            return "circle.dashed"
        case .permissionDenied:
            return "hand.raised.circle"
        case .recording:
            return "record.circle"
        case .paused:
            return "pause.circle"
        case .secureInputBlocked:
            return "lock.circle"
        case .tapUnavailable:
            return "exclamationmark.triangle"
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func percentString(_ value: Double) -> String {
        "\(String(format: "%.1f", value * 100))%"
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

private struct MenuMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.medium))
        }
    }
}
