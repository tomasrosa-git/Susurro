import AVFoundation
import SusurroCore

@MainActor
final class DictationController {
    enum Mode: Equatable {
        case hold
        case handsFree
    }

    enum State: Equatable {
        case idle
        case recording(Mode)
        case transcribing
    }

    /// A forgotten hands-free session must not record all afternoon.
    static let maxRecordingDuration: TimeInterval = 5 * 60
    private static let minimumDuration: TimeInterval = 0.3

    var onStateChange: (State) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }

    private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange(state) } }
    }
    private(set) var recordingStartedAt: Date?

    var transcriber: LocalTranscriber
    private var gesture = DictationGesture()
    private let recorder = AudioRecorder()
    private var transcription: Task<Void, Never>?
    private var tapTimer: Timer?
    private var limitTimer: Timer?

    init(transcriber: LocalTranscriber) {
        self.transcriber = transcriber
    }

    var audioLevel: Float { recorder.level }

    func hotkeyPressed() {
        guard state != .transcribing else { return }
        apply(gesture.press(at: now))
    }

    func hotkeyReleased() {
        apply(gesture.release(at: now))
    }

    func otherKeyPressed() {
        apply(gesture.otherKeyPressed())
    }

    func escapePressed() {
        switch state {
        case .idle:
            break
        case .recording:
            gesture.reset()
            cancelRecording()
        case .transcribing:
            transcription?.cancel()
        }
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private func apply(_ action: DictationGesture.Action) {
        switch action {
        case .none: break
        case .start: startRecording()
        case .handsFree: if case .recording = state { state = .recording(.handsFree) }
        case .finish: finishRecording()
        case .cancel: cancelRecording()
        }
        scheduleTapTimer()
    }

    private func scheduleTapTimer() {
        tapTimer?.invalidate()
        tapTimer = nil
        guard let deadline = gesture.deadline else { return }
        tapTimer = Timer.scheduledTimer(withTimeInterval: max(0, deadline - now), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.apply(self.gesture.tapWindowElapsed())
            }
        }
    }

    private func startRecording() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            gesture.reset()
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            return
        default:
            gesture.reset()
            onError("Susurro no tiene permiso para usar el micrófono.")
            return
        }
        do {
            try recorder.start()
        } catch {
            gesture.reset()
            onError(error.localizedDescription)
            return
        }
        recordingStartedAt = Date()
        state = .recording(.hold)
        limitTimer = Timer.scheduledTimer(withTimeInterval: Self.maxRecordingDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.gesture.reset()
                self.finishRecording()
            }
        }
    }

    private func stopRecorder() -> [Float] {
        limitTimer?.invalidate()
        limitTimer = nil
        recordingStartedAt = nil
        return recorder.stop()
    }

    private func cancelRecording() {
        guard case .recording = state else { return }
        _ = stopRecorder()
        state = .idle
    }

    private func finishRecording() {
        guard case .recording = state else { return }
        let samples = stopRecorder()
        guard samples.count >= Int(Self.minimumDuration * Double(Audio.sampleRate)), !Audio.isSilent(samples) else {
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
                // Esc can land after whisper returns but before this resumes on the main actor.
                try Task.checkCancellation()
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
