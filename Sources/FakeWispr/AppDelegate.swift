import AppKit
import AVFoundation

enum AppState {
    case idle, recording, processing
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotkeyManager: HotkeyManager!
    var audioRecorder: AudioRecorder!
    var transcriber: WhisperTranscriber!
    var textInjector: TextInjector!
    var preferencesWindowController: PreferencesWindowController?
    var overlay = RecordingOverlay()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        audioRecorder = AudioRecorder()
        transcriber = WhisperTranscriber()
        textInjector = TextInjector()

        // Request mic permission upfront
        AVCaptureDevice.requestAccess(for: .audio) { _ in }

        hotkeyManager = HotkeyManager(
            onKeyDown: { [weak self] in
                Task { @MainActor in self?.startRecording() }
            },
            onKeyUp: { [weak self] in
                Task { @MainActor in await self?.stopAndTranscribe() }
            }
        )

        Task { await transcriber.loadModel() }
        hotkeyManager.start()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setState(.idle)

        let menu = NSMenu()
        let title = NSMenuItem(title: "FakeWispr", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func setState(_ state: AppState) {
        guard let button = statusItem.button else { return }
        switch state {
        case .idle:
            button.title = "𝍄"
            button.image = nil
        case .recording:
            button.title = "🔴"
            button.image = nil
        case .processing:
            button.title = "⏳"
            button.image = nil
        }
    }

    @objc func checkPermissions() {
        let trusted = AXIsProcessTrusted()
        let alert = NSAlert()
        alert.messageText = trusted ? "✅ Accessibility: Granted" : "❌ Accessibility: Not Granted"
        alert.informativeText = trusted
            ? "Hotkey is active. Hold \(hotkeyManager.config.displayName) to dictate."
            : "Go to System Settings → Privacy & Security → Accessibility → enable FakeWispr."
        alert.alertStyle = trusted ? .informational : .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(hotkeyManager: hotkeyManager)
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor func startRecording() {
        setState(.recording)
        audioRecorder.startRecording()
        overlay.show(hotkey: "Hold \(hotkeyManager.config.displayName) to dictate")
    }

    @MainActor func stopAndTranscribe() async {
        setState(.processing)
        overlay.hide()
        let samples = audioRecorder.stopRecording()
        guard !samples.isEmpty else { setState(.idle); return }

        if let text = await transcriber.transcribe(samples: samples) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                textInjector.inject(text: trimmed)
            }
        }
        setState(.idle)
    }
}
