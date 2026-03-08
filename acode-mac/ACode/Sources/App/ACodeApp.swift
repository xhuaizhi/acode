import SwiftUI

@main
struct ACodeApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("theme") private var theme = "dark"

    private var colorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }

    init() {
        // app 退出时清理所有终端 shell 进程
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            TerminalViewCache.shared.terminateAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(colorScheme)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建终端") {
                    NotificationCenter.default.post(name: .newTerminalTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("打开文件夹…") {
                    NotificationCenter.default.post(name: .openFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("水平分屏") {
                    NotificationCenter.default.post(name: .splitHorizontal, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("垂直分屏") {
                    NotificationCenter.default.post(name: .splitVertical, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)
            }

        }

        // 设置页面已改为主窗口内嵌（InlineSettingsView）
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newTerminalTab = Notification.Name("newTerminalTab")
    static let splitHorizontal = Notification.Name("splitHorizontal")
    static let splitVertical = Notification.Name("splitVertical")
    static let providerSwitched = Notification.Name("providerSwitched")
    static let openFolder = Notification.Name("openFolder")
    static let refreshFileTree = Notification.Name("refreshFileTree")
}
