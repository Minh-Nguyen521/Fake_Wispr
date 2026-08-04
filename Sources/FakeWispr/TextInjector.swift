import AppKit

class TextInjector {
    func inject(text: String) {
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)

        pb.clearContents()
        pb.setString(text, forType: .string)

        // Brief pause so the previous app fully regains focus, then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.postCmdV()
        }

        // Restore clipboard after paste completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            pb.clearContents()
            if let prev = previous {
                pb.setString(prev, forType: .string)
            }
        }
    }

    private func postCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
