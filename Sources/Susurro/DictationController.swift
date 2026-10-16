import AVFoundation
import SusurroCore

@MainActor
final class DictationController {
    enum State {
        case idle
        case recording
        case transcribing
    }

    var onStateChange: (State) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }

    private(set) var state: State = .idle {
        didSet { onStateChange(state) }
    }

    var transcriber: LocalTranscriber
    private var gesture = HoldGesture()
    private let recorder = AudioRecorder()
    private var transcription: Task<Void, Never>?

    init(transcriber: LocalTranscriber) {
        self.transcriber = transcriber
    }

    func hotkeyPressed() {
        guard state == .idle, gesture.press(at: ProcessInfo.processInfo.systemUptime) == .start else { return }
        startRecording()
    }

    func hotkeyReleased() {
        apply(gesture.release(at: ProcessInfo.processInfo.systemUptime))
    }

    func otherKeyPressed() {
        apply(gesture.otherKeyPressed())
    }

    private func apply(_ action: HoldGesture.Action) {
        guard state == .recording else { return }
        switch action {
        case .finish: finishRecording()
        case .cancel: cancelRecording()
        case .start, .none: break
        }
    }

    private func startRecording() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            return
        default:
            onError("Susurro no tiene permiso para usar el micrófono.")
            return
        }
        do {
            try recorder.start()
            state = .recording
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func cancelRecording() {
        _ = recorder.stop()
        state = .idle
    }

    private func finishRecording() {
        let samples = recorder.stop()
        let minimumSamples = Int(gesture.minimumHold * Double(Audio.sampleRate))
        guard samples.count >= minimumSamples, !Audio.isSilent(samples) else {
            state = .idle
            return
        }
        state = .transcribing

        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("susurro-\(UUID().uuidString).wav")
        let transcriber = transcriber
        transcription = Task {
            defer { try? FileManager.default.removeItem(at: wav) }
            do {
                try Audio.wav(samples: samples).write(to: wav)
                let text = try await transcriber.transcribe(wav: wav)
                if !text.isEmpty { TextInserter.insert(text) }
            } catch is CancellationError {
            } catch {
                onError(error.localizedDescription)
            }
            state = .idle
            transcription = nil
        }
    }
}
