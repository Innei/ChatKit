#if os(macOS)
import AppKit
import ChatAppKit
import ChatKitCore
import Testing

@MainActor
private func strip(_ attachments: [CKAttachment], editable: Bool = false) -> CKAttachmentStripView {
  let view = CKAttachmentStripView()
  view.editable = editable
  view.frame = NSRect(x: 0, y: 0, width: 420, height: 200)
  view.render(attachments)
  view.layoutSubtreeIfNeeded()
  return view
}

@MainActor @Test func onePillPerAttachmentWithSizeAndProgressLabels() {
  let view = strip([
    CKAttachment(id: "a", name: "report.pdf", bytes: 2048),
    CKAttachment(id: "b", name: "photo.png", symbol: "photo", progress: 0.4),
  ])
  #expect(view.pills.count == 2)
  #expect(view.pills[0].accessibilityLabel() == "report.pdf, 2 KB")
  #expect(view.pills[1].accessibilityLabel() == "photo.png, Uploading 40%")
  #expect(view.pills[1].progress?.doubleValue == 40)
}

@MainActor @Test func displayModeHasNoRemoveButtonsAndPreviewsOnPress() {
  var previewed: [String] = []
  let view = strip([CKAttachment(id: "a", name: "report.pdf")])
  view.onPreview = { previewed.append($0.id) }
  #expect(view.pills[0].removeButton == nil)
  _ = view.pills[0].accessibilityPerformPress()
  #expect(previewed == ["a"])
}

@MainActor @Test func editableStripsRemove() {
  var removed: [String] = []
  let view = strip([CKAttachment(id: "a", name: "report.pdf")], editable: true)
  view.onRemove = { removed.append($0.id) }
  view.pills[0].removeButton?.performClick(nil)
  #expect(removed == ["a"])
}

@MainActor @Test func pillsWrapToTheWidthAndReportTheirHeight() {
  let view = strip((0..<6).map { CKAttachment(id: "f\($0)", name: "file-\($0).txt") })
  let rows = Set(view.pills.map(\.frame.minY))
  #expect(rows.count > 1)
  #expect(view.fittingSize.height >= view.pills.map(\.frame.maxY).max()!)
}
#endif
