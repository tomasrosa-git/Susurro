import Foundation

public enum Audio {
    public static let sampleRate = 16_000

    /// Whisper invents text ("Gracias por ver el video") when fed silence, so near-silent clips are dropped.
    public static func isSilent(_ samples: [Float], peakThreshold: Float = 0.01) -> Bool {
        !samples.contains { abs($0) >= peakThreshold }
    }

    /// 16-bit PCM mono WAV, the format whisper.cpp reads natively.
    public static func wav(samples: [Float], sampleRate: Int = sampleRate) -> Data {
        var data = Data()
        let byteCount = UInt32(samples.count * 2)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36) + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(byteCount)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append(Int16(clamped * Float(Int16.max)))
        }
        return data
    }
}
