import CoreGraphics

public struct CKStreamDeferral: Sendable {
  public struct Row: Sendable {
    public var group: String
    public var frame: CGRect
    public var deferrable: Bool

    public init(group: String, frame: CGRect, deferrable: Bool) {
      self.group = group
      self.frame = frame
      self.deferrable = deferrable
    }
  }

  public static let freezeMargin: CGFloat = 80
  public static let resumeMargin: CGFloat = 160

  public private(set) var deferred = Set<String>()

  public init() {}

  public mutating func update(rows: [Row], viewport: CGRect, following: Bool, finding: Bool) -> (deferred: Set<String>, catchingUp: Set<String>) {
    let groups = Dictionary(grouping: rows.filter(\.deferrable), by: \.group)
    var frozen = Set<String>()
    var resumed = Set<String>()
    for group in Set(groups.keys).union(deferred) {
      let margin = deferred.contains(group) ? Self.resumeMargin : Self.freezeMargin
      let nearby = viewport.insetBy(dx: 0, dy: -margin)
      let streaming = groups[group] ?? []
      let offscreen = !streaming.isEmpty && streaming.allSatisfy { !$0.frame.intersects(nearby) }
      if !following, !finding, offscreen {
        if deferred.insert(group).inserted { frozen.insert(group) }
      } else if deferred.remove(group) != nil {
        resumed.insert(group)
      }
    }
    return (frozen, resumed)
  }
}
