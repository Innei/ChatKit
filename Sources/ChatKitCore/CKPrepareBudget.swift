import Foundation

public final class CKPrepareRun {
  fileprivate var cancelled = false

  public func cancel() { cancelled = true }
}

public enum CKPrepareBudget {
  public static let defaultBudget: TimeInterval = 0.004

  @discardableResult
  public static func run<Item>(
    items: [Item],
    budget: TimeInterval = defaultBudget,
    clock: @escaping () -> TimeInterval,
    schedule: @escaping (@escaping () -> Void) -> Void,
    measure: @escaping (Item) -> Void,
    done: @escaping () -> Void
  ) -> CKPrepareRun {
    let run = CKPrepareRun()
    var index = 0
    func slice() {
      guard !run.cancelled else { return }
      let start = clock()
      while index < items.count {
        measure(items[index])
        index += 1
        if clock() - start >= budget { break }
      }
      if index < items.count {
        schedule(slice)
      } else {
        done()
      }
    }
    schedule(slice)
    return run
  }
}
