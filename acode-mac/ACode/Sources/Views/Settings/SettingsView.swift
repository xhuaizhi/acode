import SwiftUI
import AppKit

/// 设置页面 — 左侧菜单 + 右侧内容
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            // 左侧菜单
            SettingsSidebar(selectedTab: $selectedTab)
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            // 右侧内容
            settingsContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("设置")
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView()
        case .claude:
            ProviderSettingsView(tool: "claude_code", toolName: "Claude Code")
        case .openai:
            ProviderSettingsView(tool: "openai", toolName: "OpenAI Codex")
        case .gemini:
            ProviderSettingsView(tool: "gemini", toolName: "Gemini CLI")
        case .mcp:
            MCPSettingsView()
        case .skills:
            SkillsSettingsView()
        case .usage:
            UsageSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

// MARK: - Sidebar

struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab

    private var groupedTabs: [(String, [SettingsTab])] {
        let groups = Dictionary(grouping: SettingsTab.allCases, by: { $0.group })
        let order = ["基础", "服务商", "工具", "高级", "其他"]
        return order.compactMap { group in
            if let tabs = groups[group] {
                return (group, tabs)
            }
            return nil
        }
    }

    var body: some View {
        List(selection: $selectedTab) {
            ForEach(groupedTabs, id: \.0) { group, tabs in
                Section(group) {
                    ForEach(tabs) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("theme") private var theme = "dark"
    @AppStorage("defaultShell") private var defaultShell = "/bin/zsh"
    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("editorFontSize") private var editorFontSize = 13.0

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: $theme) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }

                HStack {
                    Text("终端字体大小")
                    Slider(value: $fontSize, in: 10...24, step: 1)
                    Text("\(Int(fontSize))pt")
                        .monospacedDigit()
                        .frame(width: 36)
                }

                HStack {
                    Text("编辑器字体大小")
                    Slider(value: $editorFontSize, in: 10...28, step: 1)
                    Text("\(Int(editorFontSize))pt")
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }

            Section("终端") {
                TextField("默认 Shell", text: $defaultShell)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("常规")
    }
}

// MARK: - Usage Settings

struct UsageSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("本次会话") {
                UsageRow(label: "输入 Tokens", value: UsageSummary.formatTokens(appState.sessionUsage.totalInputTokens))
                UsageRow(label: "输出 Tokens", value: UsageSummary.formatTokens(appState.sessionUsage.totalOutputTokens))
                UsageRow(label: "缓存读取", value: UsageSummary.formatTokens(appState.sessionUsage.totalCacheReadTokens))
                UsageRow(label: "请求次数", value: "\(appState.sessionUsage.requestCount)")

                Divider()

                UsageRow(label: "预估费用", value: UsageSummary.formatCost(appState.sessionUsage.totalCost), isHighlighted: true)
            }

            Section("说明") {
                Text("用量数据基于终端内 AI CLI 工具的使用自动统计。费用根据模型定价页面中配置的单价预估计算。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("用量")
    }
}

struct UsageRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isHighlighted ? .green : .primary)
                .fontWeight(isHighlighted ? .semibold : .regular)
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    @EnvironmentObject var appState: AppState

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // App 图标（使用应用图标）
            AppIconView(size: 96)

            Text("ACode")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("版本 \(appVersion) (\(buildNumber))")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Text("一站式 AI 编程终端，集成多家大模型，让你在一个窗口内完成代码编写、调试与部署")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                .frame(width: 200, height: 0.5)
                .padding(.vertical, 4)

            // 社区信息
            VStack(spacing: 6) {
                Text("官方 QQ 群")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("1076321843", forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Text("1076321843")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.primary)
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("点击复制群号")
            }
            .padding(.bottom, 4)

            // 版本更新
            VStack(spacing: 8) {
                if appState.updateChecker.isChecking {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在检查更新...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if appState.updateChecker.hasUpdate, let latest = appState.updateChecker.latestVersion {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text("新版本 v\(latest) 可用")
                            .font(.callout.weight(.medium))
                    }

                    if let url = appState.updateChecker.downloadUrl, let downloadUrl = URL(string: url) {
                        Link("前往下载", destination: downloadUrl)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已是最新版本")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }

                Button("检查更新") {
                    Task { await appState.updateChecker.checkForUpdates() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            // 版权信息
            Text("Copyright \u{00A9} 2025 ACode. All rights reserved.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("关于")
        .onAppear {
            Task { await appState.updateChecker.checkForUpdates() }
        }
    }
}

// MARK: - App Icon View

struct AppIconView: NSViewRepresentable {
    let size: CGFloat

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            imageView.image = appIcon
        }
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {}
}
