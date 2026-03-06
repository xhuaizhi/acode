import Foundation

/// 文件节点模型 — 递归表示文件/文件夹树
class FileNode: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool

    @Published var children: [FileNode]?
    @Published var isExpanded: Bool = false

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue
    }

    /// 加载子节点（懒加载，异步读取目录避免阻塞主线程）
    func loadChildren() {
        guard isDirectory, children == nil else { return }
        let targetURL = url
        DispatchQueue.global(qos: .userInitiated).async {
            var result: [FileNode] = []
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: targetURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                    options: [.skipsHiddenFiles]
                )
                result = contents
                    .sorted { a, b in
                        let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                        let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                        if aIsDir != bIsDir { return aIsDir }
                        return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
                    }
                    .map { FileNode(url: $0) }
            } catch {
                result = []
            }
            DispatchQueue.main.async { [weak self] in
                self?.children = result
            }
        }
    }

    /// 刷新子节点
    func refresh() {
        children = nil
        loadChildren()
    }

    /// 文件扩展名对应的 SF Symbol 图标
    var iconName: String {
        if isDirectory { return "folder.fill" }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json": return "curlybraces"
        case "md", "txt", "readme": return "doc.plaintext"
        case "py": return "doc.text"
        case "html", "css": return "globe"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "sh", "bash", "zsh": return "terminal"
        case "toml", "yaml", "yml": return "gearshape"
        case "rs": return "doc.text"
        case "c", "h", "cpp", "m": return "doc.text"
        default: return "doc"
        }
    }

    /// 文件扩展名对应的图标颜色
    var iconColorHex: String? {
        if isDirectory { return nil }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return "#F05138"
        case "js", "jsx": return "#F7DF1E"
        case "ts", "tsx": return "#3178C6"
        case "json": return "#A0A0A0"
        case "py": return "#3776AB"
        case "rs": return "#DEA584"
        case "html": return "#E34F26"
        case "css": return "#1572B6"
        default: return nil
        }
    }
}
