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
            return "Typing Lens only installs a listen-only keyboard tap after you grant Input Monitoring. Use the button below, then approve the app in System Settings → Privacy & Security → Input Monitoring."
        case .granted:
            return "Permission granted. The app can keep a debug-only in-memory preview of recent key events. Nothing captured is written to disk."
        case .denied:
            return "Input Monitoring is currently denied. Open System Settings → Privacy & Security → Input Monitoring, enable Typing Lens, then return here. If macOS still shows the old state, quit and reopen the app once."
        }
    }
}
