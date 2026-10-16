import Foundation

/// Turns raw hotkey press/release events into dictation actions.
///
/// Hold to talk. A quick tap followed by a second one within `doubleTapWindow` switches to hands-free,
/// and the next tap stops it. Recording starts on the first press, so a double-tap loses no audio.
public struct DictationGesture: Sendable {
    public enum Action: Equatable, Sendable {
        case none
        case start
        case handsFree
        case finish
        case cancel
    }

    enum State: Equatable {
        case idle
        case holding(since: TimeInterval)
        case awaitingSecondTap(until: TimeInterval)
        /// Second tap of a double-tap, key still down.
        case arming
        case handsFree
    }

    /// Releases faster than this are taps, not holds.
    public var tapThreshold: TimeInterval
    public var doubleTapWindow: TimeInterval
    private(set) var state: State = .idle

    public init(tapThreshold: TimeInterval = 0.3, doubleTapWindow: TimeInterval = 0.4) {
        self.tapThreshold = tapThreshold
        self.doubleTapWindow = doubleTapWindow
    }

    /// When set, the caller must call `tapWindowElapsed()` at this time unless another event comes first.
    public var deadline: TimeInterval? {
        if case .awaitingSecondTap(let until) = state { until } else { nil }
    }

    public mutating func press(at time: TimeInterval) -> Action {
        switch state {
        case .idle:
            state = .holding(since: time)
            return .start
        case .awaitingSecondTap:
            // Not compared against the deadline: a press that lands a few ms late because the
            // expiry timer hasn't fired yet was still meant as a double-tap.
            state = .arming
            return .handsFree
        case .handsFree:
            state = .idle
            return .finish
        case .holding, .arming:
            return .none
        }
    }

    public mutating func release(at time: TimeInterval) -> Action {
        switch state {
        case .holding(let since):
            if time - since < tapThreshold {
                state = .awaitingSecondTap(until: time + doubleTapWindow)
                return .none
            }
            state = .idle
            return .finish
        case .arming:
            state = .handsFree
            return .none
        case .idle, .awaitingSecondTap, .handsFree:
            return .none
        }
    }

    /// A lone quick tap: nothing was meant to be dictated.
    public mutating func tapWindowElapsed() -> Action {
        guard case .awaitingSecondTap = state else { return .none }
        state = .idle
        return .cancel
    }

    /// Another key while fn is down means fn is being used as a modifier (fn+arrow, fn+delete).
    public mutating func otherKeyPressed() -> Action {
        switch state {
        case .holding, .awaitingSecondTap, .arming:
            state = .idle
            return .cancel
        case .idle, .handsFree:
            return .none
        }
    }

    /// For stops decided outside the gesture (Esc, time limit). A release still in flight is then ignored.
    public mutating func reset() {
        state = .idle
    }
}
