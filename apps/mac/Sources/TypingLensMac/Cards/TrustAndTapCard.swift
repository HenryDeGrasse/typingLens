import Capture
import Core
import SwiftUI

struct ExclusionsCard: View {
    @ObservedObject var captureService: CaptureService
    @Binding var manualBundleIdentifier: String

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
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

    private func addManualBundleIdentifier() {
        let trimmedValue = manualBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return }
        captureService.addManualExclusion(bundleIdentifier: trimmedValue)
        manualBundleIdentifier = ""
    }
}

struct TrustAndTapCard: View {
    @ObservedObject var captureService: CaptureService
    let captureLabel: String
    let secureInputLabel: String

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
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

                if let persistenceWarning = state.trustState.persistenceWarning {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(persistenceWarning)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Persistence warning: \(persistenceWarning)")
                }

                GroupBox("Local storage matrix") {
                    VStack(alignment: .leading, spacing: 10) {
                        KeyValueRow(label: "JSON", value: "Typing profile summaries + manual exclusions")
                        KeyValueRow(label: "SQLite", value: "Aggregate-only coaching evidence, sessions, evaluations, transfer tickets, and learner-state updates")
                        KeyValueRow(label: "Never stored", value: "Raw typed text, raw practice responses, prompt text, raw event streams, and debug raw preview text")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AdvancedDiagnosticsCard: View {
    @ObservedObject var captureService: CaptureService
    @Binding var isShowingAdvancedDiagnostics: Bool

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
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
}

#if DEBUG
struct DebugOnlyCard: View {
    @ObservedObject var captureService: CaptureService
    @Binding var isShowingDebug: Bool

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
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
}
#endif
