import AppKit
#if canImport(Carbon)
import Carbon
#endif
import Foundation

enum KeyboardContext {
    static func currentLayoutID() -> String {
        #if canImport(Carbon)
        if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
            return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
        }
        #endif
        return "unknown"
    }

    static func currentLayoutName() -> String {
        #if canImport(Carbon)
        if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let property = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
        }
        #endif
        return "Unknown Layout"
    }

    static func deviceClass(for observedEvent: ObservedKeyEvent) -> String {
        if observedEvent.deviceID > 0 {
            return "device-\(observedEvent.deviceID)"
        }
        if observedEvent.keyboardType > 0 {
            return "keyboardType-\(observedEvent.keyboardType)"
        }
        return "unknown-device"
    }

    static func deviceClass(for event: NSEvent) -> String {
        let deviceID = event.deviceID
        if deviceID > 0 {
            return "device-\(deviceID)"
        }
        return "unknown-device"
    }
}
