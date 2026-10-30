import ChatKitCore
import CoreGraphics
import Testing

@Test func aSendFollowsAndAnchorsTheArrivingUserRow() {
  var state = CKFollowState()
  state.handle(.pause)
  state.handle(.send(queued: false))
  #expect(state.follows)
  #expect(state.awaitingAnchor)
  state.handle(.anchorableRowArrived("t1:user"))
  #expect(state.anchoredRowID == "t1:user")
  #expect(!state.awaitingAnchor)
}

@Test func aQueuedSendLeavesFollowingAlone() {
  var state = CKFollowState()
  state.handle(.pause)
  state.handle(.send(queued: true))
  #expect(!state.follows)
  #expect(!state.awaitingAnchor)
}

@Test func aRowArrivingWithoutASendDoesNotAnchor() {
  var state = CKFollowState()
  state.handle(.anchorableRowArrived("old:user"))
  #expect(state.anchoredRowID == nil)
}

@Test func scrollingBackToTheBottomResumesWithinOnePoint() {
  var state = CKFollowState()
  state.handle(.pause)
  state.handle(.scrollEnded(distanceFromBottom: 1.5))
  #expect(!state.follows)
  state.handle(.scrollEnded(distanceFromBottom: 1))
  #expect(state.follows)
}

@Test func aLiveTurnResumesNearTheTailUnlessTheReaderPaused() {
  var near = CKFollowState()
  near.handle(.pause)
  near.handle(.scrollEnded(distanceFromBottom: 40))
  near.handle(.liveTurnStarted(distanceFromTail: 40))
  #expect(!near.follows)

  var untouched = CKFollowState()
  untouched.handle(.unfollow)
  untouched.handle(.liveTurnStarted(distanceFromTail: 79))
  #expect(untouched.follows)

  var far = CKFollowState()
  far.handle(.unfollow)
  far.handle(.liveTurnStarted(distanceFromTail: 81))
  #expect(!far.follows)
}

@Test func jumpingToTheBottomClearsAGesturePause() {
  var state = CKFollowState()
  state.handle(.pause)
  state.handle(.jumpToBottom)
  #expect(state.follows)
  state.handle(.liveTurnStarted(distanceFromTail: 10))
  #expect(state.follows)
}

@Test func anAnchorKeepsTheRowWhereItWasAfterAPrepend() {
  let anchor = CKScrollAnchor.capture(rowID: "r", rowMinY: 500, offset: 420)
  #expect(anchor.target(rowMinY: 800, topRubberBanding: false) == 720)
  #expect(anchor.target(rowMinY: 800, topRubberBanding: true) == nil)
}

@Test func motionMatchesChatScroll() {
  #expect(CKScrollMotion.advance(100, toward: 100.2, elapsed: 1.0 / 60, response: 0.10) == 100.2)
  let shrink = CKScrollMotion.advance(100, toward: 20, elapsed: 1.0 / 60, response: 0.06)
  #expect(shrink > 20 && shrink < 100)
  #expect(CKScrollMotion.advance(100, toward: 20, elapsed: 0, response: 0.06) == 100)
  #expect(CKScrollMotion.advance(100, toward: 100.9, elapsed: 1.0 / 60, response: 10, minimumStep: 1) == 100.9)
  #expect(CKScrollMotion.bottom(contentHeight: 500, viewportHeight: 200, topInset: 100, bottomInset: 40) == 340)
  #expect(CKScrollMotion.bottom(contentHeight: 20, viewportHeight: 200, topInset: 100, bottomInset: 40) == -100)
  #expect(CKScrollMotion.resumeDistance == 80)
}

@Test func theSendEaseLandsInAQuarterSecond() {
  #expect(CKScrollMotion.sendProgress(elapsed: 0) == 0)
  #expect(CKScrollMotion.sendProgress(elapsed: 0.25) == 1)
  #expect(abs(CKScrollMotion.sendProgress(elapsed: 0.125) - 0.875) < 0.0001)
}

@Test func theReserveLiftsTheAnchoredRowToTheTop() {
  let reserve = CKScrollMotion.reserve(anchorMinY: 900, contentHeight: 1000, viewportHeight: 600, topInset: 50, bottomInset: 20)
  #expect(reserve == 430)
  #expect(CKScrollMotion.reserve(anchorMinY: 100, contentHeight: 1000, viewportHeight: 600, topInset: 50, bottomInset: 20) == 0)
}
