#if os(macOS)
import AppKit
import ChatKitCore

@MainActor
public final class CKAttachmentStripView: NSView {
  public struct Labels {
    public var remove: String
    public var failed: String
    public var uploading: (Int) -> String

    public init(remove: String, failed: String, uploading: @escaping (Int) -> String) {
      self.remove = remove
      self.failed = failed
      self.uploading = uploading
    }
  }

  public static let spacing: CGFloat = 8
  public var labels = Labels(remove: "Remove", failed: "Failed", uploading: { "Uploading \($0)%" })
  public var editable = false
  public var trailing = false {
    didSet { needsLayout = true }
  }
  public var onPreview: (CKAttachment) -> Void = { _ in }
  public var onRemove: (CKAttachment) -> Void = { _ in }
  public private(set) var pills: [CKAttachmentPill] = []
  private var height: NSLayoutConstraint!

  public override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    height = heightAnchor.constraint(equalToConstant: 0)
    height.priority = .init(999)
    height.isActive = true
  }

  public required init?(coder: NSCoder) { nil }

  public func render(_ attachments: [CKAttachment]) {
    let reusable = Dictionary(pills.map { ($0.attachment.id, $0) }, uniquingKeysWith: { first, _ in first })
    let next = attachments.map { attachment in
      let pill = reusable[attachment.id] ?? CKAttachmentPill()
      pill.configure(attachment, editable: editable, labels: labels)
      pill.onPress = { [weak self] in self?.onPreview($0) }
      pill.onRemove = { [weak self] in self?.onRemove($0) }
      return pill
    }
    for pill in pills where !next.contains(where: { $0 === pill }) { pill.removeFromSuperview() }
    for pill in next where pill.superview !== self { addSubview(pill) }
    pills = next
    needsLayout = true
  }

  public override var isFlipped: Bool { true }

  public override func layout() {
    super.layout()
    let width = bounds.width
    var lines: [[CKAttachmentPill]] = [[]]
    var x: CGFloat = 0
    for pill in pills {
      let size = pill.preferredSize(maxWidth: width)
      if x > 0, x + size.width > width {
        lines.append([])
        x = 0
      }
      pill.frame.size = size
      lines[lines.count - 1].append(pill)
      x += size.width + Self.spacing
    }
    var y: CGFloat = 0
    for line in lines where !line.isEmpty {
      let used = line.map(\.frame.width).reduce(0, +) + Self.spacing * CGFloat(line.count - 1)
      var cursor = trailing ? width - used : 0
      for pill in line {
        pill.frame.origin = NSPoint(x: cursor.rounded(), y: y)
        cursor += pill.frame.width + Self.spacing
      }
      y += CKAttachmentPill.height + Self.spacing
    }
    let total = pills.isEmpty ? 0 : y - Self.spacing
    if abs(height.constant - total) > 0.5 { height.constant = total }
  }
}

@MainActor
public final class CKAttachmentPill: NSView {
  static let height: CGFloat = 44
  public private(set) var attachment = CKAttachment(id: "", name: "")
  public private(set) var removeButton: NSButton?
  public private(set) var progress: NSProgressIndicator?
  var onPress: (CKAttachment) -> Void = { _ in }
  var onRemove: (CKAttachment) -> Void = { _ in }
  private let icon = NSImageView()
  private let name = NSTextField(labelWithString: "")
  private let detail = NSTextField(labelWithString: "")

  init() {
    super.init(frame: .zero)
    wantsLayer = true
    layer?.cornerRadius = 10
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.wantsLayer = true
    icon.layer?.cornerRadius = 6
    icon.layer?.masksToBounds = true
    name.font = .systemFont(ofSize: 12, weight: .medium)
    name.lineBreakMode = .byTruncatingMiddle
    detail.font = .systemFont(ofSize: 11)
    detail.textColor = .secondaryLabelColor
    for view in [icon, name, detail] as [NSView] { addSubview(view) }
    setAccessibilityElement(true)
    setAccessibilityRole(.button)
  }

  required init?(coder: NSCoder) { nil }

  func configure(_ attachment: CKAttachment, editable: Bool, labels: CKAttachmentStripView.Labels) {
    self.attachment = attachment
    name.stringValue = attachment.name
    if let thumbnail = attachment.thumbnail {
      icon.image = NSImage(cgImage: thumbnail, size: .zero)
      icon.contentTintColor = nil
    } else {
      icon.image = NSImage(systemSymbolName: attachment.symbol, accessibilityDescription: nil)
      icon.contentTintColor = .secondaryLabelColor
    }
    let status = status(attachment, labels: labels)
    detail.stringValue = status ?? ""
    detail.textColor = attachment.failed ? .systemRed : .secondaryLabelColor
    configureProgress(attachment)
    configureRemove(editable, label: labels.remove)
    setAccessibilityLabel([attachment.name, status].compactMap { $0 }.joined(separator: ", "))
    needsLayout = true
  }

  func preferredSize(maxWidth: CGFloat) -> NSSize {
    let text = max(name.attributedStringValue.size().width, detail.attributedStringValue.size().width) + 8
    let chrome: CGFloat = 8 + 28 + 8 + 10 + (removeButton == nil ? 0 : 20)
    return NSSize(width: min(maxWidth, max(120, min(240, ceil(text) + chrome))), height: Self.height)
  }

  public override func layout() {
    super.layout()
    icon.frame = NSRect(x: 8, y: (bounds.height - 28) / 2, width: 28, height: 28)
    let right = bounds.width - (removeButton == nil ? 10 : 28)
    name.frame = NSRect(x: 44, y: bounds.height - 22, width: max(0, right - 44), height: 16)
    detail.frame = NSRect(x: 44, y: 6, width: max(0, right - 44), height: 14)
    progress?.frame = NSRect(x: 44, y: 9, width: max(0, right - 44), height: 6)
    removeButton?.frame = NSRect(x: bounds.width - 24, y: (bounds.height - 16) / 2, width: 16, height: 16)
  }

  public override var wantsUpdateLayer: Bool { true }

  public override func updateLayer() {
    layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
  }

  public override func hitTest(_ point: NSPoint) -> NSView? {
    guard let hit = super.hitTest(point) else { return nil }
    if let removeButton, hit.isDescendant(of: removeButton) { return hit }
    return self
  }

  public override func mouseDown(with event: NSEvent) {}

  public override func mouseUp(with event: NSEvent) {
    guard event.clickCount <= 1, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
    onPress(attachment)
  }

  public override func accessibilityPerformPress() -> Bool {
    onPress(attachment)
    return true
  }

  private func status(_ attachment: CKAttachment, labels: CKAttachmentStripView.Labels) -> String? {
    if attachment.failed { return labels.failed }
    if let progress = attachment.progress, progress < 1 { return labels.uploading(Int((progress * 100).rounded())) }
    return attachment.sizeLabel
  }

  private func configureProgress(_ attachment: CKAttachment) {
    guard let value = attachment.progress, value < 1, !attachment.failed else {
      progress?.removeFromSuperview()
      progress = nil
      detail.isHidden = false
      return
    }
    let bar = progress ?? NSProgressIndicator()
    bar.style = .bar
    bar.controlSize = .small
    bar.isIndeterminate = false
    bar.minValue = 0
    bar.maxValue = 100
    bar.doubleValue = (value * 100).rounded()
    if bar.superview == nil { addSubview(bar) }
    progress = bar
    detail.isHidden = true
  }

  private func configureRemove(_ editable: Bool, label: String) {
    guard editable else {
      removeButton?.removeFromSuperview()
      removeButton = nil
      return
    }
    let button = removeButton ?? NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: label) ?? NSImage(), target: self, action: #selector(remove))
    button.isBordered = false
    button.title = ""
    button.imagePosition = .imageOnly
    button.contentTintColor = .tertiaryLabelColor
    button.setAccessibilityLabel(label)
    if button.superview == nil { addSubview(button) }
    removeButton = button
  }

  @objc private func remove() { onRemove(attachment) }
}
#endif
