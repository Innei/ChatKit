#if os(macOS)
import AppKit
import ChatKitCore

extension CKTranscriptTable {
  public func loadEarlier() {
    guard history.requestEarlier() else { return }
    prepareEarlier()
  }

  func prepareEarlier() {
    preparing?.run.cancel()
    let groups = Set(history.page(groups: groupOrder))
    let page = rows.filter { groups.contains($0.group) }
    let run = CKPrepareBudget.run(
      items: page,
      clock: { CACurrentMediaTime() },
      schedule: { next in
        nonisolated(unsafe) let slice = next
        let timer = Timer(timeInterval: 0.008, repeats: false) { _ in MainActor.assumeIsolated { slice() } }
        RunLoop.main.add(timer, forMode: .common)
      },
      measure: { [weak self] row in self?.height(for: row) },
      done: { [weak self] in
        guard let self else { return }
        history.markPrepared(page.map(\.id))
        commitEarlier()
      }
    )
    preparing = (run, page.map(\.id))
    refreshHeader()
  }

  func commitEarlier() {
    guard let pageRows = preparing?.rows,
          history.commit(groups: groupOrder, pageRows: pageRows, scrollMoving: liveScrolling)
    else { return }
    preparing = nil
    let clip = scrollView.contentView
    let anchor = firstVisibleRow().map {
      CKScrollAnchor.capture(rowID: displayedRows[$0].id, rowMinY: tableView.rect(ofRow: $0).minY, offset: clip.bounds.minY)
    }
    display(windowed())
    tableView.layoutSubtreeIfNeeded()
    guard let anchor, let index = displayedRows.firstIndex(where: { $0.id == anchor.rowID }),
          let target = anchor.target(rowMinY: tableView.rect(ofRow: index).minY, topRubberBanding: clip.bounds.minY < -scrollView.contentInsets.top)
    else { return }
    clip.scroll(to: NSPoint(x: clip.bounds.minX, y: target))
    scrollView.reflectScrolledClipView(clip)
  }

  func windowed() -> [CKTranscriptRow] {
    let groups = groupOrder
    let boundary = history.update(groups: groups)
    let start = groups.isEmpty ? 0 : rows.firstIndex { $0.group == groups[boundary] } ?? 0
    let visible = Array(rows[start...])
    guard history.hasEarlier || history.hasPaged else { return visible }
    refreshHeader()
    return [CKTranscriptRow(id: Self.historyKind, kind: Self.historyKind, neighbourKey: "", version: headerState.rawValue, group: "")] + visible
  }

  func observeScrolling() {
    let center = NotificationCenter.default
    center.addObserver(self, selector: #selector(liveScrollStarted), name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
    center.addObserver(self, selector: #selector(liveScrollEnded), name: NSScrollView.didEndLiveScrollNotification, object: scrollView)
    scrollView.contentView.postsBoundsChangedNotifications = true
    center.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
  }

  @objc private func liveScrollStarted() { liveScrolling = true }

  @objc private func liveScrollEnded() {
    liveScrolling = false
    commitEarlier()
  }

  @objc private func scrolled() { prefetchIfNeeded() }

  func prefetchIfNeeded() {
    let clip = scrollView.contentView.bounds
    let scrollable = tableView.frame.height > clip.height
    guard CKHistoryWindow.shouldPrefetch(distanceFromTop: clip.minY + scrollView.contentInsets.top, viewport: clip.height, following: following, finding: false, positioned: scrollable) else { return }
    loadEarlier()
  }

  private var groupOrder: [String] {
    var seen = Set<String>()
    return rows.compactMap { seen.insert($0.group).inserted ? $0.group : nil }
  }

  private var headerState: CKHistoryHeaderView.State {
    if history.isPreparing { return .loading }
    return history.hasEarlier ? .more : .start
  }

  private func refreshHeader() {
    historyHeader.state = headerState
  }

  private func firstVisibleRow() -> Int? {
    let range = tableView.rows(in: scrollView.contentView.bounds)
    return (range.location..<NSMaxRange(range)).first { displayedRows.indices.contains($0) && displayedRows[$0].kind != Self.historyKind }
  }
}
#endif
