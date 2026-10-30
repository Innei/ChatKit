#if os(macOS)
import AppKit
import ChatAppKit
import Testing

@MainActor
private final class Label: NSTextField {
  var configured = 0
}

@MainActor
private func table(rows count: Int, height: CGFloat = 400) -> (CKTranscriptTable, NSWindow) {
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: height), styleMask: [.titled], backing: .buffered, defer: false)
  window.isReleasedWhenClosed = false
  let table = CKTranscriptTable(frame: NSRect(x: 0, y: 0, width: 700, height: height))
  window.contentView = table
  table.cell = { row, reused in
    let label = (reused as? Label) ?? Label(wrappingLabelWithString: "")
    label.stringValue = "\(row.id) v\(row.version)"
    label.configured += 1
    return label
  }
  table.apply((0..<count).map { CKTranscriptRow(id: "r\($0)", kind: "text", neighbourKey: "text", version: 1, group: "e\($0)") })
  window.layoutIfNeeded()
  table.layoutSubtreeIfNeeded()
  return (table, window)
}

@MainActor @Test func onlyVisibleRowsAreBuilt() {
  let (table, window) = table(rows: 1000)
  defer { window.close() }
  #expect(table.rows.count == 1000)
  #expect(table.tableView.numberOfRows == 51)
  #expect(table.instantiatedContentViews.count < 60)
}

@MainActor @Test func aChangedRowIsReconfiguredInPlaceAndOthersKeepTheirViews() {
  let (table, window) = table(rows: 3)
  defer { window.close() }
  let before = table.instantiatedContentViews
  var rows = table.rows
  rows[1].version = 2
  table.apply(rows)
  let after = table.instantiatedContentViews
  #expect(after.count == 3)
  #expect(before[0] === after[0])
  #expect(before[1] === after[1])
  #expect((after[1] as? NSTextField)?.stringValue == "r1 v2")
}

@MainActor @Test func heightsAreCachedAcrossApplies() {
  let (table, window) = table(rows: 5)
  defer { window.close() }
  let measured = table.measurements
  table.apply(table.rows + [CKTranscriptRow(id: "new", kind: "text", neighbourKey: "text", version: 1, group: "e9")])
  table.layoutSubtreeIfNeeded()
  #expect(table.measurements == measured + 1)
}

@MainActor @Test func insertsAndDeletesKeepOrder() {
  let (table, window) = table(rows: 3)
  defer { window.close() }
  var rows = table.rows
  rows.remove(at: 0)
  rows.insert(CKTranscriptRow(id: "mid", kind: "text", neighbourKey: "text", version: 1, group: "e1"), at: 1)
  table.apply(rows)
  #expect(table.rows.map(\.id) == ["r1", "mid", "r2"])
  #expect(table.tableView.numberOfRows == 3)
}

@MainActor @Test func theReadingWidthCapsContentAndCanBeLifted() {
  let (table, window) = table(rows: 1)
  defer { window.close() }
  table.readingWidth = 500
  #expect(table.contentWidth == 468)
  table.readingWidth = nil
  #expect(table.contentWidth == 668)
}

@MainActor
private func waitUntil(_ condition: () -> Bool) {
  let deadline = Date().addingTimeInterval(3)
  while !condition(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
}

@MainActor @Test func historyOpensOnTheLatestPageWithAHeader() {
  let (table, window) = table(rows: 120)
  defer { window.close() }
  #expect(table.displayedRows.count == 51)
  #expect(table.displayedRows.first?.kind == CKTranscriptTable.historyKind)
  #expect(table.displayedRows[1].id == "r70")
  #expect(table.history.hasEarlier)
}

@MainActor @Test func reachingTheTopLoadsTheEarlierPageAndKeepsTheReaderInPlace() {
  let (table, window) = table(rows: 120)
  defer { window.close() }
  let clip = table.scrollView.contentView
  clip.scroll(to: NSPoint(x: 0, y: table.tableView.rect(ofRow: 3).minY))
  table.scrollView.reflectScrolledClipView(clip)
  let anchorID = table.displayedRows[3].id
  let before = table.tableView.rect(ofRow: 3).minY - clip.bounds.minY
  table.following = false
  table.loadEarlier()
  waitUntil { table.displayedRows.count == 101 }
  #expect(table.displayedRows.count == 101)
  let index = table.displayedRows.firstIndex { $0.id == anchorID }!
  let after = table.tableView.rect(ofRow: index).minY - clip.bounds.minY
  #expect(abs(after - before) <= 1)
}

@MainActor @Test func aPageWaitsWhileTheReaderIsScrolling() {
  let (table, window) = table(rows: 120)
  defer { window.close() }
  table.following = false
  NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: table.scrollView)
  table.loadEarlier()
  waitUntil { table.history.isPreparing && table.measurements >= 100 }
  RunLoop.main.run(until: Date().addingTimeInterval(0.1))
  #expect(table.displayedRows.count == 51)
  NotificationCenter.default.post(name: NSScrollView.didEndLiveScrollNotification, object: table.scrollView)
  waitUntil { table.displayedRows.count == 101 }
  #expect(table.displayedRows.count == 101)
}

@MainActor @Test func shortTranscriptsHaveNoHeader() {
  let (table, window) = table(rows: 3)
  defer { window.close() }
  #expect(table.displayedRows.map(\.id) == ["r0", "r1", "r2"])
}
#endif
