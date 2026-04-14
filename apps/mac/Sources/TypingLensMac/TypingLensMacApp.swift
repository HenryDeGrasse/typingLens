import Capture
import SwiftUI

@main
struct TypingLensMacApp: App {
    @StateObject private var captureService = CaptureService()

    var body: some Scene {
        WindowGroup("Typing Lens", id: "main") {
            ContentView(captureService: captureService)
                .frame(minWidth: 920, minHeight: 720)
        }
        .windowResizability(.contentSize)

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
