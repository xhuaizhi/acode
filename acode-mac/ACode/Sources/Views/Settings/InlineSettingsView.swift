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
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.top, group == groupedTabs.first?.0 ? 12 : 20)
                                .padding(.bottom, 6)

                            ForEach(tabs) { tab in
                                SettingsSidebarItem(
                                    tab: tab,
                                    isSelected: selectedTab == tab,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTab = tab
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }

                Divider()

                // 底部返回按钮
                SettingsBackButton(action: onClose)
            }
            .frame(width: 200)
            .background(Color(nsColor: .windowBackgroundColor))

            // 分隔线
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)

            // 右侧内容
            VStack(spacing: 0) {
                // 标题栏
                HStack(alignment: .center) {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider()

                // 内容区
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        settingsContent
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                }
                .id(selectedTab)
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - 侧栏菜单项（带 Hover 效果）

private struct SettingsSidebarItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        } else if isHovering {
            return Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.5)
        }
        return .clear
    }
}

// MARK: - 返回按钮（带 Hover 效果）

private struct SettingsBackButton: View {
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                Text("返回应用程序")
                    .font(.system(size: 14))
                Spacer()
            }
            .foregroundColor(isHovering ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
