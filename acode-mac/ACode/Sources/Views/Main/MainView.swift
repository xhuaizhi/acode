import SwiftUI

// MARK: - Split Node Model（分屏树）

/// 分屏节点：要么是一个终端叶子节点，要么是一个分屏容器
class SplitNode: ObservableObject, Identifiable {
    let id = UUID()

    enum NodeType {
        case terminal(TerminalTab)
        case split(direction: SplitDirection, first: SplitNode, second: SplitNode)
    }

    enum SplitDirection {
        case horizontal  // 左右分屏
        case vertical    // 上下分屏
    }

    @Published var type: NodeType
    @Published var splitRatio: CGFloat = 0.5

    init(tab: TerminalTab) {
        self.type = .terminal(tab)
    }

    init(direction: SplitDirection, first: SplitNode, second: SplitNode) {
        self.type = .split(direction: direction, first: first, second: second)
    }

    /// 构建包含 N 个终端的平衡分屏树（用于恢复上次的终端布局）
    func restoreTerminals(count: Int, direction: SplitDirection = .horizontal) {
        guard count > 1 else { return }
        func buildBalanced(_ n: Int) -> SplitNode {
            if n <= 1 { return SplitNode(tab: TerminalTab()) }
            let half = n / 2
            return SplitNode(direction: direction, first: buildBalanced(half), second: buildBalanced(n - half))
        }
        // 保留当前节点的第一个终端，构建剩余部分
        if case .terminal(let existingTab) = self.type {
            let remaining = buildBalanced(count - 1)
            self.type = .split(direction: direction, first: SplitNode(tab: existingTab), second: remaining)
            self.splitRatio = 1.0 / CGFloat(count)
        }
    }

    /// 获取所有终端标签（叶子节点）
    var allTabs: [TerminalTab] {
        switch type {
        case .terminal(let tab):
            return [tab]
        case .split(_, let first, let second):
            return first.allTabs + second.allTabs
        }
    }

    /// 在指定终端旁边分屏
    func splitTerminal(tabId: UUID, direction: SplitDirection) {
        switch type {
        case .terminal(let tab) where tab.id == tabId:
            let newTab = TerminalTab()
            let firstNode = SplitNode(tab: tab)
            let secondNode = SplitNode(tab: newTab)
            self.type = .split(direction: direction, first: firstNode, second: secondNode)
            self.splitRatio = 0.5

        case .split(_, let first, let second):
            if first.containsTab(tabId: tabId) {
                first.splitTerminal(tabId: tabId, direction: direction)
            } else if second.containsTab(tabId: tabId) {
                second.splitTerminal(tabId: tabId, direction: direction)
            }

        default:
            break
        }
    }

    /// 检查是否包含指定 tabId
    func containsTab(tabId: UUID) -> Bool {
        switch type {
        case .terminal(let tab):
            return tab.id == tabId
        case .split(_, let first, let second):
            return first.containsTab(tabId: tabId) || second.containsTab(tabId: tabId)
        }
    }

    /// 关闭终端面板（就地修改，不替换节点引用，避免 SwiftUI 重建视图树）
    /// 返回 true 表示成功关闭
    @discardableResult
    func closeTerminal(tabId: UUID) -> Bool {
        switch type {
        case .terminal(let tab) where tab.id == tabId:
            // 根节点本身就是要关闭的终端（不应在此处处理，应由父级处理）
            return false

        case .terminal:
            return false // 不匹配

        case .split(_, let first, let second):
            // 检查直接子节点是否是要关闭的终端
            if case .terminal(let tab) = first.type, tab.id == tabId {
                // 左子是目标，提升右子到当前节点
                self.type = second.type
                self.splitRatio = second.splitRatio
                return true
            }
            if case .terminal(let tab) = second.type, tab.id == tabId {
                // 右子是目标，提升左子到当前节点
                self.type = first.type
                self.splitRatio = first.splitRatio
                return true
            }

            // 递归到子树
            if first.closeTerminal(tabId: tabId) {
                return true
            }
            if second.closeTerminal(tabId: tabId) {
                return true
            }
            return false
        }
    }

}

// MARK: - Main View

/// 主窗口视图
struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var rootNode = SplitNode(tab: TerminalTab())
    @State private var focusedTabId: UUID?
    @State private var projectURL: URL?
    @State private var showSidebar: Bool = true
    @State private var showTerminal: Bool = true
    @State private var openedFiles: [URL] = []
    @State private var activeFileIndex: Int? = nil
    @State private var showUpdateToast = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 三栏布局：左文件夹 | 中代码 | 右终端
                HSplitView {
                    // 左侧：文件管理器
                    if showSidebar {
                        VStack(spacing: 0) {
                            FileExplorerView(rootURL: $projectURL) { fileURL in
                                openFile(fileURL)
                            }
                        }
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)
                    }

                    // 中间：代码编辑器（多标签）— 仅在有打开文件时显示
                    if !openedFiles.isEmpty {
                        VStack(spacing: 0) {
                            // 标签栏
                            EditorTabBar(
                                files: $openedFiles,
                                activeIndex: $activeFileIndex,
                                onClose: { idx in closeFile(at: idx) },
                                onCloseAll: closeAllFiles,
                                onSelect: { idx in
                                    activeFileIndex = idx
                                    updateActiveFileInfo()
                                }
                            )

                            // 编辑器内容
                            if let idx = activeFileIndex, idx < openedFiles.count {
                                FileEditorView(fileURL: openedFiles[idx])
                                    .id(openedFiles[idx])
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Color(nsColor: .textBackgroundColor)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(minWidth: 300)
                    }

                    // 右侧：终端（始终保留视图，避免隐藏时销毁终端进程）
                    VStack(spacing: 0) {
                        SplitNodeView(
                            node: rootNode,
                            focusedTabId: $focusedTabId,
                            totalTabCount: rootNode.allTabs.count,
                            onCloseTab: { tabId in closePanel(tabId: tabId) }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(minWidth: showTerminal ? 300 : 0, maxWidth: showTerminal ? .infinity : 0)
                    .opacity(showTerminal ? 1 : 0)
                    .clipped()
                }

                // 底部状态栏（横跨整个窗口）
                StatusBarView()
            }

            // 设置页面覆盖层（内嵌式）
            if appState.showSettings {
                InlineSettingsView(onClose: { appState.showSettings = false })
                    .transition(.opacity)
            }

            // 底部更新 Toast 通知
            if showUpdateToast, let version = appState.updateChecker.latestVersion {
                VStack {
                    Spacer()
                    UpdateToastView(
                        version: version,
                        notes: appState.updateChecker.isDownloading
                            ? "正在下载更新..."
                            : (appState.updateChecker.isDownloaded ? "更新已就绪，点击重启应用" : appState.updateChecker.releaseNotes),
                        isDownloaded: appState.updateChecker.isDownloaded,
                        isDownloading: appState.updateChecker.isDownloading,
                        onUpdate: {
                            if appState.updateChecker.isDownloaded {
                                appState.updateChecker.installAndRestart()
                            }
                        },
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showUpdateToast = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
                    .padding(.horizontal, 20)
                }
                .allowsHitTesting(true)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { withAnimation { showSidebar.toggle() } }) {
                    Image(systemName: "sidebar.left")
                }
                .help("切换侧栏")

                Button(action: { withAnimation { showTerminal.toggle() } }) {
                    Image(systemName: "sidebar.right")
                }
                .help("切换终端")

                Button(action: addNewTab) {
                    Text("新建终端")
                }
                .help("新建终端")
            }
        }
        .onAppear {
            // 检查更新后重启标记
            if let updatedVer = UserDefaults.standard.string(forKey: "lastUpdatedVersion"), !updatedVer.isEmpty {
                UserDefaults.standard.removeObject(forKey: "lastUpdatedVersion")
                if let url = URL(string: "https://acode.anna.tf/versions") {
                    NSWorkspace.shared.open(url)
                }
            }
            // 确保 focusedTabId 先设置（addNewTab 依赖此值）
            if focusedTabId == nil {
                focusedTabId = rootNode.allTabs.first?.id
            }
            // 恢复上次打开的文件夹
            if projectURL == nil, let saved = UserDefaults.standard.string(forKey: "lastProjectPath") {
                let url = URL(fileURLWithPath: saved)
                if FileManager.default.fileExists(atPath: saved) {
                    projectURL = url
                }
            }
            // 自动检查更新 → 下载 → 显示重启按钮
            Task {
                await appState.updateChecker.checkForUpdates()
                if appState.updateChecker.hasUpdate {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showUpdateToast = true
                    }
                    // 后台自动下载
                    await appState.updateChecker.downloadUpdate()
                }
            }
            // 恢复上次的终端数量（构建平衡分屏树）
            let savedCount = UserDefaults.standard.integer(forKey: "lastTerminalCount")
            if savedCount > 1 {
                rootNode.restoreTerminals(count: savedCount)
                appState.terminalCount = rootNode.allTabs.count
                focusedTabId = rootNode.allTabs.first?.id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTerminalTab)) { _ in
            addNewTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .splitHorizontal)) { _ in
            splitHorizontal()
        }
        .onReceive(NotificationCenter.default.publisher(for: .splitVertical)) { _ in
            splitVertical()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { notification in
            if let url = notification.object as? URL {
                switchProject(to: url)
            } else {
                openFolderDialog()
            }
        }
    }

    // MARK: - File Management

    private func openFile(_ url: URL) {
        if let existingIdx = openedFiles.firstIndex(of: url) {
            activeFileIndex = existingIdx
        } else {
            openedFiles.append(url)
            activeFileIndex = openedFiles.count - 1
        }
        updateActiveFileInfo()
    }

    private func closeFile(at index: Int) {
        guard index < openedFiles.count else { return }
        let wasActive = activeFileIndex == index
        openedFiles.remove(at: index)

        if openedFiles.isEmpty {
            activeFileIndex = nil
        } else if wasActive {
            // 关闭的是当前活跃标签：优先选同位置，否则选最后一个
            activeFileIndex = min(index, openedFiles.count - 1)
        } else if let active = activeFileIndex {
            if active > index {
                // 关闭的标签在活跃标签之前，index 前移
                activeFileIndex = active - 1
            }
            // active < index: 不需要调整
        }
        updateActiveFileInfo()
    }

    private func closeAllFiles() {
        openedFiles.removeAll()
        activeFileIndex = nil
        updateActiveFileInfo()
    }

    private func updateActiveFileInfo() {
        guard let idx = activeFileIndex, idx < openedFiles.count else {
            appState.activeFileURL = nil
            appState.activeFileLineCount = nil
            appState.activeFileModDate = nil
            return
        }
        let url = openedFiles[idx]
        appState.activeFileURL = url

        // 异步读取文件信息，避免阻塞主线程
        let state = appState
        DispatchQueue.global(qos: .userInitiated).async {
            var lineCount: Int? = nil
            var modDate: Date? = nil

            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                lineCount = text.components(separatedBy: "\n").count
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let date = attrs[.modificationDate] as? Date {
                modDate = date
            }

            DispatchQueue.main.async {
                // 确保切换期间用户未再次切换标签
                guard state.activeFileURL == url else { return }
                state.activeFileLineCount = lineCount
                state.activeFileModDate = modDate
            }
        }
    }

    /// 切换项目文件夹，清空旧的编辑器状态
    private func switchProject(to url: URL) {
        // 清空旧文件夹的编辑器状态，防止标签/文件引用跨文件夹
        closeAllFiles()
        projectURL = url
        UserDefaults.standard.set(url.path, forKey: "lastProjectPath")
    }

    private func openFolderDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择要打开的项目文件夹"
        panel.prompt = "打开"
        if panel.runModal() == .OK, let url = panel.url {
            switchProject(to: url)
        }
    }

    private func addNewTab() {
        if let tabId = focusedTabId {
            rootNode.splitTerminal(tabId: tabId, direction: .horizontal)
            if let newTab = rootNode.allTabs.last {
                focusedTabId = newTab.id
            }
            appState.terminalCount = rootNode.allTabs.count
            UserDefaults.standard.set(rootNode.allTabs.count, forKey: "lastTerminalCount")
        }
    }

    private func splitHorizontal() {
        if let tabId = focusedTabId {
            rootNode.splitTerminal(tabId: tabId, direction: .horizontal)
            if let newTab = rootNode.allTabs.last {
                focusedTabId = newTab.id
            }
            appState.terminalCount = rootNode.allTabs.count
            UserDefaults.standard.set(rootNode.allTabs.count, forKey: "lastTerminalCount")
        }
    }

    private func splitVertical() {
        if let tabId = focusedTabId {
            rootNode.splitTerminal(tabId: tabId, direction: .vertical)
            if let newTab = rootNode.allTabs.last {
                focusedTabId = newTab.id
            }
            appState.terminalCount = rootNode.allTabs.count
            UserDefaults.standard.set(rootNode.allTabs.count, forKey: "lastTerminalCount")
        }
    }

    private func closeCurrentPanel() {
        guard let tabId = focusedTabId else { return }
        closePanel(tabId: tabId)
    }

    private func closePanel(tabId: UUID) {
        let allTabs = rootNode.allTabs
        guard allTabs.count > 1 else { return }

        let previousFocused = focusedTabId

        rootNode.closeTerminal(tabId: tabId)
        TerminalViewCache.shared.removeView(tabId: tabId)

        let remainingTabs = rootNode.allTabs
        if let prev = previousFocused, prev != tabId, remainingTabs.contains(where: { $0.id == prev }) {
            focusedTabId = prev
        } else {
            focusedTabId = remainingTabs.first?.id
        }
        appState.terminalCount = remainingTabs.count
        UserDefaults.standard.set(remainingTabs.count, forKey: "lastTerminalCount")
    }
}

// MARK: - Split Node View（递归渲染分屏树）

struct SplitNodeView: View {
    @ObservedObject var node: SplitNode
    @Binding var focusedTabId: UUID?
    var totalTabCount: Int = 1
    var onCloseTab: ((UUID) -> Void)? = nil

    var body: some View {
        switch node.type {
        case .terminal(let tab):
            TerminalPanelView(
                tab: tab,
                isFocused: focusedTabId == tab.id,
                canClose: totalTabCount > 1,
                onClose: { onCloseTab?(tab.id) },
                onFocus: { focusedTabId = tab.id }
            )

        case .split(let direction, let first, let second):
            switch direction {
            case .horizontal:
                HSplitPaneView(ratio: $node.splitRatio) {
                    SplitNodeView(node: first, focusedTabId: $focusedTabId, totalTabCount: totalTabCount, onCloseTab: onCloseTab)
                } second: {
                    SplitNodeView(node: second, focusedTabId: $focusedTabId, totalTabCount: totalTabCount, onCloseTab: onCloseTab)
                }
            case .vertical:
                VSplitPaneView(ratio: $node.splitRatio) {
                    SplitNodeView(node: first, focusedTabId: $focusedTabId, totalTabCount: totalTabCount, onCloseTab: onCloseTab)
                } second: {
                    SplitNodeView(node: second, focusedTabId: $focusedTabId, totalTabCount: totalTabCount, onCloseTab: onCloseTab)
                }
            }
        }
    }
}

// MARK: - Terminal Panel (with close button)

struct TerminalPanelView: View {
    let tab: TerminalTab
    let isFocused: Bool
    let canClose: Bool
    let onClose: () -> Void
    let onFocus: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // 分屏时显示标签栏
            if canClose {
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))

                    Text(tab.title)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: onClose) {
                        Text("关闭")
                            .font(.system(size: 10))
                            .foregroundColor(isHovering ? .secondary : .clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(Color(nsColor: .controlBackgroundColor))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isHovering = hovering
                    }
                }
            }

            // 终端视图
            TerminalContainerView(tab: tab, isFocused: isFocused)
                .id(tab.id)
                .contentShape(Rectangle())
                .onTapGesture { onFocus() }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isFocused && canClose ? Color(nsColor: .separatorColor).opacity(0.8) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Horizontal Split Pane（左右分屏，可拖拽）

struct HSplitPaneView<First: View, Second: View>: View {
    @Binding var ratio: CGFloat
    @ViewBuilder let first: First
    @ViewBuilder let second: Second

    @State private var isDragging = false
    @State private var cursorPushed = false

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let dividerWidth: CGFloat = 1
            let firstWidth = max(80, totalWidth * ratio - dividerWidth / 2)
            let secondWidth = max(80, totalWidth * (1 - ratio) - dividerWidth / 2)

            HStack(spacing: 0) {
                first
                    .frame(width: firstWidth)

                // 可拖拽分隔条
                ZStack {
                    Rectangle()
                        .fill(isDragging ? Color.white.opacity(0.4) : Color(nsColor: .separatorColor))
                        .frame(width: 1)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 6)
                        .contentShape(Rectangle())
                }
                .onHover { hovering in
                    if hovering, !cursorPushed {
                        NSCursor.resizeLeftRight.push()
                        cursorPushed = true
                    } else if !hovering, cursorPushed {
                        NSCursor.pop()
                        cursorPushed = false
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            guard totalWidth > 1 else { return }
                            let newRatio = (firstWidth + value.location.x) / totalWidth
                            ratio = min(max(newRatio, 0.15), 0.85)
                        }
                        .onEnded { _ in isDragging = false }
                )

                second
                    .frame(width: secondWidth)
            }
        }
    }
}

// MARK: - Vertical Split Pane（上下分屏，可拖拽）

struct VSplitPaneView<First: View, Second: View>: View {
    @Binding var ratio: CGFloat
    @ViewBuilder let first: First
    @ViewBuilder let second: Second

    @State private var isDragging = false
    @State private var cursorPushed = false

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let dividerHeight: CGFloat = 1
            let firstHeight = max(60, totalHeight * ratio - dividerHeight / 2)
            let secondHeight = max(60, totalHeight * (1 - ratio) - dividerHeight / 2)

            VStack(spacing: 0) {
                first
                    .frame(height: firstHeight)

                // 可拖拽分隔条
                ZStack {
                    Rectangle()
                        .fill(isDragging ? Color.white.opacity(0.4) : Color(nsColor: .separatorColor))
                        .frame(height: 1)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 6)
                        .contentShape(Rectangle())
                }
                .onHover { hovering in
                    if hovering, !cursorPushed {
                        NSCursor.resizeUpDown.push()
                        cursorPushed = true
                    } else if !hovering, cursorPushed {
                        NSCursor.pop()
                        cursorPushed = false
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            guard totalHeight > 1 else { return }
                            let newRatio = (firstHeight + value.location.y) / totalHeight
                            ratio = min(max(newRatio, 0.15), 0.85)
                        }
                        .onEnded { _ in isDragging = false }
                )

                second
                    .frame(height: secondHeight)
            }
        }
    }
}

// MARK: - Terminal Tab Model

struct TerminalTab: Identifiable, Equatable {
    let id = UUID()
    var title: String = "Terminal"
    var workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser

    static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toolbar

struct TerminalToolbar: View {
    let tabs: [TerminalTab]
    let focusedTabId: UUID?
    let onNewTab: () -> Void
    let onSplitH: () -> Void
    let onSplitV: () -> Void
    let onClosePanel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            // 分屏操作按钮
            HStack(spacing: 2) {
                ToolbarButton(icon: "rectangle.split.1x2", tooltip: "垂直分屏", action: onSplitV)
                ToolbarButton(icon: "rectangle.split.2x1", tooltip: "水平分屏", action: onSplitH)

                ToolbarButton(icon: "plus", tooltip: "新建终端", action: onNewTab)

                if tabs.count > 1 {
                    ToolbarButton(icon: "xmark", tooltip: "关闭当前面板", action: onClosePanel)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.5))
                .frame(height: 0.5)
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Empty State

struct EmptyTerminalView: View {
    let onCreateNew: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("没有打开的终端")
                .font(.title3)
                .foregroundColor(.gray)

            Button("新建终端", action: onCreateNew)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Terminal Container

struct TerminalContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fontSize") private var fontSize: Double = 14.0
    let tab: TerminalTab
    var isFocused: Bool = false

    private var terminalBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0))
            : Color(nsColor: .textBackgroundColor)
    }

    var body: some View {
        SwiftTerminalView(
            tabId: tab.id,
            workingDirectory: tab.workingDirectory,
            environment: currentProviderEnv,
            fontSize: CGFloat(fontSize)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(terminalBackground)
    }

    /// 合并所有激活 Provider 的环境变量
    private var currentProviderEnv: [String: String] {
        var env: [String: String] = [:]
        for tool in ["claude_code", "openai", "gemini"] {
            if let providerEnv = try? appState.providerService.getProviderEnv(tool: tool) {
                for (key, value) in providerEnv {
                    env[key] = value
                }
            }
        }
        return env
    }
}
