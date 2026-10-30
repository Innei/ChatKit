import CoreGraphics
import Foundation

public struct CKMediaRef: Hashable, Sendable {
  public var id: String
  public var context: [String: String]

  public init(id: String, context: [String: String] = [:]) {
    self.id = id
    self.context = context
  }
}

public protocol CKMediaProvider: Sendable {
  func image(for ref: CKMediaRef, pixelSize: CGSize) async throws -> CGImage
  func fileURL(for ref: CKMediaRef) async throws -> URL
}

public struct CKAttachment: Identifiable, Equatable, Sendable {
  public let id: String
  public var name: String
  public var bytes: Int?
  public var symbol: String
  public var thumbnail: CGImage?
  public var media: CKMediaRef?
  public var progress: Double?
  public var failed: Bool

  public init(id: String, name: String, bytes: Int? = nil, symbol: String = "doc", thumbnail: CGImage? = nil,
              media: CKMediaRef? = nil, progress: Double? = nil, failed: Bool = false) {
    self.id = id
    self.name = name
    self.bytes = bytes
    self.symbol = symbol
    self.thumbnail = thumbnail
    self.media = media
    self.progress = progress
    self.failed = failed
  }

  public var sizeLabel: String? {
    bytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) }
  }
}
