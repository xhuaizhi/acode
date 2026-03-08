import SwiftUI
import SwiftTerm
import AppKit

// MARK: - ANSI Color Palette

private func c8(_ r: UInt16, _ g: UInt16, _ b: UInt16) -> SwiftTerm.Color {
    SwiftTerm.Color(red: r * 257, green: g * 257, blue: b * 257)
}

private func makeAnsiPalette(isDark: Bool) -> [SwiftTerm.Color] {
    if isDark {
        return [
            c8(0x1d, 0x1f, 0x21),  c8(0xcc, 0x66, 0x66),
            c8(0xb5, 0xbd, 0x68),  c8(0xf0, 0xc6, 0x74),
            c8(0x81, 0xa2, 0xbe),  c8(0xb2, 0x94, 0xbb),
            c8(0x8a, 0xbe, 0xb7),  c8(0xc5, 0xc8, 0xc6),
            c8(0x96, 0x98, 0x96),  c8(0xff, 0x33, 0x34),
            c8(0x9e, 0xc4, 0x00),  c8(0xe7, 0xc5, 0x47),
            c8(0x7a, 0xa6, 0xda),  c8(0xb7, 0x7e, 0xe0),
            c8(0x54, 0xce, 0xd6),  c8(0xff, 0xff, 0xff),
        ]
    } else {
        return [
            c8(0x00, 0x00, 0x00),  c8(0xc9, 0x1b, 0x00),
            c8(0x00, 0xc2, 0x00),  c8(0xc7, 0xc4, 0x00),
            c8(0x00, 0x25, 0xc7),  c8(0xc9, 0x30, 0xc7),
            c8(0x00, 0xc5, 0xc7),  c8(0xc7, 0xc7, 0xc7),
            c8(0x68, 0x68, 0x68),  c8(0xff, 0x6e, 0x67),
            c8(0x5f, 0xf9, 0x67),  c8(0xfe, 0xfb, 0x67),
            c8(0x68, 0x71, 0xff),  c8(0xff, 0x76, 0xff),
            c8(0x5f, 0xfd, 0xff),  c8(0xff, 0xff, 0xff),
        ]
    }
}

// MARK: - Terminal View Cache（全局缓存，避免视图重建时重启 shell 进程）

final class TerminalViewCache {
    static let shared = TerminalViewCache()
    private var cache: [UUID: LocalProcessTerminalView] = [:]

    func getOrCreate(
        tabId: UUID,
        workingDirectory: URL,
        environment: [String: String],
        fontSize: CGFloat,
        delegate: LocalProcessTerminalViewDelegate
    ) -> LocalProcessTerminalView {
        if let existing = cache[tabId] {
            existing.processDelegate = delegate
            return existing
        }

        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.focusRingType = .none

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = font

        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            terminalView.nativeBackgroundColor = NSColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0)
            terminalView.nativeForegroundColor = NSColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1.0)
        } else {
            terminalView.nativeBackgroundColor = .textBackgroundColor
            terminalView.nativeForegroundColor = .textColor
        }

        terminalView.installColors(makeAnsiPalette(isDark: isDark))

        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"

        let shell = env["SHELL"] ?? "/bin/zsh"
        let envArray = env.map { "\($0.key)=\($0.value)" }

        terminalView.processDelegate = delegate
        terminalView.startProcess(
            executable: shell,
            args: ["--login"],
            environment: envArray,
            execName: nil,
            currentDirectory: workingDirectory.path
        )

        cache[tabId] = terminalView
        return terminalView
    }

    func removeView(tabId: UUID) {
        if let view = cache.removeValue(forKey: tabId) {
            view.terminate()
        }
    }

    /// 终止所有缓存的终端进程（app 退出时调用）
    func terminateAll() {
        for (_, view) in cache {
            view.terminate()
        }
        cache.removeAll()
    }
}

/// SwiftTerm 终端视图封装
/// 使用容器 NSView 包装 LocalProcessTerminalView，避免 SwiftUI 视图树重建时销毁终端进程
struct SwiftTerminalView: NSViewRepresentable {
    let tabId: UUID
    let workingDirectory: URL
    let environment: [String: String]
    let fontSize: CGFloat

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        // 设置容器背景色与终端一致，用于填充 padding 区域
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        container.layer?.backgroundColor = isDark
            ? NSColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0).cgColor
            : NSColor.textBackgroundColor.cgColor

        let terminalView = TerminalViewCache.shared.getOrCreate(
            tabId: tabId,
            workingDirectory: workingDirectory,
            environment: environment,
            fontSize: fontSize,
            delegate: context.coordinator
        )

        // 从旧父视图移除（如果有），重新挂载到新容器
        terminalView.removeFromSuperview()
        container.addSubview(terminalView)
        terminalView.translatesAutoresizingMaskIntoConstraints = false

        // 添加内边距，避免终端内容紧贴容器边缘
        let hPadding: CGFloat = 12
        let vPadding: CGFloat = 6
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: container.topAnchor, constant: vPadding),
            terminalView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPadding),
            terminalView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPadding),
            terminalView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -hPadding),
        ])

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 找到容器内的终端视图
        guard let terminalView = nsView.subviews.first as? LocalProcessTerminalView else { return }

        // 仅在字体大小变化时更新，避免触发 resetFont -> resize -> softReset -> showCursor 链
        // softReset 会强制 cursorHidden=false 并调用 showCursor，覆盖 TUI 应用的 DECTCEM 光标隐藏
        if terminalView.font.pointSize != fontSize {
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            terminalView.font = font
        }

        // 同步容器背景色（响应深色/浅色模式切换）
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        nsView.layer?.backgroundColor = isDark
            ? NSColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0).cgColor
            : NSColor.textBackgroundColor.cgColor

        // 隐藏 SwiftTerm 内部的 NSScroller
        for subview in terminalView.subviews {
            if let scroller = subview as? NSScroller {
                scroller.isHidden = true
            }
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        // 从容器中移除终端视图（但不销毁，缓存仍持有引用）
        for subview in nsView.subviews {
            if subview is LocalProcessTerminalView {
                subview.removeFromSuperview()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // 终端大小变化时自动处理
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            NotificationCenter.default.post(
                name: .terminalTitleChanged,
                object: nil,
                userInfo: ["title": title]
            )
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // 当前目录变化
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            NotificationCenter.default.post(
                name: .terminalProcessExited,
                object: nil,
                userInfo: ["exitCode": exitCode ?? -1]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let terminalTitleChanged = Notification.Name("terminalTitleChanged")
    static let terminalProcessExited = Notification.Name("terminalProcessExited")
}
