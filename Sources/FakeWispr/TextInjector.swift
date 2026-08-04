import AppKit

class TextInjector {
    private var restoreWorkItem: DispatchWorkItem?
    private var hasShownPermissionAlert = false

    func inject(text: String) {
        guard AXIsProcessTrusted() else {
            showPermissionAlert()
            return
        }

        restoreWorkItem?.cancel()

        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)

        pb.clearContents()
        pb.setString(text, forType: .string)

        // Brief pause so the previous app fully regains focus, then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.postCmdV()
        }

        // Restore clipboard after paste completes
        let workItem = DispatchWorkItem {
            pb.clearContents()
            if let prev = previous {
                pb.setString(prev, forType: .string)
            }
        }
        restoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
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

    private func showPermissionAlert() {
        guard !hasShownPermissionAlert else { return }
        hasShownPermissionAlert = true

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "FakeWispr needs Accessibility to paste text. Each rebuild resets this — open Settings, toggle FakeWispr off then back on."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        hasShownPermissionAlert = false
    }
}
