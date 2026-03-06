import SwiftUI
import AppKit

/// 文件编辑器 — 支持文本编辑、图片预览、二进制文件提示
struct FileEditorView: View {
    let fileURL: URL
    @State private var content: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isModified = false
    @State private var fileType: FileContentType = .text

    enum FileContentType {
        case text
        case image
        case unsupported(String)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch fileType {
                case .text:
                    FileTextEditor(text: $content, isModified: $isModified, fileURL: fileURL)
                case .image:
                    ImagePreviewView(fileURL: fileURL)
                case .unsupported(let ext):
                    VStack(spacing: 12) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("无法预览此文件类型")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text(".\(ext)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.6))
                        Button("用系统默认应用打开") {
                            NSWorkspace.shared.open(fileURL)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { loadFile() }
        .onChange(of: fileURL) { loadFile() }
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "svg", "ico", "heic", "heif"
    ]

    private static let textExtensions: Set<String> = [
        "swift", "js", "ts", "jsx", "tsx", "json", "md", "txt", "py",
        "html", "css", "scss", "less", "xml", "yaml", "yml", "toml",
        "sh", "bash", "zsh", "fish", "rs", "go", "c", "h", "cpp", "m",
        "java", "kt", "rb", "php", "sql", "r", "lua", "vim", "conf",
        "ini", "cfg", "env", "gitignore", "dockerignore", "makefile",
        "dockerfile", "readme", "license", "changelog", "editorconfig",
        "lock", "log", "csv", "tsv", "plist", "strings", "entitlements",
        "pbxproj", "xcscheme", "xcworkspacedata", "resolved",
        ""
    ]

    private static let specialFileNames: Set<String> = [
        "makefile", "dockerfile", "readme", "license", "changelog",
        "gemfile", "podfile", "procfile", "rakefile", "vagrantfile",
        ".gitignore", ".gitattributes", ".editorconfig", ".env"
    ]

    private func loadFile() {
        isLoading = true
        errorMessage = nil
        isModified = false

        let ext = fileURL.pathExtension.lowercased()
        let fileName = fileURL.lastPathComponent.lowercased()

        // 图片（无需读磁盘，立即返回）
        if Self.imageExtensions.contains(ext) {
            fileType = .image
            isLoading = false
            return
        }

        let isText = Self.textExtensions.contains(ext) || Self.specialFileNames.contains(fileName)
        let targetURL = fileURL

        // 异步读取文件内容，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async {
            var resultContent: String? = nil
            var resultType: FileContentType = .text
            var resultError: String? = nil

            if isText {
                do {
                    let data = try Data(contentsOf: targetURL)
                    let maxSize = 10 * 1024 * 1024 // 10MB
                    if data.count > maxSize {
                        resultError = "文件过大（\(data.count / 1024 / 1024)MB），超过 10MB 限制"
                    } else if let text = String(data: data, encoding: .utf8) {
                        resultContent = text
                        resultType = .text
                    } else {
                        resultError = "无法解码文件内容（非 UTF-8）"
                    }
                } catch {
                    resultError = "读取文件失败: \(error.localizedDescription)"
                }
            } else {
                // 尝试当文本打开
                do {
                    let data = try Data(contentsOf: targetURL)
                    if data.count < 1024 * 1024, let text = String(data: data, encoding: .utf8) {
                        resultContent = text
                        resultType = .text
                    } else {
                        resultType = .unsupported(ext)
                    }
                } catch {
                    resultType = .unsupported(ext)
                }
            }

            DispatchQueue.main.async {
                // 确保文件 URL 未在读取期间切换
                guard self.fileURL == targetURL else { return }
                if let error = resultError {
                    self.errorMessage = error
                } else if let text = resultContent {
                    self.content = text
                    self.fileType = resultType
                } else {
                    self.fileType = resultType
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Image Preview

struct ImagePreviewView: View {
    let fileURL: URL

    @State private var scale: CGFloat = 1.0
    @State private var imageSize: CGSize = .zero

    private let minScale: CGFloat = 0.1
    private let maxScale: CGFloat = 10.0

    var body: some View {
        GeometryReader { geo in
            if let nsImage = NSImage(contentsOf: fileURL) {
                let fitScale = fitScaleFor(imageSize: NSSize(width: nsImage.size.width, height: nsImage.size.height), containerSize: geo.size)
                let displayWidth = nsImage.size.width * fitScale * scale
                let displayHeight = nsImage.size.height * fitScale * scale

                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: displayWidth, height: displayHeight)
                        .frame(
                            minWidth: max(displayWidth, geo.size.width),
                            minHeight: max(displayHeight, geo.size.height)
                        )
                }
                .onAppear {
                    imageSize = nsImage.size
                    scale = 1.0
                }
                .overlay(alignment: .bottomTrailing) {
                    // 缩放信息和控制
                    HStack(spacing: 8) {
                        Button(action: { zoomOut() }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(scale * fitScale * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 40)

                        Button(action: { zoomIn() }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)

                        Button(action: { scale = 1.0 }) {
                            Text("适应")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)

                        Button(action: { scale = 1.0 / fitScale }) {
                            Text("100%")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                    )
                    .padding(8)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("无法加载图片")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onMagnify { value in
            let newScale = scale * (1 + value)
            scale = min(max(newScale, minScale), maxScale)
        }
    }

    private func fitScaleFor(imageSize: NSSize, containerSize: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1.0 }
        let scaleX = containerSize.width / imageSize.width
        let scaleY = containerSize.height / imageSize.height
        return min(scaleX, scaleY, 1.0) // 不超过原始大小
    }

    private func zoomIn() {
        scale = min(scale * 1.25, maxScale)
    }

    private func zoomOut() {
        scale = max(scale / 1.25, minScale)
    }
}

// MARK: - Magnify Gesture Extension

extension View {
    func onMagnify(perform: @escaping (CGFloat) -> Void) -> some View {
        self.modifier(MagnifyGestureModifier(action: perform))
    }
}

struct MagnifyGestureModifier: ViewModifier {
    let action: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content.gesture(
            MagnifyGesture()
                .onChanged { value in
                    action(value.magnification - 1)
                }
        )
    }
}

// MARK: - Custom Scroll View (syncs text view frame on layout)

class EditorScrollView: NSScrollView {
    private var isSyncing = false

    override func tile() {
        super.tile()
        syncDocumentViewWidth()
    }

    override func layout() {
        super.layout()
        syncDocumentViewWidth()
    }

    func syncDocumentViewWidth() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let textView = documentView as? NSTextView,
              let textContainer = textView.textContainer else { return }
        let w = contentSize.width
        guard w > 1 else { return }

        if abs(textView.frame.size.width - w) > 0.5 {
            textView.frame.size.width = w
        }
        let inset = textView.textContainerInset.width
        let expectedContainerW = max(1, w - 2 * inset)
        if abs(textContainer.containerSize.width - expectedContainerW) > 0.5 {
            textContainer.containerSize = NSSize(width: expectedContainerW, height: CGFloat.greatestFiniteMagnitude)
        }
    }
}

// MARK: - NSTextView Wrapper (with Cmd+S save)

struct FileTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isModified: Bool
    let fileURL: URL

    private var language: String {
        SyntaxHighlighter.languageForExtension(fileURL.pathExtension)
    }

    private var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    func makeNSView(context: Context) -> NSScrollView {
        let theme = isDark ? SyntaxHighlighter.Theme.dark : SyntaxHighlighter.Theme.light

        let gutterWidth: CGFloat = 40
        let initialWidth: CGFloat = 800

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: NSSize(width: initialWidth - 2 * gutterWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 5
        layoutManager.addTextContainer(textContainer)

        let textView = SaveableTextView(
            frame: NSRect(x: 0, y: 0, width: initialWidth, height: 400),
            textContainer: textContainer
        )

        textView.gutterWidth = gutterWidth
        textView.lineNumberColor = theme.comment
        textView.lineNumberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.gutterBackgroundColor = theme.background

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isRichText = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = theme.plain
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.plain
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainerInset = NSSize(width: gutterWidth, height: 8)
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        textView.saveAction = { context.coordinator.saveFile() }

        let scrollView = EditorScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.scrollerStyle = .overlay
        scrollView.backgroundColor = theme.background

        let lang = language
        context.coordinator.language = lang
        context.coordinator.theme = theme
        context.coordinator.scrollView = scrollView
        context.coordinator.needsInitialText = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? SaveableTextView else { return }

        if textView.string != text && !context.coordinator.isEditing {
            let theme = isDark ? SyntaxHighlighter.Theme.dark : SyntaxHighlighter.Theme.light
            let lang = language
            context.coordinator.language = lang
            context.coordinator.theme = theme

            let plainAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: theme.plain
            ]

            context.coordinator.isUpdatingText = true
            textView.undoManager?.disableUndoRegistration()
            textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: plainAttrs))
            textView.undoManager?.enableUndoRegistration()
            context.coordinator.isUpdatingText = false

            textView.updateGutterWidth()

            if let editorSV = nsView as? EditorScrollView {
                editorSV.syncDocumentViewWidth()
            }

            context.coordinator.scheduleHighlight(for: text)

            DispatchQueue.main.async {
                if let editorSV = nsView as? EditorScrollView {
                    editorSV.syncDocumentViewWidth()
                }
            }
        } else if context.coordinator.needsInitialText {
            context.coordinator.needsInitialText = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: FileTextEditor
        var isEditing = false
        var isUpdatingText = false
        var language = "plain"
        var theme = SyntaxHighlighter.Theme.dark
        weak var scrollView: NSScrollView?
        var needsInitialText = false
        private var highlightTimer: Timer?
        private var highlightWorkItem: DispatchWorkItem?

        init(_ parent: FileTextEditor) {
            self.parent = parent
        }

        deinit {
            highlightTimer?.invalidate()
            highlightWorkItem?.cancel()
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingText else { return }
            guard let textView = notification.object as? SaveableTextView else { return }
            isEditing = true
            parent.text = textView.string
            parent.isModified = true
            isEditing = false

            textView.updateGutterWidth()
            scheduleHighlight(for: textView.string)
        }

        func scheduleHighlight(for text: String) {
            highlightTimer?.invalidate()
            highlightWorkItem?.cancel()

            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                let lang = self.language
                let theme = self.theme
                let workItem = DispatchWorkItem { [weak self] in
                    let highlighted = SyntaxHighlighter.highlight(text, language: lang, theme: theme)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self,
                              let sv = self.scrollView,
                              let tv = sv.documentView as? NSTextView else { return }
                        guard tv.string == text else { return }
                        let cursorRange = tv.selectedRange()

                        self.isUpdatingText = true
                        tv.undoManager?.disableUndoRegistration()
                        tv.textStorage?.setAttributedString(highlighted)
                        tv.undoManager?.enableUndoRegistration()
                        self.isUpdatingText = false

                        if cursorRange.location <= tv.string.count {
                            tv.setSelectedRange(cursorRange)
                        }

                        if let editorSV = sv as? EditorScrollView {
                            editorSV.syncDocumentViewWidth()
                        }
                    }
                }
                self.highlightWorkItem = workItem
                DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
            }
        }

        func saveFile() {
            do {
                try parent.text.write(to: parent.fileURL, atomically: true, encoding: .utf8)
                parent.isModified = false
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}

// MARK: - NSTextView with Integrated Line Numbers

class SaveableTextView: NSTextView {
    var saveAction: (() -> Void)?

    var gutterWidth: CGFloat = 40
    var lineNumberColor: NSColor = .secondaryLabelColor
    var lineNumberFont: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    var gutterBackgroundColor: NSColor = .clear

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawGutter(in: rect)
    }

    func updateGutterWidth() {
        let lineCount = max(1, string.components(separatedBy: "\n").count)
        let digits = max(3, String(lineCount).count + 1)
        let attrs: [NSAttributedString.Key: Any] = [.font: lineNumberFont]
        let digitWidth = ("8" as NSString).size(withAttributes: attrs).width
        let newWidth = CGFloat(digits) * digitWidth + 16
        if abs(gutterWidth - newWidth) > 2 {
            gutterWidth = newWidth
            textContainerInset = NSSize(width: gutterWidth, height: textContainerInset.height)
            if let sv = enclosingScrollView as? EditorScrollView {
                sv.syncDocumentViewWidth()
            }
            needsDisplay = true
        }
    }

    private func drawGutter(in rect: NSRect) {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        let origin = textContainerOrigin

        gutterBackgroundColor.setFill()
        NSRect(x: 0, y: rect.origin.y, width: origin.x, height: rect.height).fill()

        NSColor.separatorColor.withAlphaComponent(0.3).setStroke()
        let sep = NSBezierPath()
        sep.move(to: NSPoint(x: origin.x - 0.5, y: rect.origin.y))
        sep.line(to: NSPoint(x: origin.x - 0.5, y: rect.origin.y + rect.height))
        sep.lineWidth = 0.5
        sep.stroke()

        let fullString = self.string as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]

        guard fullString.length > 0 else {
            let s = ("1" as NSString).size(withAttributes: attrs)
            ("1" as NSString).draw(
                at: NSPoint(x: origin.x - s.width - 8, y: origin.y + 2),
                withAttributes: attrs
            )
            return
        }

        let totalGlyphs = layoutManager.numberOfGlyphs
        guard totalGlyphs > 0 else { return }

        let visibleRect = self.visibleRect
        let containerRect = NSRect(
            x: visibleRect.origin.x - origin.x,
            y: visibleRect.origin.y - origin.y,
            width: visibleRect.width,
            height: visibleRect.height
        )

        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: containerRect, in: textContainer)
        guard visibleGlyphs.length > 0 else { return }
        let visibleChars = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)

        var lineNumber = 1
        if visibleChars.location > 0 {
            lineNumber = fullString.substring(to: visibleChars.location)
                .components(separatedBy: "\n").count
        }

        var charIndex = visibleChars.location
        while charIndex < NSMaxRange(visibleChars) {
            let lineRange = fullString.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            guard glyphRange.location < totalGlyphs else { break }

            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            lineRect.origin.y += origin.y

            let numStr = "\(lineNumber)" as NSString
            let size = numStr.size(withAttributes: attrs)
            numStr.draw(
                at: NSPoint(
                    x: origin.x - size.width - 8,
                    y: lineRect.origin.y + (lineRect.height - size.height) / 2
                ),
                withAttributes: attrs
            )

            lineNumber += 1
            let next = NSMaxRange(lineRange)
            if next <= charIndex { break }
            charIndex = next
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "s" {
            saveAction?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
