import WhisperKit
import Foundation

class WhisperTranscriber {
    private var whisper: WhisperKit?
    private var isLoading = false

    func loadModel() async {
        guard whisper == nil, !isLoading else { return }
        isLoading = true
        do {
            whisper = try await WhisperKit(model: "openai_whisper-large-v3-turbo")
            NSLog("FakeWispr: Whisper model loaded")
        } catch {
            NSLog("FakeWispr: model load error — \(error)")
        }
        isLoading = false
    }

    func transcribe(samples: [Float]) async -> String? {
        guard let whisper else {
            return nil
        }
        do {
            let results = try await whisper.transcribe(audioArray: samples)
            return results.map(\.text).joined(separator: " ")
        } catch {
            return nil
        }
    }
}
