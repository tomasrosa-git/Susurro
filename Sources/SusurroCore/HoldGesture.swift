import Foundation

/// Turns raw hotkey press/release events into dictation actions for hold-to-talk.
public struct HoldGesture: Sendable {
    public enum Action: Equatable, Sendable {
        case none
        case start
        case finish
        case cancel
    }

    /// Shorter holds are treated as accidental taps.
    public var minimumHold: TimeInterval
    private var pressedAt: TimeInterval?

    public init(minimumHold: TimeInterval = 0.3) {
        self.minimumHold = minimumHold
    }

    public var isHolding: Bool { pressedAt != nil }

    public mutating func press(at time: TimeInterval) -> Action {
        guard pressedAt == nil else { return .none }
        pressedAt = time
        return .start
    }

    public mutating func release(at time: TimeInterval) -> Action {
        guard let start = pressedAt else { return .none }
        pressedAt = nil
        return time - start < minimumHold ? .cancel : .finish
    }

    /// Another key while fn is held means fn is being used as a modifier (fn+arrow, fn+delete).
    public mutating func otherKeyPressed() -> Action {
        guard pressedAt != nil else { return .none }
        pressedAt = nil
        return .cancel
    }
}
