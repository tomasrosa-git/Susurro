import Testing
@testable import SusurroCore

@Suite struct DictationGestureTests {
    private func gesture() -> DictationGesture {
        DictationGesture(tapThreshold: 0.3, doubleTapWindow: 0.4)
    }

    // MARK: Hold to talk

    @Test func holdLongEnoughFinishes() {
        var g = gesture()
        #expect(g.press(at: 10) == .start)
        #expect(g.release(at: 11.2) == .finish)
        #expect(g.state == .idle)
    }

    @Test func holdExactlyAtThresholdFinishes() {
        var g = gesture()
        _ = g.press(at: 0)
        #expect(g.release(at: 0.3) == .finish)
    }

    @Test func keyRepeatWhileHoldingIsIgnored() {
        var g = gesture()
        #expect(g.press(at: 0) == .start)
        #expect(g.press(at: 0.5) == .none)
        #expect(g.release(at: 1) == .finish)
    }

    @Test func releaseWithoutPressIsIgnored() {
        var g = gesture()
        #expect(g.release(at: 1) == .none)
    }

    // MARK: Single tap

    @Test func quickTapWaitsForSecondTapThenCancels() {
        var g = gesture()
        #expect(g.press(at: 10) == .start)
        #expect(g.release(at: 10.1) == .none)
        #expect(g.deadline == 10.5)
        #expect(g.tapWindowElapsed() == .cancel)
        #expect(g.state == .idle)
        #expect(g.deadline == nil)
    }

    @Test func tapWindowElapsedOutsideTheWindowDoesNothing() {
        var g = gesture()
        #expect(g.tapWindowElapsed() == .none)
        _ = g.press(at: 0)
        #expect(g.tapWindowElapsed() == .none)
        #expect(g.release(at: 2) == .finish)
    }

    // MARK: Hands-free

    @Test func doubleTapEntersHandsFreeAndNextTapFinishes() {
        var g = gesture()
        #expect(g.press(at: 0) == .start)
        #expect(g.release(at: 0.1) == .none)
        #expect(g.press(at: 0.3) == .handsFree)
        #expect(g.release(at: 0.4) == .none)
        #expect(g.state == .handsFree)
        #expect(g.deadline == nil)
        #expect(g.tapWindowElapsed() == .none)

        #expect(g.press(at: 60) == .finish)
        #expect(g.release(at: 60.1) == .none)
        #expect(g.state == .idle)
    }

    @Test func secondTapHeldLongStillEntersHandsFree() {
        var g = gesture()
        _ = g.press(at: 0)
        _ = g.release(at: 0.1)
        #expect(g.press(at: 0.2) == .handsFree)
        #expect(g.release(at: 3) == .none)
        #expect(g.state == .handsFree)
    }

    @Test func secondPressAfterLateTimerStillCountsAsDoubleTap() {
        var g = gesture()
        _ = g.press(at: 0)
        _ = g.release(at: 0.1)
        #expect(g.press(at: 0.52) == .handsFree)
    }

    @Test func freshRecordingAfterHandsFreeStops() {
        var g = gesture()
        _ = g.press(at: 0); _ = g.release(at: 0.1)
        _ = g.press(at: 0.2); _ = g.release(at: 0.3)
        _ = g.press(at: 5); _ = g.release(at: 5.1)
        #expect(g.press(at: 8) == .start)
        #expect(g.release(at: 9) == .finish)
    }

    // MARK: fn used as a modifier

    @Test func otherKeyWhileHoldingCancelsAndSwallowsTheRelease() {
        var g = gesture()
        _ = g.press(at: 0)
        #expect(g.otherKeyPressed() == .cancel)
        #expect(g.release(at: 2) == .none)
    }

    @Test func otherKeyDuringSecondTapCancels() {
        var g = gesture()
        _ = g.press(at: 0); _ = g.release(at: 0.1)
        _ = g.press(at: 0.2)
        #expect(g.otherKeyPressed() == .cancel)
        #expect(g.release(at: 0.3) == .none)
        #expect(g.state == .idle)
    }

    @Test func otherKeyDuringHandsFreeIsIgnored() {
        var g = gesture()
        _ = g.press(at: 0); _ = g.release(at: 0.1)
        _ = g.press(at: 0.2); _ = g.release(at: 0.3)
        #expect(g.otherKeyPressed() == .none)
        #expect(g.state == .handsFree)
    }

    // MARK: External stops

    @Test func resetWhileHoldingIgnoresTheRelease() {
        var g = gesture()
        _ = g.press(at: 0)
        g.reset()
        #expect(g.release(at: 1) == .none)
        #expect(g.press(at: 2) == .start)
    }

    @Test func resetDuringHandsFreeMeansNextPressStartsOver() {
        var g = gesture()
        _ = g.press(at: 0); _ = g.release(at: 0.1)
        _ = g.press(at: 0.2); _ = g.release(at: 0.3)
        g.reset()
        #expect(g.press(at: 10) == .start)
    }
}
