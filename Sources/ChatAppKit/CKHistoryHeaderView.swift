#if os(macOS)
import AppKit

@MainActor
public final class CKHistoryHeaderView: NSView {
  public enum State: Int { case more, loading, start }

  public struct Labels {
    public var more: String
    public var start: String

    public init(more: String, start: String) {
      self.more = more
      self.start = start
    }
  }

  static let height: CGFloat = 48
  public var labels = Labels(more: "Load Earlier", start: "Beginning of Session") {
    didSet { render() }
  }
  var onLoad: () -> Void = {}
  var state = State.more {
    didSet { render() }
  }
  private let button = NSButton()
  private let caption = NSTextField(labelWithString: "")
  private let spinner = NSProgressIndicator()

  init() {
    super.init(frame: .zero)
    button.bezelStyle = .push
    button.controlSize = .small
    button.target = self
    button.action = #selector(load)
    caption.textColor = .tertiaryLabelColor
    caption.font = .preferredFont(forTextStyle: .caption1)
    spinner.style = .spinning
    spinner.controlSize = .small
    let stack = NSStackView(views: [spinner, button, caption])
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    render()
  }

  required init?(coder: NSCoder) { nil }

  public var stateName: String { "\(state)" }

  private func render() {
    button.title = labels.more
    caption.stringValue = labels.start
    button.isHidden = state != .more
    caption.isHidden = state != .start
    spinner.isHidden = state != .loading
    if state == .loading { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
  }

  @objc private func load() { onLoad() }
}
#endif
