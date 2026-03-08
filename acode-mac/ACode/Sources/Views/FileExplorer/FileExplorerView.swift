import SwiftUI
import AppKit

/// 左侧文件管理器
struct FileExplorerView: View {
    @EnvironmentObject var appState: AppState
    @Binding var rootURL: URL?
    var onFileSelected: ((URL) -> Void)?
    @State private var rootNode: FileNode?

    var body: some View {
        VStack(spacing: 0) {
            if let root = rootURL {
                // 项目名称头部
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(root.lastPathComponent)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Button(action: { refreshRoot() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("刷新")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // 文件树
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let node = rootNode {
                            FileTreeNodeView(node: node, depth: 0, rootURL: root, onFileSelected: onFileSelected)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onAppear { ensureRootNode(for: root) }
                .onChange(of: rootURL) {
                    if let url = rootURL {
                        ensureRootNode(for: url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .refreshFileTree)) { _ in
                    refreshRoot()
                }

                // 底部路径栏
                Divider()
                HStack(spacing: 4) {
                    Text(root.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(root.path, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("复制路径")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            } else {
                // 未打开项目
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))

                    Button(action: openFolderDialog) {
                        Text("打开文件夹")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    Text("⌘O")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func ensureRootNode(for url: URL) {
        if rootNode == nil || rootNode?.url != url {
            let node = FileNode(url: url)
            node.isExpanded = true
            node.loadChildren()
            rootNode = node
        }
    }

    private func refreshRoot() {
        guard let url = rootURL else { return }
        let node = FileNode(url: url)
        node.isExpanded = true
        node.loadChildren()
        rootNode = node
    }

    private func openFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择要打开的项目文件夹"
        panel.prompt = "打开"
        if panel.runModal() == .OK, let url = panel.url {
            rootURL = url
            UserDefaults.standard.set(url.path, forKey: "lastProjectPath")
        }
    }
}

// MARK: - File Tree Node

struct FileTreeNodeView: View {
    @ObservedObject var node: FileNode
    let depth: Int
    let rootURL: URL
    var onFileSelected: ((URL) -> Void)?

    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 节点行
            HStack(spacing: 4) {
                // 展开箭头（仅文件夹）
                if node.isDirectory {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 14)
                } else {
                    Color.clear.frame(width: 14)
                }

                // 图标
                Image(systemName: node.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                    .frame(width: 20)

                // 文件名（或重命名输入框）
                if isRenaming {
                    TextField("", text: $renameName, onCommit: {
                        performRename()
                    })
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .onExitCommand { isRenaming = false }
                } else {
                    Text(node.name)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 18 + 8)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.5) : Color.clear)
                    .padding(.horizontal, 4)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        node.isExpanded.toggle()
                        if node.isExpanded {
                            node.loadChildren()
                        }
                    }
                } else {
                    onFileSelected?(node.url)
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .contextMenu {
                if !node.isDirectory {
                    Button("在编辑器中打开") {
                        onFileSelected?(node.url)
                    }
                }

                Button("打开方式…") {
                    NSWorkspace.shared.open(node.url)
                }

                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                }

                Divider()

                Button("复制") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([node.url as NSURL])
                    pb.setString(node.url.path, forType: .string)
                }

                Button("复制路径") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(node.url.path, forType: .string)
                }

                Button("复制相对路径") {
                    let relativePath = node.url.path.replacingOccurrences(
                        of: rootURL.path + "/", with: ""
                    )
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(relativePath, forType: .string)
                }

                Divider()

                Button("重命名…") {
                    renameName = node.name
                    isRenaming = true
                }

                Button("删除", role: .destructive) {
                    performDelete()
                }
            }

            // 子节点
            if node.isDirectory && node.isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileTreeNodeView(node: child, depth: depth + 1, rootURL: rootURL, onFileSelected: onFileSelected)
                }
            }
        }
    }

    private var iconColor: Color {
        if node.isDirectory { return Color.secondary }
        if let hex = node.iconColorHex { return Color(hex: hex) }
        return .secondary
    }

    private func performRename() {
        isRenaming = false
        let newName = renameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != node.name else { return }
        let newURL = node.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: node.url, to: newURL)
            // 通知刷新
            NotificationCenter.default.post(name: .refreshFileTree, object: nil)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func performDelete() {
        let alert = NSAlert()
        alert.messageText = "删除「\(node.name)」？"
        alert.informativeText = node.isDirectory ? "文件夹及其内容将被移到废纸篓。" : "文件将被移到废纸篓。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
                NotificationCenter.default.post(name: .refreshFileTree, object: nil)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
