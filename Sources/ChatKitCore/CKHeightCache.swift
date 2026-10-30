import CoreGraphics

public struct CKHeightKey: Hashable, Sendable {
  public var id: String
  public var version: Int
  public var width: CGFloat
  public var previous: String

  public init(id: String, version: Int, width: CGFloat, previous: String) {
    self.id = id
    self.version = version
    self.width = width
    self.previous = previous
  }
}

public struct CKHeightCache: Sendable {
  private var entries: [String: (key: CKHeightKey, height: CGFloat)] = [:]

  public init() {}

  public func height(for key: CKHeightKey) -> CGFloat? {
    guard let entry = entries[key.id], entry.key == key else { return nil }
    return entry.height
  }

  public mutating func store(_ height: CGFloat, for key: CKHeightKey) {
    guard height > 0.5 else { return }
    entries[key.id] = (key, height)
  }

  public mutating func prune(retaining ids: Set<String>) {
    entries = entries.filter { ids.contains($0.key) }
  }

  public mutating func invalidateAll() {
    entries.removeAll()
  }
}
