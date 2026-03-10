import AppKit

/// 简易语法高亮引擎 — 基于正则表达式的关键词着色
class SyntaxHighlighter {

    struct Theme {
        let keyword: NSColor
        let string: NSColor
        let number: NSColor
        let comment: NSColor
        let type: NSColor
        let function: NSColor
        let property: NSColor
        let plain: NSColor
        let background: NSColor

        static var dark: Theme {
            Theme(
                keyword: NSColor(srgbRed: 0.337, green: 0.612, blue: 0.839, alpha: 1),  // #569CD6 钢蓝
                string: NSColor(srgbRed: 0.808, green: 0.569, blue: 0.471, alpha: 1),   // #CE9178 暖棕
                number: NSColor(srgbRed: 0.710, green: 0.808, blue: 0.659, alpha: 1),   // #B5CEA8 浅绿
                comment: NSColor(srgbRed: 0.416, green: 0.600, blue: 0.333, alpha: 1),  // #6A9955 绿色
                type: NSColor(srgbRed: 0.306, green: 0.788, blue: 0.690, alpha: 1),     // #4EC9B0 青绿
                function: NSColor(srgbRed: 0.863, green: 0.863, blue: 0.667, alpha: 1), // #DCDCAA 淡黄
                property: NSColor(srgbRed: 0.612, green: 0.863, blue: 0.996, alpha: 1), // #9CDCFE 浅蓝
                plain: NSColor(srgbRed: 0.831, green: 0.831, blue: 0.831, alpha: 1),    // #D4D4D4 浅灰
                background: NSColor(srgbRed: 0.118, green: 0.118, blue: 0.118, alpha: 1) // #1E1E1E 深色背景
            )
        }

        static var light: Theme {
            Theme(
                keyword: NSColor(srgbRed: 0.0, green: 0.0, blue: 1.0, alpha: 1),        // #0000FF 蓝
                string: NSColor(srgbRed: 0.639, green: 0.082, blue: 0.082, alpha: 1),   // #A31515 暗红
                number: NSColor(srgbRed: 0.035, green: 0.525, blue: 0.345, alpha: 1),   // #098658 暗青
                comment: NSColor(srgbRed: 0.0, green: 0.502, blue: 0.0, alpha: 1),      // #008000 绿
                type: NSColor(srgbRed: 0.149, green: 0.498, blue: 0.600, alpha: 1),     // #267F99 青
                function: NSColor(srgbRed: 0.475, green: 0.369, blue: 0.149, alpha: 1), // #795E26 棕
                property: NSColor(srgbRed: 0.0, green: 0.063, blue: 0.502, alpha: 1),   // #001080 深蓝
                plain: NSColor.textColor,
                background: NSColor.textBackgroundColor
            )
        }
    }

    // MARK: - Language Definitions

    private struct LanguageDef {
        let keywords: Set<String>
        let types: Set<String>
        let singleLineComment: String?
        let multiLineCommentStart: String?
        let multiLineCommentEnd: String?
    }

    private static let swift = LanguageDef(
        keywords: ["import", "func", "var", "let", "class", "struct", "enum", "protocol",
                   "extension", "if", "else", "guard", "switch", "case", "default", "for",
                   "while", "repeat", "return", "break", "continue", "throw", "throws",
                   "try", "catch", "do", "in", "where", "as", "is", "self", "Self",
                   "super", "init", "deinit", "nil", "true", "false", "static", "private",
                   "public", "internal", "fileprivate", "open", "override", "mutating",
                   "weak", "unowned", "lazy", "some", "any", "async", "await", "typealias",
                   "@State", "@Binding", "@Published", "@ObservedObject", "@StateObject",
                   "@EnvironmentObject", "@Environment", "@ViewBuilder", "@MainActor",
                   "@available", "@objc", "@discardableResult"],
        types: ["String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
                "Optional", "URL", "Data", "Date", "UUID", "View", "Color", "Text",
                "Image", "Button", "VStack", "HStack", "ZStack", "List", "NavigationView",
                "NSView", "NSColor", "NSFont", "NSImage", "CGFloat", "CGPoint", "CGSize"],
        singleLineComment: "//",
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/"
    )

    private static let javascript = LanguageDef(
        keywords: ["const", "let", "var", "function", "return", "if", "else", "for",
                   "while", "do", "switch", "case", "default", "break", "continue",
                   "new", "this", "class", "extends", "super", "import", "export",
                   "from", "async", "await", "try", "catch", "throw", "typeof",
                   "instanceof", "in", "of", "true", "false", "null", "undefined",
                   "yield", "delete", "void", "static", "get", "set"],
        types: ["Array", "Object", "String", "Number", "Boolean", "Promise",
                "Map", "Set", "WeakMap", "WeakSet", "Symbol", "Date", "RegExp",
                "Error", "JSON", "Math", "console", "window", "document"],
        singleLineComment: "//",
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/"
    )

    private static let python = LanguageDef(
        keywords: ["def", "class", "if", "elif", "else", "for", "while", "return",
                   "import", "from", "as", "try", "except", "finally", "raise",
                   "with", "yield", "lambda", "pass", "break", "continue", "and",
                   "or", "not", "in", "is", "True", "False", "None", "self",
                   "global", "nonlocal", "assert", "del", "async", "await"],
        types: ["int", "float", "str", "bool", "list", "dict", "tuple", "set",
                "type", "object", "Exception", "print", "len", "range", "enumerate",
                "zip", "map", "filter", "sorted", "super", "property", "staticmethod",
                "classmethod"],
        singleLineComment: "#",
        multiLineCommentStart: nil,
        multiLineCommentEnd: nil
    )

    private static let rust = LanguageDef(
        keywords: ["fn", "let", "mut", "const", "if", "else", "match", "for", "while",
                   "loop", "return", "break", "continue", "struct", "enum", "impl",
                   "trait", "type", "use", "mod", "pub", "crate", "self", "super",
                   "where", "as", "in", "ref", "move", "async", "await", "unsafe",
                   "extern", "dyn", "true", "false"],
        types: ["String", "Vec", "Option", "Result", "Box", "Rc", "Arc", "HashMap",
                "HashSet", "i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32",
                "u64", "u128", "f32", "f64", "bool", "char", "usize", "isize", "Self"],
        singleLineComment: "//",
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/"
    )

    private static let html = LanguageDef(
        keywords: ["html", "head", "body", "div", "span", "a", "p", "h1", "h2", "h3",
                   "h4", "h5", "h6", "img", "ul", "ol", "li", "table", "tr", "td", "th",
                   "form", "input", "button", "select", "option", "textarea", "label",
                   "script", "style", "link", "meta", "title", "section", "article",
                   "nav", "header", "footer", "main", "aside"],
        types: ["class", "id", "href", "src", "alt", "type", "name", "value",
                "placeholder", "action", "method", "target", "rel", "content"],
        singleLineComment: nil,
        multiLineCommentStart: "<!--",
        multiLineCommentEnd: "-->"
    )

    private static let css = LanguageDef(
        keywords: ["@import", "@media", "@keyframes", "@font-face", "@supports",
                   "!important", "inherit", "initial", "unset", "none", "auto",
                   "block", "inline", "flex", "grid", "absolute", "relative", "fixed",
                   "sticky", "hidden", "visible", "solid", "dashed", "dotted"],
        types: ["color", "background", "margin", "padding", "border", "font-size",
                "font-weight", "display", "position", "width", "height", "top", "left",
                "right", "bottom", "z-index", "overflow", "opacity", "transform",
                "transition", "animation", "box-shadow", "text-align", "line-height"],
        singleLineComment: "//",
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/"
    )

    private static let go = LanguageDef(
        keywords: ["package", "import", "func", "var", "const", "type", "struct",
                   "interface", "map", "chan", "if", "else", "for", "range", "switch",
                   "case", "default", "break", "continue", "return", "go", "defer",
                   "select", "fallthrough", "goto", "nil", "true", "false",
                   "make", "new", "append", "len", "cap", "copy", "delete", "close"],
        types: ["string", "int", "int8", "int16", "int32", "int64",
                "uint", "uint8", "uint16", "uint32", "uint64",
                "float32", "float64", "bool", "byte", "rune", "error",
                "any", "comparable"],
        singleLineComment: "//",
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/"
    )

    private static let generic = LanguageDef(
        keywords: ["if", "else", "for", "while", "return", "function", "class",
                   "import", "export", "true", "false", "null", "nil", "void",
                   "var", "let", "const", "new", "this", "self"],
        types: ["String", "Int", "Bool", "Array", "Object", "Error"],
        singleLineComment: "//",
        multiLineCommentStart: "/*",
        multiLineCommentEnd: "*/"
    )

    // MARK: - Public API

    static func languageForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "swift": return "swift"
        case "js", "jsx", "mjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "rs": return "rust"
        case "html", "htm": return "html"
        case "css", "scss", "less": return "css"
        case "json": return "json"
        case "go": return "go"
        case "c", "h", "cpp", "hpp", "m", "mm": return "c"
        case "java", "kt": return "java"
        case "rb": return "ruby"
        case "sh", "bash", "zsh": return "shell"
        case "sql": return "sql"
        case "xml", "plist", "svg": return "xml"
        case "yaml", "yml": return "yaml"
        case "toml": return "toml"
        case "md": return "markdown"
        default: return "plain"
        }
    }

    static func highlight(_ text: String, language: String, theme: Theme, fontSize: CGFloat = 13) -> NSAttributedString {
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: theme.plain
        ]

        // 纯文本 / Markdown 不做语法高亮
        if language == "plain" || language == "markdown" {
            return NSAttributedString(string: text, attributes: baseAttrs)
        }

        let langDef = languageDefinition(for: language)
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttrs)

        let fullRange = NSRange(location: 0, length: attributed.length)

        // 收集"保护区域"（注释+字符串+数字），后续关键词/类型/函数不会覆盖
        var protectedRanges: [NSRange] = []

        // 1. 多行注释
        if let start = langDef.multiLineCommentStart, let end = langDef.multiLineCommentEnd {
            protectedRanges += highlightAndCollect(in: attributed, pattern: escapeRegex(start) + "[\\s\\S]*?" + escapeRegex(end), color: theme.comment, range: fullRange)
        }

        // 2. 单行注释
        if let commentPrefix = langDef.singleLineComment {
            protectedRanges += highlightAndCollect(in: attributed, pattern: escapeRegex(commentPrefix) + ".*$", color: theme.comment, range: fullRange, options: .anchorsMatchLines)
        }

        // 3. 字符串（双引号、单引号、反引号）
        protectedRanges += highlightAndCollect(in: attributed, pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", color: theme.string, range: fullRange)
        protectedRanges += highlightAndCollect(in: attributed, pattern: "'(?:[^'\\\\]|\\\\.)*'", color: theme.string, range: fullRange)
        protectedRanges += highlightAndCollect(in: attributed, pattern: "`(?:[^`\\\\]|\\\\.)*`", color: theme.string, range: fullRange)

        // 4. 数字
        protectedRanges += highlightAndCollect(in: attributed, pattern: "\\b\\d+\\.?\\d*\\b", color: theme.number, range: fullRange)

        // 5. 类型（跳过保护区域）
        for type in langDef.types {
            highlightWordProtected(in: attributed, word: type, color: theme.type, range: fullRange, protected: protectedRanges)
        }

        // 6. 关键词（跳过保护区域）
        for keyword in langDef.keywords {
            if keyword.hasPrefix("@") {
                highlightPatternProtected(in: attributed, pattern: escapeRegex(keyword) + "\\b", color: theme.keyword, range: fullRange, protected: protectedRanges)
            } else {
                highlightWordProtected(in: attributed, word: keyword, color: theme.keyword, range: fullRange, protected: protectedRanges)
            }
        }

        // 7. 函数调用（跳过保护区域）
        highlightPatternProtected(in: attributed, pattern: "\\b([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(", color: theme.function, range: fullRange, protected: protectedRanges, captureGroup: 1)

        return attributed
    }

    // MARK: - Private Helpers

    private static func languageDefinition(for language: String) -> LanguageDef {
        switch language {
        case "swift": return swift
        case "javascript", "typescript", "json": return javascript
        case "python": return python
        case "rust": return rust
        case "go": return go
        case "html", "xml": return html
        case "css": return css
        case "c", "java": return javascript
        default: return generic
        }
    }

    private static func escapeRegex(_ string: String) -> String {
        NSRegularExpression.escapedPattern(for: string)
    }

    /// 高亮并返回匹配到的范围列表（用于构建保护区域）
    private static func highlightAndCollect(in attributed: NSMutableAttributedString, pattern: String, color: NSColor, range: NSRange, options: NSRegularExpression.Options = []) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let matches = regex.matches(in: attributed.string, range: range)
        var collected: [NSRange] = []
        for match in matches {
            let r = match.range
            if r.location != NSNotFound {
                attributed.addAttribute(.foregroundColor, value: color, range: r)
                collected.append(r)
            }
        }
        return collected
    }

    /// 检查 range 是否与任何保护区域重叠
    private static func isProtected(_ range: NSRange, by protected: [NSRange]) -> Bool {
        let start = range.location
        let end = start + range.length
        for p in protected {
            let pStart = p.location
            let pEnd = pStart + p.length
            if start < pEnd && end > pStart { return true }
        }
        return false
    }

    /// 高亮正则匹配，跳过保护区域
    private static func highlightPatternProtected(in attributed: NSMutableAttributedString, pattern: String, color: NSColor, range: NSRange, protected: [NSRange], options: NSRegularExpression.Options = [], captureGroup: Int = 0) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: attributed.string, range: range)
        for match in matches {
            let matchRange = captureGroup < match.numberOfRanges ? match.range(at: captureGroup) : match.range
            if matchRange.location != NSNotFound && !isProtected(matchRange, by: protected) {
                attributed.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
        }
    }

    /// 高亮单词，跳过保护区域
    private static func highlightWordProtected(in attributed: NSMutableAttributedString, word: String, color: NSColor, range: NSRange, protected: [NSRange]) {
        highlightPatternProtected(in: attributed, pattern: "\\b" + escapeRegex(word) + "\\b", color: color, range: range, protected: protected)
    }
}
