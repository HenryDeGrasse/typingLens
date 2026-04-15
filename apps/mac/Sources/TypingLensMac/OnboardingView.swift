import Capture
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var captureService: CaptureService
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard.badge.eye")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Typing Lens")
                        .font(.title2.weight(.semibold))
                    Text("A local-first typing coach. Nothing leaves your Mac.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                onboardingRow(
                    icon: "lock.shield",
                    title: "Privacy by design",
                    detail: "Typing Lens never stores raw text, prompt responses, or event streams. It saves only aggregate timing summaries and drill metrics, locally."
                )
                onboardingRow(
                    icon: "ear",
                    title: "Listen-only keyboard tap",
                    detail: "macOS will ask you to grant Input Monitoring on the next step. Typing Lens uses this to observe key timing — it cannot block, modify, or inject keystrokes."
                )
                onboardingRow(
                    icon: "list.bullet.rectangle",
                    title: "Excluded apps",
                    detail: "Password fields and a built-in deny list are skipped automatically. You can add or remove apps yourself in the Trust panel."
                )
                onboardingRow(
                    icon: "chart.bar.doc.horizontal",
                    title: "Deterministic coaching",
                    detail: "Drills are recommended by an explainable rule engine, not opaque AI. You can see exactly which signals fired."
                )
            }

            Spacer(minLength: 0)

            HStack {
                Button("Open Privacy Docs") {
                    if let url = URL(string: "https://github.com/anthropics/claude-code") {
                        // No URL outbound in the app; just close — keeping link intentionally inert in tester build.
                        _ = url
                    }
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Skip for now") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Closes this onboarding without granting permissions yet")

                Button("Grant Input Monitoring") {
                    captureService.requestPermissionFlow()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens System Settings to grant Input Monitoring access")
            }
        }
        .padding(28)
        .frame(width: 540, height: 480)
    }

    private func onboardingRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}
