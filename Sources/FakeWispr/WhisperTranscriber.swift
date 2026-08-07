import WhisperKit
import Foundation

class WhisperTranscriber {
    static let availableModels: [String] = [
        "openai_whisper-tiny",
        "openai_whisper-tiny.en",
        "openai_whisper-base",
        "openai_whisper-base.en",
        "openai_whisper-small",
        "openai_whisper-small.en",
        "openai_whisper-medium",
        "openai_whisper-medium.en",
        "openai_whisper-large-v3",
        "openai_whisper-large-v3_turbo",
        "vinai/PhoWhisper-base",
    ]

    // (display name, ISO 639-1 code); nil code = auto-detect
    static let availableLanguages: [(name: String, code: String?)] = [
        ("Auto-detect", nil),
        ("English", "en"),
        ("Spanish", "es"),
        ("French", "fr"),
        ("German", "de"),
        ("Italian", "it"),
        ("Portuguese", "pt"),
        ("Dutch", "nl"),
        ("Russian", "ru"),
        ("Chinese", "zh"),
        ("Japanese", "ja"),
        ("Korean", "ko"),
        ("Arabic", "ar"),
        ("Hindi", "hi"),
        ("Vietnamese", "vi"),
        ("Polish", "pl"),
        ("Turkish", "tr"),
        ("Swedish", "sv"),
        ("Ukrainian", "uk"),
        ("Indonesian", "id"),
    ]

    private static let modelDefaultsKey = "selectedModel"
    private static let languageDefaultsKey = "selectedLanguage"
    private static let translateDefaultsKey = "translateToEnglish"
    private static let defaultModel = "openai_whisper-base.en"
    private static let autoDetectSentinel = "__auto__"

    private var whisper: WhisperKit?
    private var isLoading = false
    private(set) var modelName: String
    private(set) var languageCode: String?  // nil = auto-detect
    private(set) var translateToEnglish: Bool

    init() {
        modelName = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? Self.defaultModel
        let saved = UserDefaults.standard.string(forKey: Self.languageDefaultsKey)
        if modelName == "vinai/PhoWhisper-base" && (saved == nil || saved == Self.autoDetectSentinel) {
            languageCode = "vi"
        } else {
            languageCode = (saved == nil || saved == Self.autoDetectSentinel) ? nil : saved
        }
        translateToEnglish = UserDefaults.standard.bool(forKey: Self.translateDefaultsKey)
    }

    func loadModel() async {
        guard whisper == nil, !isLoading else { return }
        isLoading = true
        NSLog("FakeWispr: loading model '\(modelName)'...")
        do {
            let config = WhisperKitConfig(model: modelName, verbose: true, logLevel: .debug)
            whisper = try await WhisperKit(config)
            NSLog("FakeWispr: model loaded successfully")
        } catch {
            NSLog("FakeWispr: model load error — \(error)")
        }
        isLoading = false
    }

    func switchModel(to name: String) async {
        guard Self.availableModels.contains(name) else { return }
        whisper = nil
        isLoading = false
        modelName = name
        UserDefaults.standard.set(name, forKey: Self.modelDefaultsKey)
        if name == "vinai/PhoWhisper-base" {
            setLanguage("vi")
        }
        await loadModel()
    }

    func setLanguage(_ code: String?) {
        languageCode = code
        UserDefaults.standard.set(code ?? Self.autoDetectSentinel, forKey: Self.languageDefaultsKey)
    }

    func setTranslate(_ enabled: Bool) {
        translateToEnglish = enabled
        UserDefaults.standard.set(enabled, forKey: Self.translateDefaultsKey)
    }

    func transcribe(samples: [Float]) async -> String? {
        guard let whisper else {
            NSLog("FakeWispr: transcribe called but whisper is nil (model not loaded)")
            return nil
        }
        let task: DecodingTask = translateToEnglish ? .translate : .transcribe
        NSLog("FakeWispr: transcribing \(samples.count) samples (language: \(languageCode ?? "auto"), task: \(task))")
        do {
            let options = DecodingOptions(task: task, language: languageCode)
            let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ")
            NSLog("FakeWispr: transcription result = '\(text)'")
            return text
        } catch {
            NSLog("FakeWispr: transcription error — \(error)")
            return nil
        }
    }
}
