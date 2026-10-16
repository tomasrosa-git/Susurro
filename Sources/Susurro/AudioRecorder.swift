import AVFoundation
import SusurroCore

/// Captures the default input device as 16 kHz mono Float32, which is what whisper expects.
final class AudioRecorder: @unchecked Sendable {
    enum RecorderError: LocalizedError {
        case noInput

        var errorDescription: String? { "No hay micrófono disponible." }
    }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(Audio.sampleRate),
        channels: 1,
        interleaved: false
    )!

    func start() throws {
        lock.withLock { samples.removeAll(keepingCapacity: true) }
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        else { throw RecorderError.noInput }

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard let converted = AVAudioPCMBuffer(pcmFormat: self.outputFormat, frameCapacity: capacity) else { return }
            var consumed = false
            var error: NSError?
            converter.convert(to: converted, error: &error) { _, status in
                if consumed {
                    status.pointee = .noDataNow
                    return nil
                }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, let channel = converted.floatChannelData?[0] else { return }
            let chunk = UnsafeBufferPointer(start: channel, count: Int(converted.frameLength))
            self.lock.withLock { self.samples.append(contentsOf: chunk) }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return lock.withLock { samples }
    }
}
