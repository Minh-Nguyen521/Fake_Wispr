import AppKit
import AVFoundation

enum AppState {
    case idle, loading, recording, processing
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
        if #available(macOS 14, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }

        hotkeyManager = HotkeyManager(
            onKeyDown: { [weak self] in
                Task { @MainActor in self?.startRecording() }
            },
            onKeyUp: { [weak self] in
                Task { @MainActor in await self?.stopAndTranscribe() }
            }
        )

        setState(.loading)
        Task {
            await transcriber.loadModel()
            await MainActor.run { setState(.idle) }
        }
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
        case .loading:
            button.title = "⋯"
            button.image = nil
        case .recording:
            button.title = "🔴"
            button.image = nil
        case .processing:
            button.title = "⏳"
            button.image = nil
        }
    }

    @objc func openPreferences() {
        preferencesWindowController = PreferencesWindowController(
            hotkeyManager: hotkeyManager,
            currentModel: transcriber.modelName,
            currentLanguageCode: transcriber.languageCode,
            currentTranslate: transcriber.translateToEnglish,
            onModelChanged: { [weak self] name in self?.changeModel(name) },
            onLanguageChanged: { [weak self] code in self?.transcriber.setLanguage(code) },
            onTranslateChanged: { [weak self] enabled in self?.transcriber.setTranslate(enabled) }
        )
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func changeModel(_ name: String) {
        setState(.loading)
        Task {
            await transcriber.switchModel(to: name)
            await MainActor.run { setState(.idle) }
        }
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
