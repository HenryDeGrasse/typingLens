import AppKit
import SwiftUI

struct PracticeKeyCaptureView: NSViewRepresentable {
    let isActive: Bool
    let onCharacter: (String) -> Void
    let onBackspace: () -> Void

    func makeNSView(context: Context) -> PracticeCaptureNSView {
        let view = PracticeCaptureNSView()
        view.onCharacter = onCharacter
        view.onBackspace = onBackspace
        view.isCaptureActive = isActive
        return view
    }

    func updateNSView(_ nsView: PracticeCaptureNSView, context: Context) {
        nsView.onCharacter = onCharacter
        nsView.onBackspace = onBackspace
        nsView.isCaptureActive = isActive
        nsView.refocusIfNeeded()
    }
}

final class PracticeCaptureNSView: NSView {
    var onCharacter: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var isCaptureActive = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refocusIfNeeded()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isCaptureActive else {
            super.keyDown(with: event)
            return
        }

        let blockedModifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard blockedModifiers.isEmpty else {
            return
        }

        switch event.keyCode {
        case 51:
            onBackspace?()
            return
        case 36, 76:
            return
        default:
            break
        }

        guard let rawCharacters = event.charactersIgnoringModifiers?.lowercased(),
              rawCharacters.count == 1 else {
            return
        }

        let normalized = String(rawCharacters)
        if normalized == " " || normalized.range(of: "^[a-z]$", options: .regularExpression) != nil {
            onCharacter?(normalized)
        }
    }

    override func becomeFirstResponder() -> Bool {
        true
    }

    func refocusIfNeeded() {
        guard isCaptureActive else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            if window.firstResponder !== self {
                window.makeFirstResponder(self)
            }
        }
    }
}
