import AppKit
import Carbon

class PreferencesWindowController: NSWindowController {
    private weak var hotkeyManager: HotkeyManager?
    private var hotkeyRecorderView: HotkeyRecorderView?
    private var onModelChanged: ((String) -> Void)?
    private var onLanguageChanged: ((String?) -> Void)?
    private var onTranslateChanged: ((Bool) -> Void)?

    init(
        hotkeyManager: HotkeyManager,
        currentModel: String,
        currentLanguageCode: String?,
        currentTranslate: Bool,
        onModelChanged: @escaping (String) -> Void,
        onLanguageChanged: @escaping (String?) -> Void,
        onTranslateChanged: @escaping (Bool) -> Void
    ) {
        self.hotkeyManager = hotkeyManager
        self.onModelChanged = onModelChanged
        self.onLanguageChanged = onLanguageChanged
        self.onTranslateChanged = onTranslateChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 272),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FakeWispr Preferences"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupUI(currentModel: currentModel, currentLanguageCode: currentLanguageCode, currentTranslate: currentTranslate)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI(currentModel: String, currentLanguageCode: String?, currentTranslate: Bool) {
        guard let window else { return }

        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(container)

        // Model label
        let modelLabel = NSTextField(labelWithString: "Model:")
        modelLabel.frame = NSRect(x: 24, y: 232, width: 70, height: 22)
        modelLabel.alignment = .right
        container.addSubview(modelLabel)

        // Model picker
        let modelPopup = NSPopUpButton(frame: NSRect(x: 102, y: 228, width: 200, height: 26), pullsDown: false)
        for name in WhisperTranscriber.availableModels {
            modelPopup.addItem(withTitle: name)
        }
        modelPopup.selectItem(withTitle: currentModel)
        modelPopup.target = self
        modelPopup.action = #selector(modelPickerChanged(_:))
        container.addSubview(modelPopup)

        // Language label
        let langLabel = NSTextField(labelWithString: "Language:")
        langLabel.frame = NSRect(x: 24, y: 188, width: 70, height: 22)
        langLabel.alignment = .right
        container.addSubview(langLabel)

        // Language picker
        let langPopup = NSPopUpButton(frame: NSRect(x: 102, y: 184, width: 200, height: 26), pullsDown: false)
        for (name, _) in WhisperTranscriber.availableLanguages {
            langPopup.addItem(withTitle: name)
        }
        let selectedLangName = WhisperTranscriber.availableLanguages
            .first(where: { $0.code == currentLanguageCode })?.name ?? "Auto-detect"
        langPopup.selectItem(withTitle: selectedLangName)
        langPopup.target = self
        langPopup.action = #selector(languagePickerChanged(_:))
        container.addSubview(langPopup)

        // Translate checkbox
        let translateCheck = NSButton(checkboxWithTitle: "Translate to English", target: self, action: #selector(translateToggled(_:)))
        translateCheck.frame = NSRect(x: 102, y: 150, width: 200, height: 22)
        translateCheck.state = currentTranslate ? .on : .off
        container.addSubview(translateCheck)

        // Hotkey label
        let hotkeyLabel = NSTextField(labelWithString: "Hotkey:")
        hotkeyLabel.frame = NSRect(x: 24, y: 112, width: 70, height: 22)
        hotkeyLabel.alignment = .right
        container.addSubview(hotkeyLabel)

        // Recorder button
        let recorder = HotkeyRecorderView(config: hotkeyManager?.config ?? .defaultHotkey)
        recorder.frame = NSRect(x: 102, y: 108, width: 200, height: 28)
        recorder.onConfigChanged = { [weak self] newConfig in
            self?.hotkeyManager?.updateConfig(newConfig)
        }
        hotkeyRecorderView = recorder
        container.addSubview(recorder)

        // Hint
        let hint = NSTextField(labelWithString: "Hold the hotkey to record, release to transcribe.")
        hint.frame = NSRect(x: 24, y: 64, width: 296, height: 28)
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2
        container.addSubview(hint)

        // Reset button
        let reset = NSButton(title: "Reset to Default", target: self, action: #selector(resetHotkey))
        reset.frame = NSRect(x: 102, y: 24, width: 150, height: 24)
        reset.bezelStyle = .inline
        container.addSubview(reset)
    }

    @objc private func modelPickerChanged(_ sender: NSPopUpButton) {
        guard let name = sender.selectedItem?.title else { return }
        onModelChanged?(name)
    }

    @objc private func languagePickerChanged(_ sender: NSPopUpButton) {
        guard let name = sender.selectedItem?.title else { return }
        let code = WhisperTranscriber.availableLanguages.first(where: { $0.name == name })?.code
        onLanguageChanged?(code)
    }

    @objc private func translateToggled(_ sender: NSButton) {
        onTranslateChanged?(sender.state == .on)
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
    private var pendingModifiers: NSEvent.ModifierFlags = []

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
        title = isRecording ? "Press keys…" : config.displayName
    }

    @objc private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        pendingModifiers = []
        updateTitle()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event)
            return nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            pendingModifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
            title = pendingModifiers.isEmpty ? "Press keys…" : buildPendingTitle(pendingModifiers)
            return
        }

        // keyDown: Escape cancels; require at least one modifier for a valid hotkey
        if event.keyCode == 53 { stopRecording(apply: false); return }
        guard !pendingModifiers.isEmpty else { return }

        commit(keyCode: event.keyCode, nsModifiers: pendingModifiers)
    }

    private func commit(keyCode: UInt16, nsModifiers: NSEvent.ModifierFlags) {
        let carbonMods = carbonModifiers(from: nsModifiers)
        let displayName = buildDisplayName(keyCode: keyCode, flags: nsModifiers)
        let newConfig = HotkeyConfig(
            keyCode: UInt32(keyCode),
            carbonModifiers: carbonMods,
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

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
        if flags.contains(.option)  { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    private func buildPendingTitle(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append("…")
        return parts.joined()
    }

    private func buildDisplayName(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode) ?? "Key\(keyCode)")
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫",
            96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 111: "F12", 122: "F1",
            120: "F2", 118: "F4",
        ]
        return map[keyCode]
    }
}
