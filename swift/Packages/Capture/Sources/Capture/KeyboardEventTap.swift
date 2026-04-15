import AppKit
import Core
import CoreGraphics
import Foundation

enum ObservedKeyEventPhase {
    case keyDown
    case keyUp
}

struct ObservedKeyEvent {
    let timestamp: Date
    let phase: ObservedKeyEventPhase
    let keyCode: Int64
    let keyboardType: Int64
    let deviceID: Int64
    let kind: String
    let renderedValue: String
    let isBackspace: Bool
    let flags: CGEventFlags
    let isAutoRepeat: Bool
}

enum KeyboardEventTapError: Error {
    case permissionNotGranted
    case tapCreationFailed
    case runLoopSourceCreationFailed
}

final class KeyboardEventTap {
    var onObservedKeyEvent: ((ObservedKeyEvent) -> Void)?
    var onTapNote: ((String) -> Void)?

    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isEnabled = false

    var isInstalled: Bool {
        machPort != nil
    }

    func install() throws {
        guard CGPreflightListenEventAccess() else {
            throw KeyboardEventTapError.permissionNotGranted
        }

        if machPort != nil {
            setEnabled(true)
            return
        }

        let eventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let tap = Unmanaged<KeyboardEventTap>.fromOpaque(userInfo).takeUnretainedValue()
            return tap.handleEvent(type: type, event: event)
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let machPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else {
            throw KeyboardEventTapError.tapCreationFailed
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0) else {
            CFMachPortInvalidate(machPort)
            throw KeyboardEventTapError.runLoopSourceCreationFailed
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        self.machPort = machPort
        self.runLoopSource = runLoopSource
        setEnabled(true)
    }

    func uninstall() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let machPort {
            CFMachPortInvalidate(machPort)
        }

        runLoopSource = nil
        machPort = nil
        isEnabled = false
    }

    func setEnabled(_ enabled: Bool) {
        guard let machPort else {
            isEnabled = false
            return
        }

        CGEvent.tapEnable(tap: machPort, enable: enabled)
        isEnabled = enabled
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout:
            if let machPort {
                CGEvent.tapEnable(tap: machPort, enable: true)
                isEnabled = true
                onTapNote?("Tap auto-re-enabled after timeout.")
            }
        case .tapDisabledByUserInput:
            if let machPort {
                CGEvent.tapEnable(tap: machPort, enable: true)
                isEnabled = true
                onTapNote?("Tap auto-re-enabled after user input disable.")
            }
        case .keyDown, .keyUp:
            onObservedKeyEvent?(ObservedKeyEvent.from(event: event, type: type))
        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }
}

private extension ObservedKeyEvent {
    static func from(event: CGEvent, type: CGEventType) -> ObservedKeyEvent {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let rawValue = event.debugRenderedValue(for: keyCode)
        let isBackspace = keyCode == 51
        let phase: ObservedKeyEventPhase = type == .keyUp ? .keyUp : .keyDown
        let deviceID = NSEvent(cgEvent: event).map { Int64($0.deviceID) } ?? -1
        let kind = switch phase {
        case .keyDown:
            isBackspace ? "backspaceDown" : "keyDown"
        case .keyUp:
            isBackspace ? "backspaceUp" : "keyUp"
        }

        return ObservedKeyEvent(
            timestamp: Date(),
            phase: phase,
            keyCode: keyCode,
            keyboardType: event.getIntegerValueField(.keyboardEventKeyboardType),
            deviceID: deviceID,
            kind: kind,
            renderedValue: rawValue,
            isBackspace: isBackspace,
            flags: event.flags,
            isAutoRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        )
    }
}

private extension CGEvent {
    func debugRenderedValue(for keyCode: Int64) -> String {
        switch keyCode {
        case 36:
            return "↩︎"
        case 48:
            return "⇥"
        case 49:
            return "␠"
        case 51:
            return "⌫"
        case 53:
            return "⎋"
        default:
            var length = 0
            var buffer = [UniChar](repeating: 0, count: 8)
            keyboardGetUnicodeString(
                maxStringLength: buffer.count,
                actualStringLength: &length,
                unicodeString: &buffer
            )

            if length > 0 {
                let string = String(utf16CodeUnits: buffer, count: length)
                if string == "\r" {
                    return "↩︎"
                }
                if string == "\t" {
                    return "⇥"
                }
                if string == " " {
                    return "␠"
                }
                return string
            }

            return "[keyCode:\(keyCode)]"
        }
    }
}
