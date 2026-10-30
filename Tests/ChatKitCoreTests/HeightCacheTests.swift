import ChatKitCore
import CoreGraphics
import Testing

private func key(_ id: String = "r", version: Int = 1, width: CGFloat = 400, previous: String = "user") -> CKHeightKey {
  CKHeightKey(id: id, version: version, width: width, previous: previous)
}

@Test func everyKeyPartMustMatch() {
  var cache = CKHeightCache()
  cache.store(120, for: key())
  #expect(cache.height(for: key()) == 120)
  #expect(cache.height(for: key(version: 2)) == nil)
  #expect(cache.height(for: key(width: 401)) == nil)
  #expect(cache.height(for: key(previous: "text")) == nil)
  #expect(cache.height(for: key("other")) == nil)
}

@Test func tinyHeightsAreNotStored() {
  var cache = CKHeightCache()
  cache.store(0.3, for: key())
  #expect(cache.height(for: key()) == nil)
}

@Test func pruningAndInvalidation() {
  var cache = CKHeightCache()
  cache.store(10, for: key("a"))
  cache.store(20, for: key("b"))
  cache.prune(retaining: ["b"])
  #expect(cache.height(for: key("a")) == nil)
  #expect(cache.height(for: key("b")) == 20)
  cache.invalidateAll()
  #expect(cache.height(for: key("b")) == nil)
}

@Test func theBudgetYieldsAfterFourMillisecondsAndFinishesOnce() {
  var now: Double = 0
  var queue: [() -> Void] = []
  var measured: [Int] = []
  var finished = 0
  CKPrepareBudget.run(
    items: Array(0..<10),
    clock: { now },
    schedule: { queue.append($0) },
    measure: { measured.append($0); now += 0.001 },
    done: { finished += 1 }
  )
  #expect(measured.isEmpty)
  queue.removeFirst()()
  #expect(measured == [0, 1, 2, 3])
  while !queue.isEmpty { queue.removeFirst()() }
  #expect(measured == Array(0..<10))
  #expect(finished == 1)
}

@Test func aCancelledRunStops() {
  var queue: [() -> Void] = []
  var measured = 0
  let run = CKPrepareBudget.run(items: [1, 2], clock: { 0 }, schedule: { queue.append($0) }, measure: { _ in measured += 1 }, done: {})
  run.cancel()
  while !queue.isEmpty { queue.removeFirst()() }
  #expect(measured == 0)
}
