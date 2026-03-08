import SwiftUI

/// 内嵌式设置页面 — 覆盖在主窗口内，类似 Cursor IDE 风格
struct InlineSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .general
    let onClose: () -> Void

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
        HStack(spacing: 0) {
            // 左侧菜单
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(groupedTabs, id: \.0) { group, tabs in
                            Text(group.uppercased())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.top, group == groupedTabs.first?.0 ? 12 : 20)
                                .padding(.bottom, 4)

                            ForEach(tabs) { tab in
                                Button(action: { selectedTab = tab }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 12))
                                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                                            .frame(width: 18)
                                        Text(tab.rawValue)
                                            .font(.system(size: 13))
                                            .foregroundColor(selectedTab == tab ? .primary : .primary.opacity(0.7))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(selectedTab == tab ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                            }
                        }
                    }
                }

                Divider()

                // 底部返回按钮
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                        Text("返回应用程序")
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .frame(width: 190)
            .background(Color(nsColor: .windowBackgroundColor))

            // 分隔线
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)

            // 右侧内容
            VStack(spacing: 0) {
                // 标题
                HStack {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        settingsContent
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
