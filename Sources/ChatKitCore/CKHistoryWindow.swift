import CoreGraphics

public struct CKHistoryWindow: Sendable {
  public let pageSize: Int
  public private(set) var hasEarlier = false
  public private(set) var hasPaged = false
  public private(set) var isPreparing = false
  private var start: String?
  private var target: String?
  private var prepared = Set<String>()
  private var width: CGFloat?

  public init(pageSize: Int = 50) {
    self.pageSize = pageSize
  }

  public mutating func update(groups: [String]) -> Int {
    guard !groups.isEmpty else {
      self = CKHistoryWindow(pageSize: pageSize)
      return 0
    }
    let retained = start.flatMap { groups.firstIndex(of: $0) }
    let index = retained ?? max(0, groups.count - pageSize)
    start = groups[index]
    hasEarlier = index > 0
    hasPaged = hasEarlier || (retained != nil && hasPaged)
    return index
  }

  public mutating func requestEarlier() -> Bool {
    guard hasEarlier, !isPreparing else { return false }
    isPreparing = true
    target = nil
    return true
  }

  public mutating func page(groups: [String]) -> [String] {
    guard isPreparing, let first = range(groups: groups) else { return [] }
    target = groups[first.lowerBound]
    return Array(groups[first])
  }

  public mutating func markPrepared(_ rowIDs: some Sequence<String>) {
    prepared.formUnion(rowIDs)
  }

  public func isPrepared(_ rowID: String) -> Bool { prepared.contains(rowID) }

  public mutating func commit(groups: [String], pageRows: [String], scrollMoving: Bool) -> Bool {
    guard isPreparing, !scrollMoving, pageRows.allSatisfy(prepared.contains), let page = range(groups: groups) else { return false }
    start = groups[page.lowerBound]
    target = nil
    isPreparing = false
    prepared.removeAll()
    hasEarlier = page.lowerBound > 0
    hasPaged = true
    return true
  }

  public mutating func widthChanged(_ next: CGFloat) {
    if width != next { prepared.removeAll() }
    width = next
  }

  public static func shouldPrefetch(distanceFromTop: CGFloat, viewport: CGFloat, following: Bool, finding: Bool, positioned: Bool) -> Bool {
    positioned && !following && !finding && distanceFromTop < viewport
  }

  private func range(groups: [String]) -> Range<Int>? {
    guard let start, let end = groups.firstIndex(of: start) else { return nil }
    let lower = target.flatMap { groups.firstIndex(of: $0) }.map { min(end, $0) } ?? max(0, end - pageSize)
    return lower..<end
  }
}
