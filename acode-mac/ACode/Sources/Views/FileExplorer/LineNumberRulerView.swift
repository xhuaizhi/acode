import AppKit

/// 行号 ruler — 显示在 NSTextView 左侧的行号栏
class LineNumberRulerView: NSRulerView {

    private var textView: NSTextView? {
        clientView as? NSTextView
    }

    var lineNumberColor: NSColor = NSColor.secondaryLabelColor {
        didSet { needsDisplay = true }
    }

    var lineNumberFont: NSFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular) {
        didSet { updateThickness(); needsDisplay = true }
    }

    var gutterBackgroundColor: NSColor = NSColor.clear {
        didSet { needsDisplay = true }
    }

    private var isUpdatingThickness = false

    init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.ruleThickness = 40
        self.clientView = scrollView.documentView

        if let textView = scrollView.documentView as? NSTextView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(textDidChange(_:)),
                name: NSText.didChangeNotification,
                object: textView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        updateThickness()
        needsDisplay = true
    }

    @objc private func boundsDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    /// 根据总行数调整 ruler 宽度（仅在文本变化时调用，不在绘制期间调用）
    private func updateThickness() {
        guard !isUpdatingThickness else { return }
        isUpdatingThickness = true
        defer { isUpdatingThickness = false }

        guard let textView = textView else { return }
        let lineCount = max(1, textView.string.components(separatedBy: "\n").count)
        let digits = max(3, String(lineCount).count + 1)
        let attrs: [NSAttributedString.Key: Any] = [.font: lineNumberFont]
        let digitWidth = ("8" as NSString).size(withAttributes: attrs).width
        let newThickness = CGFloat(digits) * digitWidth + 16
        if abs(ruleThickness - newThickness) > 2 {
            ruleThickness = newThickness
        }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let contentWidth = scrollView?.contentSize.width ?? 0
        guard contentWidth > 1 else { return }

        gutterBackgroundColor.setFill()
        rect.fill()

        let string = textView.string as NSString
        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let textInset = textView.textContainerInset

        let attrs: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]

        guard string.length > 0 else {
            let lineStr = "1" as NSString
            let size = lineStr.size(withAttributes: attrs)
            let x = ruleThickness - size.width - 8
            let y = textInset.height + 2
            lineStr.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            return
        }

        let totalGlyphs = layoutManager.numberOfGlyphs
        guard totalGlyphs > 0 else { return }
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard visibleGlyphRange.length > 0 else { return }
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        var lineNumber = 1

        if visibleCharRange.location > 0 {
            let beforeVisible = string.substring(to: visibleCharRange.location)
            lineNumber = beforeVisible.components(separatedBy: "\n").count
        }

        var charIndex = visibleCharRange.location
        while charIndex < NSMaxRange(visibleCharRange) {
            let lineRange = string.lineRange(for: NSRange(location: charIndex, length: 0))

            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            guard glyphRange.location < totalGlyphs else { break }
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)

            lineRect.origin.y += textInset.height - visibleRect.origin.y

            let lineStr = "\(lineNumber)" as NSString
            let size = lineStr.size(withAttributes: attrs)
            let x = ruleThickness - size.width - 8
            let y = lineRect.origin.y + (lineRect.height - size.height) / 2

            lineStr.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

            lineNumber += 1
            let nextIndex = NSMaxRange(lineRange)
            if nextIndex <= charIndex { break }
            charIndex = nextIndex
        }
    }
}
