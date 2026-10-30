import ChatKitCore
import Testing

private struct Row: CKDiffableRow {
  let id: String
  var kind: String
  var text: String
  var neighbourKey: String { kind }
}

private func changes(_ previous: [Row], _ next: [Row]) throws -> CKRowDiff.Changes {
  try CKRowDiff.compute(previous: previous, next: next).get()
}

@Test func insertsAndDeletesFollowListOrder() throws {
  let a = Row(id: "a", kind: "user", text: "hi")
  let b = Row(id: "b", kind: "text", text: "yo")
  let c = Row(id: "c", kind: "text", text: "new")
  let result = try changes([a, b], [a, c])
  #expect(result.inserted == ["c"])
  #expect(result.deleted == ["b"])
  #expect(result.reconfigured.isEmpty)
}

@Test func changedContentReconfigures() throws {
  let a = Row(id: "a", kind: "text", text: "partial")
  let result = try changes([a], [Row(id: "a", kind: "text", text: "partial reply")])
  #expect(result.reconfigured == ["a"])
}

@Test func aNewPredecessorKindReconfiguresAnUnchangedRow() throws {
  let user = Row(id: "u", kind: "user", text: "q")
  let delivery = Row(id: "d", kind: "delivery", text: "sent")
  let reply = Row(id: "r", kind: "text", text: "answer")
  let result = try changes([user, delivery, reply], [user, reply])
  #expect(result.deleted == ["d"])
  #expect(result.reconfigured == ["r"])
}

@Test func theSamePredecessorKindLeavesARowAlone() throws {
  let first = Row(id: "1", kind: "text", text: "one")
  let second = Row(id: "2", kind: "text", text: "two")
  let replacement = Row(id: "3", kind: "text", text: "three")
  let result = try changes([first, second], [replacement, second])
  #expect(result.reconfigured.isEmpty)
}

@Test func duplicateIdsAreReportedNotCrashed() {
  let a = Row(id: "a", kind: "text", text: "x")
  #expect(throws: CKRowDiff.Failure.duplicate("a")) {
    try CKRowDiff.compute(previous: [], next: [a, a]).get()
  }
}
