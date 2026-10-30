import ChatKitCore
import CoreGraphics
import Foundation
import Testing

private struct FakeProvider: CKMediaProvider {
  func image(for ref: CKMediaRef, pixelSize: CGSize) async throws -> CGImage {
    let context = CGContext(data: nil, width: Int(pixelSize.width), height: Int(pixelSize.height), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    return context!.makeImage()!
  }

  func fileURL(for ref: CKMediaRef) async throws -> URL {
    URL(fileURLWithPath: "/tmp/\(ref.id)")
  }
}

@Test func aProviderAnswersForARefAtThePixelSize() async throws {
  let provider: any CKMediaProvider = FakeProvider()
  let image = try await provider.image(for: CKMediaRef(id: "img-1"), pixelSize: CGSize(width: 64, height: 32))
  #expect(image.width == 64)
  #expect(image.height == 32)
  #expect(try await provider.fileURL(for: CKMediaRef(id: "img-1")).lastPathComponent == "img-1")
}

@Test func attachmentEqualityIncludesProgressAndFailure() {
  let base = CKAttachment(id: "a", name: "notes.txt", bytes: 2048)
  var uploading = base
  uploading.progress = 0.5
  var failed = base
  failed.failed = true
  #expect(base != uploading)
  #expect(base != failed)
  #expect(base == CKAttachment(id: "a", name: "notes.txt", bytes: 2048))
}

@Test func attachmentDetailFormatsBytes() {
  #expect(CKAttachment(id: "a", name: "big.zip", bytes: 2_500_000).sizeLabel == ByteCountFormatter.string(fromByteCount: 2_500_000, countStyle: .file))
  #expect(CKAttachment(id: "b", name: "unknown").sizeLabel == nil)
}
