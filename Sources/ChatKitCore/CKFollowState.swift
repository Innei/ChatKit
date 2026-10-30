import CoreGraphics

public struct CKFollowState: Equatable, Sendable {
  public enum Event: Equatable, Sendable {
    case send(queued: Bool)
    case anchorableRowArrived(String)
    case clearAnchor
    case jumpToBottom
    case scrollEnded(distanceFromBottom: CGFloat)
    case liveTurnStarted(distanceFromTail: CGFloat)
    case pause
    case unfollow
  }

  public private(set) var follows = true
  public private(set) var pausedByGesture = false
  public private(set) var awaitingAnchor = false
  public private(set) var anchoredRowID: String?

  public init() {}

  public mutating func handle(_ event: Event) {
    switch event {
    case .send(let queued):
      guard !queued else { return }
      resume()
      awaitingAnchor = true
    case .anchorableRowArrived(let id):
      guard awaitingAnchor else { return }
      anchoredRowID = id
      awaitingAnchor = false
      resume()
    case .clearAnchor:
      anchoredRowID = nil
    case .jumpToBottom:
      resume()
    case .scrollEnded(let distance):
      if distance <= 1 { resume() }
    case .liveTurnStarted(let distance):
      if !follows, !pausedByGesture, distance < CGFloat(CKScrollMotion.resumeDistance) { follows = true }
    case .pause:
      follows = false
      pausedByGesture = true
      awaitingAnchor = false
    case .unfollow:
      follows = false
    }
  }

  private mutating func resume() {
    follows = true
    pausedByGesture = false
  }
}

public struct CKScrollAnchor: Equatable, Sendable {
  public let rowID: String
  public let delta: CGFloat

  public static func capture(rowID: String, rowMinY: CGFloat, offset: CGFloat) -> CKScrollAnchor {
    CKScrollAnchor(rowID: rowID, delta: rowMinY - offset)
  }

  public func target(rowMinY: CGFloat, topRubberBanding: Bool) -> CGFloat? {
    topRubberBanding ? nil : rowMinY - delta
  }
}
