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
        VStack(alignment: .leading, spacing: 24) {
            // 外观
            SettingsSection(title: "外观") {
                SettingsRow(label: "主题") {
                    Picker("", selection: $theme) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                SettingsRow(label: "终端字体大小") {
                    HStack(spacing: 10) {
                        Slider(value: $fontSize, in: 10...24, step: 1)
                            .frame(maxWidth: 200)
                        Text("\(Int(fontSize))pt")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                SettingsRow(label: "编辑器字体大小") {
                    HStack(spacing: 10) {
                        Slider(value: $editorFontSize, in: 10...28, step: 1)
                            .frame(maxWidth: 200)
                        Text("\(Int(editorFontSize))pt")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            // 终端
            SettingsSection(title: "终端") {
                SettingsRow(label: "默认 Shell") {
                    TextField("", text: $defaultShell)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 通用设置区块

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - 通用设置行

struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
            Spacer()
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Usage Settings

struct UsageSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SettingsSection(title: "本次会话") {
                SettingsRow(label: "输入 Tokens") {
                    Text(UsageSummary.formatTokens(appState.sessionUsage.totalInputTokens))
                        .font(.system(size: 14, design: .monospaced))
                }
                SettingsRow(label: "输出 Tokens") {
                    Text(UsageSummary.formatTokens(appState.sessionUsage.totalOutputTokens))
                        .font(.system(size: 14, design: .monospaced))
                }
                SettingsRow(label: "缓存读取") {
                    Text(UsageSummary.formatTokens(appState.sessionUsage.totalCacheReadTokens))
                        .font(.system(size: 14, design: .monospaced))
                }
                SettingsRow(label: "请求次数") {
                    Text("\(appState.sessionUsage.requestCount)")
                        .font(.system(size: 14, design: .monospaced))
                }

                Divider()
                    .padding(.horizontal, 16)

                SettingsRow(label: "预估费用") {
                    Text(UsageSummary.formatCost(appState.sessionUsage.totalCost))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.6))
                Text("用量数据基于终端内 AI CLI 工具的使用自动统计。费用根据模型定价页面中配置的单价预估计算。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
