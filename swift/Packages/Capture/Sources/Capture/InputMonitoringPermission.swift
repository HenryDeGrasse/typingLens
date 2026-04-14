import AppKit
import Core
import CoreGraphics
import Foundation
import IOKit.hid

public enum InputMonitoringPermissionManager {
    private static let settingsURLs = [
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent",
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
        "x-apple.systempreferences:com.apple.preference.security"
    ]

    public static func currentState() -> InputMonitoringPermissionState {
        if CGPreflightListenEventAccess() {
            return .granted
        }

        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return .granted
        case kIOHIDAccessTypeDenied:
            return .denied
        default:
            return .unknown
        }
    }

    @discardableResult
    public static func requestAccess() -> Bool {
        CGRequestListenEventAccess()
    }

    @discardableResult
    public static func openSettings() -> Bool {
        for candidate in settingsURLs {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }

    public static func guidanceText(for state: InputMonitoringPermissionState) -> String {
        switch state {
        case .unknown:
            return "Typing Lens only installs a listen-only keyboard tap after you grant Input Monitoring. The product UI focuses on a local typing profile built from content-free summaries, not raw text. Use the button below, then approve the app in System Settings → Privacy & Security → Input Monitoring."
        case .granted:
            return "Permission granted. Typing Lens can now observe typing activity, compute local profile summaries like rhythm and flow, and keep any raw debug preview in memory only."
        case .denied:
            return "Input Monitoring is currently denied. Open System Settings → Privacy & Security → Input Monitoring, enable Typing Lens, then return here. If macOS still shows the old state, quit and reopen the app once."
        }
    }
}
