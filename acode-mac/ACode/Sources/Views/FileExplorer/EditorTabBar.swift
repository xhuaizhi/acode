import SwiftUI

/// 编辑器标签栏 — 支持多文件标签、关闭、全部关闭
struct EditorTabBar: View {
    @Binding var files: [URL]
    @Binding var activeIndex: Int?
    var onClose: (Int) -> Void
    var onCloseAll: () -> Void
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(files.enumerated()), id: \.element) { index, file in
                        EditorTab(
                            fileName: file.lastPathComponent,
                            isActive: activeIndex == index,
                            onSelect: { onSelect(index) },
                            onClose: { onClose(index) }
                        )
                    }
                }
            }

            Spacer(minLength: 0)

            // 竖三点菜单
            if !files.isEmpty {
                Menu {
                    Button("关闭所有文件", action: onCloseAll)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(90))
                        .frame(width: 20, height: 20)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20)
                .padding(.trailing, 6)
            }
        }
        .frame(height: 26)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }
}

/// 单个编辑器标签
struct EditorTab: View {
    let fileName: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @State private var isCloseHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // 标签主体
            Button(action: onSelect) {
                HStack(spacing: 4) {
                    Image(systemName: iconForFile(fileName))
                        .font(.system(size: 10))
                        .foregroundColor(iconColorForFile(fileName))

                    Text(fileName)
                        .font(.system(size: 11))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            // 关闭按钮（始终占位，hover/active 时显示图标）
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor((isHovering || isActive) ? .secondary : .clear)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isCloseHovering = hovering }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isActive
                ? Color(nsColor: .textBackgroundColor)
                : (isHovering ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.3) : Color.clear)
        )
        .onHover { hovering in isHovering = hovering }

        // 右侧分隔线
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.2))
            .frame(width: 0.5)
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json": return "curlybraces"
        case "md", "txt": return "doc.plaintext"
        case "py": return "doc.text"
        case "html", "css": return "globe"
        case "sh", "bash", "zsh": return "terminal"
        case "rs": return "doc.text"
        default: return "doc"
        }
    }

    private func iconColorForFile(_ name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return Color(hex: "#F05138")
        case "js", "jsx": return Color(hex: "#F7DF1E")
        case "ts", "tsx": return Color(hex: "#3178C6")
        case "py": return Color(hex: "#3776AB")
        case "rs": return Color(hex: "#DEA584")
        case "html": return Color(hex: "#E34F26")
        case "css": return Color(hex: "#1572B6")
        case "json": return .secondary
        default: return .secondary
        }
    }
}
