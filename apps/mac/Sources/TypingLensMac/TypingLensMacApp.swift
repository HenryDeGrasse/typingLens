import Capture
import SwiftUI

@main
struct TypingLensMacApp: App {
    @StateObject private var captureService = CaptureService()

    var body: some Scene {
        WindowGroup("Typing Lens") {
            ContentView(captureService: captureService)
                .frame(minWidth: 920, minHeight: 720)
        }
        .windowResizability(.contentSize)
    }
}
