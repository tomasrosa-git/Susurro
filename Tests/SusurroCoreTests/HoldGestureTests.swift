import Testing
@testable import SusurroCore

@Suite struct HoldGestureTests {
    @Test func holdLongEnoughFinishes() {
        var g = HoldGesture(minimumHold: 0.3)
        #expect(g.press(at: 10) == .start)
        #expect(g.release(at: 11.2) == .finish)
        #expect(!g.isHolding)
    }

    @Test func quickTapCancels() {
        var g = HoldGesture(minimumHold: 0.3)
        #expect(g.press(at: 10) == .start)
        #expect(g.release(at: 10.1) == .cancel)
    }

    @Test func repeatedPressWhileHoldingIsIgnored() {
        var g = HoldGesture()
        #expect(g.press(at: 0) == .start)
        #expect(g.press(at: 0.5) == .none)
        #expect(g.release(at: 1) == .finish)
    }

    @Test func releaseWithoutPressIsIgnored() {
        var g = HoldGesture()
        #expect(g.release(at: 1) == .none)
    }

    @Test func otherKeyCancelsAndSwallowsTheRelease() {
        var g = HoldGesture()
        #expect(g.press(at: 0) == .start)
        #expect(g.otherKeyPressed() == .cancel)
        #expect(g.release(at: 2) == .none)
        #expect(g.otherKeyPressed() == .none)
    }
}
