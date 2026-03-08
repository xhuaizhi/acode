import SwiftUI

/// 底部状态栏
struct StatusBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var visibleMessage: String?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    appState.showSettings.toggle()
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("设置")

            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text("\(appState.terminalCount) 个终端")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // 临时状态消息（如 Provider 切换提示）
            if let msg = visibleMessage {
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            // 当前文件信息（文件名 + 行数 + 修改日期）
            if let fileURL = appState.activeFileURL {
                Text(fileURL.lastPathComponent)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if let lineCount = appState.activeFileLineCount {
                Text("\(lineCount) 行")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if let modDate = appState.activeFileModDate {
                Text(Self.formatDate(modDate))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            ForEach(["claude_code", "openai", "gemini"], id: \.self) { tool in
                if let provider = appState.activeProviders[tool] {
                    ProviderIndicator(provider: provider)
                }
            }

            Spacer()

            TokenUsageIndicator()
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
        .onChange(of: appState.statusMessage) {
            guard !appState.statusMessage.isEmpty else { return }
            withAnimation { visibleMessage = appState.statusMessage }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation { visibleMessage = nil }
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

// MARK: - Token Usage Indicator

struct TokenUsageIndicator: View {
    @EnvironmentObject var appState: AppState
    @State private var showPopover = false
    @State private var isHovering = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            HStack(spacing: 6) {
                Text("输入 \(UsageSummary.formatTokens(appState.sessionUsage.totalInputTokens))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                Text("输出 \(UsageSummary.formatTokens(appState.sessionUsage.totalOutputTokens))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(UsageSummary.formatCost(appState.sessionUsage.totalCost))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering && !showPopover {
                showPopover = true
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            UsagePopoverView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Usage Popover

struct UsagePopoverView: View {
    @EnvironmentObject var appState: AppState

    private var usage: UsageSummary { appState.sessionUsage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本次会话用量")
                .font(.system(size: 13, weight: .semibold))

            VStack(spacing: 6) {
                UsagePopoverRow(label: "输入 Token", value: UsageSummary.formatTokens(usage.totalInputTokens))
                UsagePopoverRow(label: "输出 Token", value: UsageSummary.formatTokens(usage.totalOutputTokens))
                UsagePopoverRow(label: "缓存读取", value: UsageSummary.formatTokens(usage.totalCacheReadTokens))

                Divider()

                UsagePopoverRow(label: "请求次数", value: "\(usage.requestCount)")

                HStack {
                    Text("预估费用")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(UsageSummary.formatCost(usage.totalCost))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}

struct UsagePopoverRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Provider Indicator

struct ProviderIndicator: View {
    let provider: Provider

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(providerColor)
                .frame(width: 6, height: 6)

            Text(provider.name)
                .font(.system(size: 11))
                .foregroundColor(.primary)

            if !provider.model.isEmpty {
                Text("·")
                    .foregroundColor(.secondary)
                Text(provider.model)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        )
    }

    private var providerColor: Color {
        if let hex = provider.iconColor {
            return Color(hex: hex)
        }
        switch provider.tool {
        case "claude_code": return Color(hex: "#D4915D")
        case "openai": return Color(hex: "#00A67E")
        case "gemini": return Color(hex: "#4285F4")
        default: return .gray
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
