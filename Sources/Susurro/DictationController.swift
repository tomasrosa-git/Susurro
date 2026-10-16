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
        case recording(Mode, Trigger)
        case transcribing(Trigger)
    }

    /// A forgotten hands-free session must not record all afternoon.
    static let maxRecordingDuration: TimeInterval = 5 * 60
    private static let minimumDuration: TimeInterval = 0.3

    var onStateChange: (State) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }
    var onNotice: (String) -> Void = { _ in }
    var onDictation: (String) -> Void = { _ in }

    private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange(state) } }
    }
    private(set) var recordingStartedAt: Date?

    var pipeline: DictationPipeline
    var restoreClipboard = false
    private var gesture = DictationGesture()
    private let recorder = AudioRecorder()
    private var transcription: Task<Void, Never>?
    private var tapTimer: Timer?
    private var limitTimer: Timer?
    private var pendingTrigger: Trigger = .dictation

    init(pipeline: DictationPipeline) {
        self.pipeline = pipeline
    }

    var audioLevel: Float { recorder.level }

    func hotkeyPressed(_ trigger: Trigger) {
        if case .transcribing = state { return }
        let action = gesture.press(at: now)
        pendingTrigger = trigger
        if trigger == .command { upgradeToCommand() }
        apply(action)
    }

    /// Joining the command modifiers mid-recording turns the take into a command, without losing audio.
    func upgradeToCommand() {
        if case .recording(let mode, .dictation) = state { state = .recording(mode, .command) }
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
        case .handsFree: if case .recording(_, let trigger) = state { state = .recording(.handsFree, trigger) }
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
        state = .recording(.hold, pendingTrigger)
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
        guard case .recording(_, let trigger) = state else { return }
        let samples = stopRecorder()
        guard samples.count >= Int(Self.minimumDuration * Double(Audio.sampleRate)), !Audio.isSilent(samples) else {
            state = .idle
            return
        }
        state = .transcribing(trigger)

        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("susurro-\(UUID().uuidString).wav")
        let pipeline = pipeline
        let restoreClipboard = restoreClipboard
        transcription = Task {
            defer { try? FileManager.default.removeItem(at: wav) }
            do {
                try Audio.wav(samples: samples).write(to: wav)
                if trigger == .command {
                    try await runCommand(wav: wav, pipeline: pipeline, restoreClipboard: restoreClipboard)
                    state = .idle
                    transcription = nil
                    return
                }
                var text = try await pipeline.transcript(wav: wav)
                if let cleaner = pipeline.cleaner, !text.isEmpty {
                    do {
                        text = try await cleaner.clean(text)
                    } catch {
                        try Task.checkCancellation()
                        onNotice("Limpieza no disponible, pegué el texto sin limpiar. \(error.localizedDescription)")
                    }
                }
                // Esc can land after the last await but before this resumes on the main actor.
                try Task.checkCancellation()
                if !text.isEmpty {
                    TextInserter.insert(
                        Spacing.join(text, after: CursorContext.previousCharacter()),
                        restoringClipboard: restoreClipboard
                    )
                    onDictation(text)
                }
            } catch {
                // Cancelled network calls surface as URLError, not CancellationError.
                if !Task.isCancelled { onError(error.localizedDescription) }
            }
            state = .idle
            transcription = nil
        }
    }

    private func runCommand(wav: URL, pipeline: DictationPipeline, restoreClipboard: Bool) async throws {
        guard let commander = pipeline.commander else {
            onError("El modo comando necesita GROQ_API_KEY en .env.")
            return
        }
        // Read before the transcription await: by then the user may have clicked elsewhere.
        let selection = await CursorContext.selectedText()
        let instruction = try await pipeline.transcript(wav: wav)
        guard !instruction.isEmpty else { return }
        let output = try await commander.run(instruction: instruction, selection: selection)
        try Task.checkCancellation()
        // With a selection, ⌘V replaces it; without one it's new text at the cursor, spaced like a dictation.
        let text = selection == nil ? Spacing.join(output, after: CursorContext.previousCharacter()) : output
        TextInserter.insert(text, restoringClipboard: restoreClipboard)
        onDictation(output)
    }
}
