public protocol CKDiffableRow: Equatable {
  var id: String { get }
  var neighbourKey: String { get }
}

public enum CKRowDiff {
  public struct Changes: Equatable, Sendable {
    public var inserted: [String]
    public var deleted: [String]
    public var reconfigured: [String]
  }

  public enum Failure: Error, Equatable, Sendable {
    case duplicate(String)
  }

  public static func compute<Row: CKDiffableRow>(previous: [Row], next: [Row]) -> Result<Changes, Failure> {
    var seen = Set<String>()
    for row in next where !seen.insert(row.id).inserted {
      return .failure(.duplicate(row.id))
    }
    let before = index(previous)
    let after = index(next)
    let inserted = next.map(\.id).filter { before[$0] == nil }
    let deleted = previous.map(\.id).filter { after[$0] == nil }
    let reconfigured = next.compactMap { row -> String? in
      guard let old = before[row.id] else { return nil }
      return old.row != row || old.above != after[row.id]?.above ? row.id : nil
    }
    return .success(Changes(inserted: inserted, deleted: deleted, reconfigured: reconfigured))
  }

  private static func index<Row: CKDiffableRow>(_ rows: [Row]) -> [String: (row: Row, above: String)] {
    var result: [String: (row: Row, above: String)] = [:]
    var above = ""
    for row in rows {
      if result[row.id] == nil { result[row.id] = (row, above) }
      above = row.neighbourKey
    }
    return result
  }
}
