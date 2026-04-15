import Capture
import Core
import SwiftUI

struct PracticeRuntimeCard: View {
    @ObservedObject var captureService: CaptureService

    private var state: CaptureDashboardState {
        captureService.state
    }

    var body: some View {
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
                            .accessibilityHint("Pauses the active drill timer")
                        case .paused:
                            Button("Resume Session") {
                                captureService.resumePracticeSession()
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityHint("Resumes the paused drill timer")
                        case .completed, .canceled:
                            if state.learningModel.recommendedSession != nil {
                                Button("Run Again") {
                                    captureService.startRecommendedPracticeSession()
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityHint("Starts a fresh recommended practice session")
                            }
                        case .idle:
                            EmptyView()
                        }

                        if state.practiceRuntime.status == .running || state.practiceRuntime.status == .paused {
                            Button("Skip Prompt") {
                                captureService.skipPracticePrompt()
                            }
                            .accessibilityHint("Skips the current prompt and moves to the next one in the rotation")

                            Button("Next Block") {
                                captureService.advancePracticeBlock()
                            }
                            .accessibilityHint("Ends the current block early and advances to the next block")

                            Button("End Session") {
                                captureService.cancelPracticeSession()
                            }
                            .accessibilityHint("Cancels the entire practice session and records what completed so far")
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
}
