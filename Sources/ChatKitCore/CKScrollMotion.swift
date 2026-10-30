import Foundation

public enum CKScrollMotion: Sendable {
  public static let resumeDistance: Double = 80
  public static let sendDuration: Double = 0.25

  // Time-based convergence keeps a moving destination continuous across updates
  // and behaves the same at 60 and 120 Hz. Snap only a subpixel remainder.
  public static func advance(_ current: Double, toward target: Double, elapsed: Double, response: Double, minimumStep: Double = 0) -> Double {
    let next = current + (target - current) * (1 - exp(-max(0, elapsed) / response))
    // Scroll views round offsets to their pixel grid. A step smaller than one
    // pixel can otherwise round back forever while the display link keeps firing.
    if elapsed > 0 && abs(next - current) < minimumStep { return target }
    return abs(target - next) <= 0.5 ? target : next
  }

  public static func bottom(contentHeight: Double, viewportHeight: Double, topInset: Double, bottomInset: Double) -> Double {
    max(-topInset, contentHeight - viewportHeight + bottomInset)
  }

  public static func sendProgress(elapsed: Double) -> Double {
    let progress = min(1, max(0, elapsed / sendDuration))
    return 1 - pow(1 - progress, 3)
  }

  public static func reserve(anchorMinY: Double, contentHeight: Double, viewportHeight: Double, topInset: Double, bottomInset: Double) -> Double {
    max(0, anchorMinY - topInset - (contentHeight - viewportHeight + bottomInset))
  }
}
