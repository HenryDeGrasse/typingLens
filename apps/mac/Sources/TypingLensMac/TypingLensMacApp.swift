import Capture
import SwiftUI

private let onboardingCompletedDefaultsKey = "ai.gauntlet.typinglens.onboardingCompleted"

@main
struct TypingLensMacApp: App {
    @StateObject private var captureService = CaptureService()
    @State private var isShowingOnboarding: Bool = !UserDefaults.standard.bool(forKey: onboardingCompletedDefaultsKey)

    var body: some Scene {
        WindowGroup("Typing Lens", id: "main") {
            ContentView(captureService: captureService)
                .frame(minWidth: 920, minHeight: 720)
                .sheet(isPresented: $isShowingOnboarding, onDismiss: persistOnboardingDismissal) {
                    OnboardingView(captureService: captureService, isPresented: $isShowingOnboarding)
                }
        }
        .windowResizability(.contentSize)

        WindowGroup("Local Data", id: "data-inspector") {
            DataInspectorView(captureService: captureService)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 640, height: 460)

        MenuBarExtra {
            MenuBarExtraView(captureService: captureService)
        } label: {
            Image(systemName: menuBarSymbolName)
                .help("Typing Lens: \(menuBarStatusLabel)")
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarStatusLabel: String {
        switch captureService.state.captureActivityState {
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

    private func persistOnboardingDismissal() {
        UserDefaults.standard.set(true, forKey: onboardingCompletedDefaultsKey)
    }

    private var menuBarSymbolName: String {
        switch captureService.state.captureActivityState {
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
}
