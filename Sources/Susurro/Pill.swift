import AppKit
import SusurroCore
import SwiftUI

/// Floating indicator near the bottom of the screen while Susurro records or transcribes.
@MainActor
final class PillPanel {
    private let panel: NSPanel
    private let model = PillModel()
    private var refreshTimer: Timer?

    var levelProvider: () -> Float = { 0 }
    var startedAtProvider: () -> Date? = { nil }

    private static let size = NSSize(width: 260, height: 48)
    private static let bottomMargin: CGFloat = 28

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: PillView(model: model))
    }

    func show(_ state: DictationController.State) {
        let wasVisible = model.state != .idle
        model.state = state
        refresh()
        guard state != .idle else {
            refreshTimer?.invalidate()
            refreshTimer = nil
            panel.orderOut(nil)
            return
        }
        if !wasVisible {
            position()
            panel.orderFrontRegardless()
        }
        if refreshTimer == nil {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    private func refresh() {
        model.level = levelProvider()
        model.elapsed = startedAtProvider().map { Date().timeIntervalSince($0) } ?? 0
    }

    /// The screen under the mouse, which is where the user is looking.
    private func position() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - Self.size.width / 2, y: frame.minY + Self.bottomMargin))
    }
}

@MainActor
private final class PillModel: ObservableObject {
    @Published var state: DictationController.State = .idle
    @Published var level: Float = 0
    @Published var elapsed: TimeInterval = 0
}

private struct PillView: View {
    @ObservedObject var model: PillModel

    var body: some View {
        HStack(spacing: 8) {
            switch model.state {
            case .recording(let mode, let trigger):
                LevelBars(level: model.level, color: trigger == .command ? .purple : .red)
                Text(trigger == .command ? "Comando" : mode == .hold ? "Escuchando" : "Manos libres")
                if mode == .handsFree {
                    Text(clock(model.elapsed))
                        .foregroundStyle(remaining < 30 ? Color.orange : Color.white.opacity(0.6))
                        .monospacedDigit()
                }
            case .transcribing(let trigger):
                WorkingBars()
                Text(trigger == .command ? "Aplicando" : "Transcribiendo")
            case .idle:
                EmptyView()
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Capsule().fill(Color.black.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var remaining: TimeInterval {
        DictationController.maxRecordingDuration - model.elapsed
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private let barShape: [CGFloat] = [0.45, 0.75, 1, 0.75, 0.45]

private struct LevelBars: View {
    let level: Float
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(barShape.indices, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: max(3, 14 * barShape[index] * loudness))
            }
        }
        .frame(height: 14)
        .animation(.easeOut(duration: 0.08), value: level)
    }

    /// Speech RMS sits roughly between -50 dB and -10 dB; map that range to 0...1.
    private var loudness: CGFloat {
        guard level > 0 else { return 0 }
        let decibels = 20 * log10(Double(level))
        return CGFloat(min(1, max(0, (decibels + 50) / 40)))
    }
}

private struct WorkingBars: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(barShape.indices, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 3, height: 4 + 10 * abs(sin(t * 5 + Double(index) * 0.7)))
                }
            }
            .frame(height: 14)
        }
    }
}
