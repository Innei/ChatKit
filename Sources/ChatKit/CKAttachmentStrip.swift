import UIKit

open class CKAttachmentStrip: UIScrollView {
  public var onRemove: ((String) -> Void)?
  public var onPreview: ((String) -> Void)?
  private let stack = UIStackView()
  private var rendered: [CKAttachmentItem] = []
  private var pills: [String: CKGlassSurface] = [:]
  private var tileImages: [String: UIImageView] = [:]
  public var onHeightChange: (() -> Void)?
  public var hasVisiblePills: Bool { !pills.isEmpty }

  public var style: CKAttachmentStyle {
    didSet {
      let items = rendered
      for surface in pills.values {
        surface.onHidden = nil
        surface.removeFromSuperview()
      }
      pills.removeAll()
      tileImages.removeAll()
      rendered = []
      stack.spacing = max(0, style.spacing)
      render(items, animatedInsertion: false)
      onHeightChange?()
    }
  }

  public init(style: CKAttachmentStyle = CKAttachmentStyle()) {
    self.style = style
    super.init(frame: .zero)
    showsHorizontalScrollIndicator = false
    alwaysBounceHorizontal = false
    stack.axis = .horizontal
    stack.spacing = max(0, style.spacing)
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
      stack.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
      stack.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor),
    ])
  }
  public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  public func render(_ items: [CKAttachmentItem], animatedRemoval: Bool = false, animatedInsertion: Bool = true) {
    guard items != rendered else { return }
    let previous = rendered
    rendered = items
    for (id, surface) in pills where !items.contains(where: { $0.id == id }) {
      surface.setVisible(false, animated: animatedRemoval)
    }
    for (index, item) in items.enumerated() {
      if let existing = pills[item.id], previous.contains(item) {
        stack.removeArrangedSubview(existing)
        stack.insertArrangedSubview(existing, at: min(index, stack.arrangedSubviews.count))
        existing.setVisible(true, animated: animatedInsertion)
        continue
      }
      // A restored draft may reuse an id while an old pill is leaving.
      if let previous = pills.removeValue(forKey: item.id) {
        previous.onHidden = nil
        previous.removeFromSuperview()
      }
      let surface = style.tiles ? tile(item) : pill(item)
      pills[item.id] = surface
      surface.onHidden = { [weak self, weak surface] in
        guard let self, let surface, self.pills[item.id] === surface,
              !self.rendered.contains(where: { $0.id == item.id }) else { return }
        self.pills.removeValue(forKey: item.id)
        self.tileImages.removeValue(forKey: item.id)
        surface.removeFromSuperview()
        self.onHeightChange?()
      }
      stack.insertArrangedSubview(surface, at: min(index, stack.arrangedSubviews.count))
      surface.setVisible(true, animated: animatedInsertion)
    }
  }

  public func attachmentFrame(id: String) -> CGRect? {
    guard rendered.contains(where: { $0.id == id }), let view = pills[id] else { return nil }
    return view.convert(view.bounds, to: self)
  }

  public func thumbnailView(id: String) -> UIView? {
    if style.tiles { return rendered.contains(where: { $0.id == id }) ? tileImages[id] : nil }
    guard rendered.contains(where: { $0.id == id && $0.thumbnail != nil }),
          let button = pills[id]?.contentView.subviews.first as? UIButton else { return nil }
    return button.imageView
  }

  public func snapshot(id: String) -> UIView? {
    guard rendered.contains(where: { $0.id == id }), let pill = pills[id] else { return nil }
    return pill.snapshotView(afterScreenUpdates: false)
  }

  private func pill(_ item: CKAttachmentItem) -> CKGlassSurface {
    var config = UIButton.Configuration.plain()
    config.image = item.thumbnail?.withRenderingMode(.alwaysOriginal) ?? UIImage(systemName: item.symbol)
    config.imagePadding = 5
    config.baseForegroundColor = style.theme.textColor
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12)
    config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 11, bottom: 0, trailing: 32)
    config.attributedTitle = AttributedString(item.name, attributes: AttributeContainer([
      .font: style.font,
    ]))
    config.titleLineBreakMode = .byTruncatingMiddle
    let button = UIButton(configuration: config)
    button.accessibilityLabel = item.previewAccessibilityLabel
    button.addAction(UIAction { [weak self] _ in self?.onPreview?(item.id) }, for: .touchUpInside)
    let remove = UIButton(type: .system)
    remove.setImage(UIImage(systemName: style.removeSymbol), for: .normal)
    remove.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 13), forImageIn: .normal)
    remove.tintColor = style.theme.mutedTextColor
    remove.accessibilityLabel = item.removeAccessibilityLabel
    remove.addAction(UIAction { [weak self] _ in self?.onRemove?(item.id) }, for: .touchUpInside)
    let surface = CKGlassSurface(interactive: true)
    if let radius = style.cornerRadius {
      surface.cornerConfiguration = .corners(radius: .fixed(max(0, radius)))
    } else {
      surface.cornerConfiguration = .capsule()
    }
    surface.tintColor = style.theme.tintColor
    surface.contentView.addSubview(button)
    surface.contentView.addSubview(remove)
    button.translatesAutoresizingMaskIntoConstraints = false
    remove.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: surface.contentView.topAnchor), button.bottomAnchor.constraint(equalTo: surface.contentView.bottomAnchor),
      button.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor), button.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
      remove.topAnchor.constraint(equalTo: surface.contentView.topAnchor), remove.bottomAnchor.constraint(equalTo: surface.contentView.bottomAnchor),
      remove.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor, constant: -4),
      remove.widthAnchor.constraint(equalToConstant: 30),
      surface.widthAnchor.constraint(lessThanOrEqualToConstant: max(80, style.maximumWidth)),
      surface.heightAnchor.constraint(equalToConstant: max(34, style.height)),
    ])
    return surface
  }

  private func tile(_ item: CKAttachmentItem) -> CKGlassSurface {
    let surface = CKGlassSurface(material: false)
    surface.layer.cornerRadius = 10
    surface.layer.cornerCurve = .continuous
    surface.clipsToBounds = true
    surface.contentView.backgroundColor = item.thumbnail == nil ? .tertiarySystemFill : .clear
    let preview = UIButton(type: .custom)
    preview.accessibilityLabel = item.previewAccessibilityLabel
    preview.addAction(UIAction { [weak self] _ in self?.onPreview?(item.id) }, for: .touchUpInside)
    let side = max(34, style.tileSide)
    var constraints = [surface.heightAnchor.constraint(equalToConstant: side)]
    if let thumbnail = item.thumbnail {
      let image = UIImageView(image: thumbnail)
      image.contentMode = .scaleAspectFill
      image.clipsToBounds = true
      surface.contentView.addSubview(image)
      image.translatesAutoresizingMaskIntoConstraints = false
      constraints += pin(image, to: surface.contentView)
      constraints.append(surface.widthAnchor.constraint(equalToConstant: side))
      tileImages[item.id] = image
    } else {
      let icon = UIImageView(image: UIImage(systemName: item.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15)))
      icon.tintColor = style.theme.mutedTextColor
      icon.setContentHuggingPriority(.required, for: .horizontal)
      let name = UILabel()
      name.text = item.name
      name.font = style.font.withSize(14)
      name.textColor = style.theme.textColor
      name.lineBreakMode = .byTruncatingMiddle
      let detail = UILabel()
      detail.text = item.detail
      detail.font = style.font.withSize(12)
      detail.textColor = style.theme.mutedTextColor
      detail.isHidden = item.detail == nil
      let text = UIStackView(arrangedSubviews: [name, detail])
      text.axis = .vertical
      let row = UIStackView(arrangedSubviews: [icon, text])
      row.spacing = 8
      row.alignment = .center
      row.isUserInteractionEnabled = false
      surface.contentView.addSubview(row)
      row.translatesAutoresizingMaskIntoConstraints = false
      constraints += [
        row.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor, constant: 10),
        row.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor, constant: -28),
        row.centerYAnchor.constraint(equalTo: surface.contentView.centerYAnchor),
        surface.widthAnchor.constraint(lessThanOrEqualToConstant: max(80, style.maximumWidth)),
      ]
    }
    surface.contentView.addSubview(preview)
    preview.translatesAutoresizingMaskIntoConstraints = false
    constraints += pin(preview, to: surface.contentView)
    let remove = UIButton(type: .custom)
    remove.accessibilityLabel = item.removeAccessibilityLabel
    remove.addAction(UIAction { [weak self] _ in self?.onRemove?(item.id) }, for: .touchUpInside)
    let badge = UIImageView(image: UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)))
    badge.tintColor = .white
    badge.contentMode = .center
    badge.backgroundColor = UIColor.black.withAlphaComponent(item.thumbnail == nil ? 0.35 : 0.55)
    badge.layer.cornerRadius = 9
    badge.isUserInteractionEnabled = false
    remove.addSubview(badge)
    surface.contentView.addSubview(remove)
    remove.translatesAutoresizingMaskIntoConstraints = false
    badge.translatesAutoresizingMaskIntoConstraints = false
    constraints += [
      remove.topAnchor.constraint(equalTo: surface.contentView.topAnchor),
      remove.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
      remove.widthAnchor.constraint(equalToConstant: 30), remove.heightAnchor.constraint(equalToConstant: 30),
      badge.widthAnchor.constraint(equalToConstant: 18), badge.heightAnchor.constraint(equalToConstant: 18),
      badge.topAnchor.constraint(equalTo: remove.topAnchor, constant: 3),
      badge.trailingAnchor.constraint(equalTo: remove.trailingAnchor, constant: -3),
    ]
    NSLayoutConstraint.activate(constraints)
    return surface
  }

  private func pin(_ view: UIView, to host: UIView) -> [NSLayoutConstraint] {
    [view.topAnchor.constraint(equalTo: host.topAnchor), view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
     view.leadingAnchor.constraint(equalTo: host.leadingAnchor), view.trailingAnchor.constraint(equalTo: host.trailingAnchor)]
  }
}
