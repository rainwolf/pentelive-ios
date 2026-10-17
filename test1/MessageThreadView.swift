import UIKit

/// Builds the attributed text for a message thread. Pure: no UI state.
enum MessageThreadRenderer {
    /// Marks the range of a replied-to entry; the view draws a vertical bar beside it.
    static let quoteBarKey = NSAttributedString.Key("pente.messageThread.quoteBar")
    static let replyIndent: CGFloat = 16
    static let separator = "\n\n"

    static let defaultDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// "<from> · <date>" (U+00B7).
    static func header(for entry: MessageThreadEntry, dateFormatter: DateFormatter = defaultDateFormatter) -> String {
        return "\(entry.from) \u{00B7} \(dateFormatter.string(from: entry.date))"
    }

    /// One attributed string, newest first (thread.entries order), blank line between entries.
    /// Body is plain text, never interpreted as HTML. Subject is not shown.
    static func attributedText(for thread: MessageThread, dateFormatter: DateFormatter = defaultDateFormatter) -> NSAttributedString {
        let bodyFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.systemFont(ofSize: 18))
        let boldDescriptor = bodyFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? bodyFont.fontDescriptor
        let headerFont = UIFont(descriptor: boldDescriptor, size: bodyFont.pointSize)

        let result = NSMutableAttributedString()
        for (i, entry) in thread.entries.enumerated() {
            if i > 0 { result.append(NSAttributedString(string: separator, attributes: [.font: bodyFont])) }
            let isReply = (entry === thread.replyTo)
            let color: UIColor = isReply ? .secondaryLabel : .label

            var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]
            if isReply {
                let p = NSMutableParagraphStyle()
                p.firstLineHeadIndent = replyIndent
                p.headIndent = replyIndent
                attrs[.paragraphStyle] = p
            }

            let piece = NSMutableAttributedString()
            piece.append(NSAttributedString(string: header(for: entry, dateFormatter: dateFormatter) + "\n",
                                            attributes: attrs.merging([.font: headerFont]) { $1 }))
            piece.append(NSAttributedString(string: entry.body,
                                            attributes: attrs.merging([.font: bodyFont]) { $1 }))
            if isReply {
                piece.addAttribute(quoteBarKey, value: true, range: NSRange(location: 0, length: piece.length))
            }
            result.append(piece)
        }
        return result
    }
}

/// Non-editable, selectable text view showing a MessageThread, with a real vertical bar
/// drawn in the indent gutter beside the replied-to entry.
@objc final class MessageThreadView: UITextView {
    private let barView = QuoteBarView()

    /// Bar rects in content coordinates (for tests).
    var quoteBarRects: [CGRect] { barView.rects }

    @objc override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isEditable = false
        isSelectable = true
        dataDetectorTypes = .link
        backgroundColor = .clear
        // Touch layoutManager now so the TextKit 1 fallback happens before any layout.
        _ = layoutManager
        barView.isUserInteractionEnabled = false
        barView.backgroundColor = .clear
        insertSubview(barView, at: 0)
    }

    @objc func show(_ thread: MessageThread) {
        attributedText = MessageThreadRenderer.attributedText(for: thread)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBars()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        barView.setNeedsDisplay()
    }

    private func updateBars() {
        let storage = textStorage
        guard storage.length > 0 else { barView.rects = []; barView.frame = .zero; return }
        layoutManager.ensureLayout(for: textContainer)
        let origin = CGPoint(x: textContainerInset.left + textContainer.lineFragmentPadding, y: textContainerInset.top)
        var rects: [CGRect] = []
        storage.enumerateAttribute(MessageThreadRenderer.quoteBarKey, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard value != nil else { return }
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var union = CGRect.null
            layoutManager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer) { r, _ in
                union = union.union(r)
            }
            guard !union.isNull else { return }
            rects.append(CGRect(x: origin.x + 2, y: origin.y + union.minY, width: 2, height: union.height))
        }
        // Size the bar view to just the bars (not the whole contentSize) so a long
        // thread does not allocate a huge backing store.
        let bounds = rects.reduce(CGRect.null) { $0.union($1) }
        barView.frame = bounds.isNull ? .zero : bounds
        barView.rects = rects
    }
}

private final class QuoteBarView: UIView {
    /// In the text view's content coordinates.
    var rects: [CGRect] = [] {
        didSet { if rects != oldValue { setNeedsDisplay() } }
    }

    override func draw(_ rect: CGRect) {
        UIColor.secondaryLabel.setFill()
        for r in rects {
            let local = r.offsetBy(dx: -frame.minX, dy: -frame.minY)
            UIBezierPath(roundedRect: local, cornerRadius: local.width / 2).fill()
        }
    }
}
