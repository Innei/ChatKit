import ChatKitCore
import CoreGraphics
import Testing

private let viewport = CGRect(x: 0, y: 0, width: 400, height: 600)

private func row(_ group: String, at y: CGFloat, deferrable: Bool = true) -> CKStreamDeferral.Row {
  CKStreamDeferral.Row(group: group, frame: CGRect(x: 0, y: y, width: 400, height: 40), deferrable: deferrable)
}

@Test func aStreamFarBelowTheViewportIsFrozen() {
  var deferral = CKStreamDeferral()
  let change = deferral.update(rows: [row("e1", at: 800)], viewport: viewport, following: false, finding: false)
  #expect(change.deferred == ["e1"])
  #expect(deferral.deferred == ["e1"])
}

@Test func aStreamJustOutsideTheMarginIsStillLive() {
  var deferral = CKStreamDeferral()
  _ = deferral.update(rows: [row("e1", at: 670)], viewport: viewport, following: false, finding: false)
  #expect(deferral.deferred.isEmpty)
}

@Test func aFrozenStreamResumesEarlierThanItFroze() {
  var deferral = CKStreamDeferral()
  _ = deferral.update(rows: [row("e1", at: 800)], viewport: viewport, following: false, finding: false)
  let change = deferral.update(rows: [row("e1", at: 740)], viewport: viewport, following: false, finding: false)
  #expect(change.catchingUp == ["e1"])
  #expect(deferral.deferred.isEmpty)
}

@Test func followingOrFindingNeverFreezes() {
  var deferral = CKStreamDeferral()
  _ = deferral.update(rows: [row("e1", at: 900)], viewport: viewport, following: true, finding: false)
  _ = deferral.update(rows: [row("e2", at: 900)], viewport: viewport, following: false, finding: true)
  #expect(deferral.deferred.isEmpty)
}

@Test func nonDeferrableRowsAreNeverFrozen() {
  var deferral = CKStreamDeferral()
  _ = deferral.update(rows: [row("e1", at: 900, deferrable: false)], viewport: viewport, following: false, finding: false)
  #expect(deferral.deferred.isEmpty)
}

@Test func oneVisibleRowKeepsTheWholeGroupLive() {
  var deferral = CKStreamDeferral()
  _ = deferral.update(rows: [row("e1", at: 900), row("e1", at: 300)], viewport: viewport, following: false, finding: false)
  #expect(deferral.deferred.isEmpty)
}
