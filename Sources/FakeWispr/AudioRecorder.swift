import AVFoundation

class AudioRecorder {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let targetSampleRate: Double = 16000
    private var isRecording = false

    func startRecording() {
        samples = []
        isRecording = true

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else { return }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, self.isRecording else { return }
            self.convert(buffer: buffer, from: inputFormat, to: whisperFormat)
        }

        do {
            try engine.start()
        } catch {
            print("❌ AudioEngine error: \(error)")
        }
    }

    func stopRecording() -> [Float] {
        isRecording = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return samples
    }

    private func convert(buffer: AVAudioPCMBuffer, from srcFormat: AVAudioFormat, to dstFormat: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else { return }

        let ratio = dstFormat.sampleRate / srcFormat.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
        guard let converted = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: frameCapacity) else { return }

        var error: NSError?
        var inputProvided = false

        converter.convert(to: converted, error: &error) { _, status in
            if inputProvided {
                status.pointee = .noDataNow
                return nil
            }
            inputProvided = true
            status.pointee = .haveData
            return buffer
        }

        guard error == nil, let channelData = converted.floatChannelData?[0] else { return }
        samples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: Int(converted.frameLength)))
    }
}
