import AppKit

class PreferencesWindowController: NSWindowController {
    private weak var hotkeyManager: HotkeyManager?
    private var hotkeyRecorderView: HotkeyRecorderView?

    init(hotkeyManager: HotkeyManager) {
        self.hotkeyManager = hotkeyManager

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FakeWispr Preferences"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let window else { return }

        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(container)

        // Label
        let label = NSTextField(labelWithString: "Hotkey:")
        label.frame = NSRect(x: 24, y: 80, width: 70, height: 22)
        label.alignment = .right
        container.addSubview(label)

        // Recorder button
        let recorder = HotkeyRecorderView(config: hotkeyManager?.config ?? .defaultHotkey)
        recorder.frame = NSRect(x: 102, y: 76, width: 200, height: 28)
        recorder.onConfigChanged = { [weak self] newConfig in
            self?.hotkeyManager?.updateConfig(newConfig)
        }
        hotkeyRecorderView = recorder
        container.addSubview(recorder)

        // Hint
        let hint = NSTextField(labelWithString: "Hold the hotkey to record, release to transcribe.")
        hint.frame = NSRect(x: 24, y: 44, width: 296, height: 28)
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2
        container.addSubview(hint)

        // Reset button
        let reset = NSButton(title: "Reset to Default", target: self, action: #selector(resetHotkey))
        reset.frame = NSRect(x: 102, y: 12, width: 150, height: 24)
        reset.bezelStyle = .inline
        container.addSubview(reset)
    }

    @objc private func resetHotkey() {
        let config = HotkeyConfig.defaultHotkey
        hotkeyManager?.updateConfig(config)
        hotkeyRecorderView?.update(config: config)
    }
}

// MARK: - HotkeyRecorderView

class HotkeyRecorderView: NSButton {
    private(set) var config: HotkeyConfig
    var onConfigChanged: ((HotkeyConfig) -> Void)?
    private var isRecording = false
    private var localMonitor: Any?

    init(config: HotkeyConfig) {
        self.config = config
        super.init(frame: .zero)
        bezelStyle = .rounded
        updateTitle()
        target = self
        action = #selector(startRecording)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(config: HotkeyConfig) {
        self.config = config
        updateTitle()
    }

    private func updateTitle() {
        title = isRecording ? "Press any key…" : config.displayName
    }

    @objc private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        updateTitle()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event)
            return nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        // Escape cancels
        if event.type == .keyDown && event.keyCode == 53 {
            stopRecording(apply: false)
            return
        }

        let keyCode = Int64(event.keyCode)
        let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])
        let displayName = buildDisplayName(keyCode: event.keyCode, flags: flags)

        let newConfig = HotkeyConfig(
            keyCode: keyCode,
            modifierFlags: UInt64(flags.rawValue),
            displayName: displayName
        )

        stopRecording(apply: true)
        config = newConfig
        updateTitle()
        onConfigChanged?(newConfig)
    }

    private func stopRecording(apply: Bool) {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if !apply { updateTitle() }
    }

    private func buildDisplayName(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyName = keyCodeToString(keyCode) ?? "Key\(keyCode)"
        parts.append(keyName)
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
            56: "⇧", 58: "⌥", 59: "⌃", 61: "Right ⌥", 62: "Right ⌃",
            63: "Fn", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 111: "F12", 122: "F1",
            120: "F2", 118: "F4",
        ]
        return map[keyCode]
    }
}
