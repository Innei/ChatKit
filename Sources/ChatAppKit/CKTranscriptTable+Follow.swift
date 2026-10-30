#if os(macOS)
import AppKit
import ChatKitCore

struct CKTranscriptMotion {
  let timer: Timer
  var from: CGFloat
  var began: TimeInterval
  var last: TimeInterval
}

extension CKTranscriptTable {
  public func follow(_ event: CKFollowState.Event) {
    followState.handle(event)
    if !following {
      stopMotion()
      prefetchIfNeeded()
    }
    catchUpDeferred()
    settle()
  }

  public func anchor(rowID: String) {
    followState.handle(.anchorableRowArrived(rowID))
    guard followState.anchoredRowID == rowID else { return }
    landing = true
    stopMotion()
    settle()
  }

  var distanceFromBottom: CGFloat {
    max(0, bottomOffset - scrollView.contentView.bounds.minY)
  }

  private var bottomOffset: CGFloat {
    CKScrollMotion.bottom(
      contentHeight: contentHeight + reserve,
      viewportHeight: scrollView.contentView.bounds.height,
      topInset: scrollView.contentInsets.top,
      bottomInset: scrollView.contentInsets.bottom
    )
  }

  private var contentHeight: CGFloat {
    guard let last = displayedRows.lastIndex(where: { $0.kind != Self.reserveKind }) else { return 0 }
    return tableView.rect(ofRow: last).maxY
  }

  func settle(snap: Bool = false) {
    guard !settling, !displayedRows.isEmpty else { return }
    settling = true
    defer { settling = false }
    updateReserve()
    guard following, !liveScrolling else { return }
    if abs(tableView.frame.height - contentHeight - reserve) > 0.5 { tableView.tile() }
    let clip = scrollView.contentView
    guard abs(clip.bounds.minY - bottomOffset) > 0.5 else {
      positioned = clip.bounds.height > 0
      landing = false
      return
    }
    guard motion == nil else { return }
    if !positioned || snap || window == nil {
      scroll(to: bottomOffset)
      positioned = true
      landing = false
      return
    }
    startMotion()
  }

  func catchUpDeferred() {
    let streaming = displayedRows.indices.filter { displayedRows[$0].deferrable }.map {
      CKStreamDeferral.Row(group: displayedRows[$0].group, frame: tableView.rect(ofRow: $0), deferrable: true)
    }
    let update = deferral.update(rows: streaming, viewport: scrollView.contentView.bounds, following: following, finding: false)
    if !update.catchingUp.isEmpty { display(windowed()) }
  }

  func wheel(began: Bool) {
    if began {
      follow(.pause)
    } else {
      follow(.scrollEnded(distanceFromBottom: distanceFromBottom))
    }
  }

  private func updateReserve() {
    var next: CGFloat = 0
    if let id = followState.anchoredRowID, let index = displayedRows.firstIndex(where: { $0.id == id }) {
      next = CKScrollMotion.reserve(
        anchorMinY: tableView.rect(ofRow: index).minY,
        contentHeight: contentHeight,
        viewportHeight: scrollView.contentView.bounds.height,
        topInset: scrollView.contentInsets.top,
        bottomInset: scrollView.contentInsets.bottom
      )
      if next <= 0.5, !landing { followState.handle(.clearAnchor) }
    }
    guard abs(next - reserve) > 0.5 else { return }
    let hadSpacer = reserve > 0
    reserve = next > 0.5 ? next : 0
    if hadSpacer == (reserve > 0), let index = displayedRows.firstIndex(where: { $0.kind == Self.reserveKind }) {
      tableView.noteHeightOfRows(withIndexesChanged: [index])
    } else {
      display(windowed())
    }
  }

  private func startMotion() {
    let now = CACurrentMediaTime()
    let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.step() }
    }
    RunLoop.main.add(timer, forMode: .common)
    motion = CKTranscriptMotion(timer: timer, from: scrollView.contentView.bounds.minY, began: now, last: now)
  }

  private func stopMotion() {
    motion?.timer.invalidate()
    motion = nil
  }

  private func step() {
    guard var current = motion, following, !liveScrolling else {
      stopMotion()
      return
    }
    let now = CACurrentMediaTime()
    let target = bottomOffset
    let y: CGFloat
    var done: Bool
    if landing {
      y = current.from + (target - current.from) * CKScrollMotion.sendProgress(elapsed: now - current.began)
      done = now - current.began >= CKScrollMotion.sendDuration
    } else {
      let position = scrollView.contentView.bounds.minY
      let pixel = 1 / (window?.backingScaleFactor ?? 2)
      y = CKScrollMotion.advance(position, toward: target, elapsed: now - current.last, response: 0.10, minimumStep: pixel)
      done = y == target
    }
    current.last = now
    motion = current
    scroll(to: done ? target : y)
    if done {
      landing = false
      stopMotion()
    }
  }

  private func scroll(to y: CGFloat) {
    let clip = scrollView.contentView
    clip.scroll(to: NSPoint(x: clip.bounds.minX, y: y))
    scrollView.reflectScrolledClipView(clip)
  }
}

@MainActor
final class CKScrollView: NSScrollView {
  var onWheel: ((Bool) -> Void)?

  override func scrollWheel(with event: NSEvent) {
    let discrete = event.phase.isEmpty && event.momentumPhase.isEmpty
    if discrete { onWheel?(true) }
    super.scrollWheel(with: event)
    if discrete { onWheel?(false) }
  }
}
#endif
