#if os(macOS)
import AppKit
import ChatKitCore

public struct CKTranscriptRow: CKDiffableRow, Sendable {
  public let id: String
  public var kind: String
  public var neighbourKey: String
  public var version: Int
  public var group: String
  public var deferrable: Bool

  public init(id: String, kind: String, neighbourKey: String, version: Int, group: String, deferrable: Bool = false) {
    self.id = id
    self.kind = kind
    self.neighbourKey = neighbourKey
    self.version = version
    self.group = group
    self.deferrable = deferrable
  }
}

@MainActor
public final class CKTranscriptTable: NSView, NSTableViewDataSource, NSTableViewDelegate {
  public static let historyKind = "ck.history"
  static let reserveKind = "ck.reserve"
  public let scrollView: NSScrollView = CKScrollView()
  public let tableView = NSTableView()
  public var spacing: CGFloat = 14
  public var horizontalInset: CGFloat = 16
  public var readingWidth: CGFloat? = 780 {
    didSet { if readingWidth != oldValue { widthChanged() } }
  }
  public var cell: (CKTranscriptRow, NSView?) -> NSView = { _, reused in reused ?? NSView() }
  public var measure: ((CKTranscriptRow, CGFloat) -> CGFloat)?
  public internal(set) var followState = CKFollowState()
  public internal(set) var reserve: CGFloat = 0
  public var following: Bool { followState.follows }
  public var isMoving: Bool { motion != nil }
  public let historyHeader = CKHistoryHeaderView()
  public private(set) var rows: [CKTranscriptRow] = []
  public private(set) var displayedRows: [CKTranscriptRow] = []
  public private(set) var measurements = 0
  public internal(set) var history = CKHistoryWindow()
  var heights = CKHeightCache()
  var previousKeys: [String: String] = [:]
  var preparing: (run: CKPrepareRun, rows: [String])?
  var liveScrolling = false
  var motion: CKTranscriptMotion?
  var landing = false
  var positioned = false
  var settling = false
  var deferral = CKStreamDeferral()
  private var measurers: [String: (view: NSView, width: NSLayoutConstraint)] = [:]
  private var applying = false
  private var pending: [CKTranscriptRow]?
  private var laidOutWidth: CGFloat = 0

  public override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("transcript"))
    column.resizingMask = .autoresizingMask
    tableView.addTableColumn(column)
    tableView.headerView = nil
    tableView.style = .plain
    tableView.intercellSpacing = .zero
    tableView.backgroundColor = .clear
    tableView.selectionHighlightStyle = .none
    tableView.gridStyleMask = []
    tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
    tableView.usesAutomaticRowHeights = false
    tableView.dataSource = self
    tableView.delegate = self
    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false
    scrollView.frame = bounds
    scrollView.autoresizingMask = [.width, .height]
    addSubview(scrollView)
    historyHeader.onLoad = { [weak self] in self?.loadEarlier() }
    observeScrolling()
    (scrollView as? CKScrollView)?.onWheel = { [weak self] began in self?.wheel(began: began) }
  }

  public required init?(coder: NSCoder) { nil }

  isolated deinit {
    motion?.timer.invalidate()
  }

  public var contentWidth: CGFloat {
    max(1, min(readingWidth ?? .greatestFiniteMagnitude, scrollView.contentView.bounds.width) - horizontalInset * 2)
  }

  public var instantiatedContentViews: [NSView] {
    (0..<tableView.numberOfRows).compactMap { contentView(at: $0) }
  }

  public func contentView(at index: Int) -> NSView? {
    (tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? CKTranscriptCellView)?.content
  }

  public func apply(_ next: [CKTranscriptRow]) {
    guard !applying else {
      pending = next
      return
    }
    var seen = Set<String>()
    let next = next.filter { seen.insert($0.id).inserted }
    rows = next
    previousKeys = Dictionary(uniqueKeysWithValues: zip(next.map(\.id), [""] + next.map(\.neighbourKey)))
    heights.prune(retaining: Set(next.map(\.id)))
    let distance = distanceFromBottom
    let shownGroups = Set(displayedRows.map(\.group))
    display(windowed())
    if !shownGroups.isEmpty, let tail = displayedRows.last(where: { $0.kind != Self.reserveKind }), !shownGroups.contains(tail.group) {
      followState.handle(.liveTurnStarted(distanceFromTail: distance))
    }
    settle()
  }

  func display(_ next: [CKTranscriptRow]) {
    applying = true
    defer {
      applying = false
      if let queued = pending {
        pending = nil
        apply(queued)
      }
    }
    guard case .success(let changes) = CKRowDiff.compute(previous: displayedRows, next: next) else { return }
    let previous = displayedRows
    displayedRows = next
    let deleted = Set(changes.deleted)
    let inserted = Set(changes.inserted)
    guard previous.map(\.id).filter({ !deleted.contains($0) }) == next.map(\.id).filter({ !inserted.contains($0) }) else {
      tableView.reloadData()
      return
    }
    tableView.beginUpdates()
    tableView.removeRows(at: IndexSet(previous.indices.filter { deleted.contains(previous[$0].id) }), withAnimation: [])
    tableView.insertRows(at: IndexSet(next.indices.filter { inserted.contains(next[$0].id) }), withAnimation: [])
    tableView.endUpdates()
    let positions = Dictionary(uniqueKeysWithValues: next.enumerated().map { ($1.id, $0) })
    let changed = IndexSet(changes.reconfigured.compactMap { positions[$0] })
    for index in changed {
      guard let container = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? CKTranscriptCellView else { continue }
      container.install(content(for: next[index], reusing: container.content))
    }
    if !changed.isEmpty { noteHeights(changed) }
  }

  public func reloadAll() {
    heights.invalidateAll()
    measurers.removeAll()
    tableView.reloadData()
  }

  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil { stopMotion() }
  }

  // View-based tables animate height changes unless the change runs in a zero-duration group.
  func noteHeights(_ rows: IndexSet) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0
      tableView.noteHeightOfRows(withIndexesChanged: rows)
    }
  }

  public override func layout() {
    super.layout()
    if abs(contentWidth - laidOutWidth) > 0.5 {
      widthChanged()
      settle(snap: true)
    }
  }

  public func numberOfRows(in tableView: NSTableView) -> Int { displayedRows.count }

  public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    let item = displayedRows[row]
    if item.kind == Self.historyKind { return CKHistoryHeaderView.height }
    if item.kind == Self.reserveKind { return max(reserve, 1) }
    return height(for: item) + spacing
  }

  public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let item = displayedRows[row]
    let identifier = NSUserInterfaceItemIdentifier(item.kind)
    let container = (tableView.makeView(withIdentifier: identifier, owner: nil) as? CKTranscriptCellView) ?? CKTranscriptCellView(identifier: identifier)
    container.table = self
    container.install(content(for: item, reusing: container.content))
    return container
  }

  public func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }

  private func content(for row: CKTranscriptRow, reusing view: NSView?) -> NSView {
    switch row.kind {
    case Self.historyKind: historyHeader
    case Self.reserveKind: view ?? NSView()
    default: cell(row, view)
    }
  }

  @discardableResult
  func height(for row: CKTranscriptRow) -> CGFloat {
    let width = contentWidth
    let key = CKHeightKey(id: row.id, version: row.version, width: width, previous: previousKeys[row.id] ?? "")
    if let cached = heights.height(for: key) { return cached }
    measurements += 1
    let measured = measure?(row, width) ?? fit(row, width: width)
    heights.store(measured, for: key)
    return max(measured, 1)
  }

  private func fit(_ row: CKTranscriptRow, width: CGFloat) -> CGFloat {
    let view = cell(row, measurers[row.kind]?.view)
    let constraint: NSLayoutConstraint
    if let existing = measurers[row.kind], existing.view === view {
      constraint = existing.width
    } else {
      view.translatesAutoresizingMaskIntoConstraints = false
      constraint = view.widthAnchor.constraint(equalToConstant: width)
      constraint.isActive = true
    }
    measurers[row.kind] = (view, constraint)
    constraint.constant = width
    view.frame.size.width = width
    view.layoutSubtreeIfNeeded()
    view.layoutSubtreeIfNeeded()
    return ceil(view.fittingSize.height)
  }

  private func widthChanged() {
    laidOutWidth = contentWidth
    history.widthChanged(contentWidth)
    if preparing != nil { prepareEarlier() }
    guard !displayedRows.isEmpty else { return }
    noteHeights(IndexSet(displayedRows.indices))
    for index in 0..<tableView.numberOfRows {
      tableView.view(atColumn: 0, row: index, makeIfNecessary: false)?.needsLayout = true
    }
  }
}

@MainActor
final class CKTranscriptCellView: NSTableCellView {
  weak var table: CKTranscriptTable?
  private(set) var content: NSView?

  init(identifier: NSUserInterfaceItemIdentifier) {
    super.init(frame: .zero)
    self.identifier = identifier
  }

  required init?(coder: NSCoder) { nil }

  func install(_ view: NSView) {
    if view !== content {
      content?.removeFromSuperview()
      view.translatesAutoresizingMaskIntoConstraints = true
      addSubview(view)
      content = view
    }
    needsLayout = true
  }

  override func layout() {
    super.layout()
    guard let content, let table else { return }
    let width = table.contentWidth
    content.frame = NSRect(x: ((bounds.width - width) / 2).rounded(), y: table.spacing / 2, width: width, height: max(0, bounds.height - table.spacing))
  }
}
#endif
