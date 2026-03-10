import SwiftUI

/// MCP 服务器管理设置页
struct MCPSettingsView: View {
    @State private var servers: [MCPServer] = []
    @State private var isLoading = false
    @State private var showAddSheet = false
    @State private var showPresetSheet = false
    @State private var editingServer: MCPServer?
    @State private var errorMessage: String?

    private let service = MCPService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 错误提示
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("关闭") { errorMessage = nil }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.08))
                )
            }

            // 服务器列表
            SettingsSection(title: "已配置 (\(servers.count))") {
                if servers.isEmpty {
                    emptyState
                } else {
                    serverList
                }
            }

            // 操作按钮
            HStack(spacing: 10) {
                Button(action: { showAddSheet = true }) {
                    Label("添加服务器", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button(action: { showPresetSheet = true }) {
                    Label("从预设添加", systemImage: "list.bullet")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button(action: refresh) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { refresh() }
        .sheet(isPresented: $showAddSheet) {
            MCPFormSheet(server: nil) {
                refresh()
            }
        }
        .sheet(item: $editingServer) { server in
            MCPFormSheet(server: server) {
                refresh()
            }
        }
        .sheet(isPresented: $showPresetSheet) {
            MCPPresetSheet {
                refresh()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))

            Text("还没有 MCP 服务器")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("MCP 服务器为 AI 提供额外工具和数据源，如网页抓取、记忆存储等")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Server List

    private var serverList: some View {
        VStack(spacing: 0) {
            ForEach(servers) { server in
                MCPServerCard(
                    server: server,
                    onEdit: { editingServer = server },
                    onDelete: { deleteServer(id: server.id) }
                )

                if server.id != servers.last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Actions

    private func refresh() {
        servers = service.listServers()
    }

    private func deleteServer(id: String) {
        do {
            try service.deleteServer(id: id)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - MCP Server Card

struct MCPServerCard: View {
    let server: MCPServer
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // 信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(server.id)
                        .font(.system(size: 14, weight: .medium))

                    Text(server.transport.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(transportColor.opacity(0.12))
                        )
                        .foregroundColor(transportColor)
                }

                HStack(spacing: 6) {
                    Text(server.summary)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !server.sources.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(server.sources, id: \.self) { source in
                            Text(source)
                                .font(.system(size: 10))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(nsColor: .separatorColor).opacity(0.25))
                                )
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 8) {
                Button("编辑", action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
                .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
                    Button("删除", role: .destructive, action: onDelete)
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("确定要删除 MCP 服务器 \"\(server.id)\" 吗？将从所有配置文件中移除。")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var transportColor: Color {
        switch server.transport {
        case "stdio": return .blue
        case "http": return .green
        case "sse": return .orange
        default: return .gray
        }
    }

    private var transportIcon: String {
        switch server.transport {
        case "stdio": return "terminal"
        case "http": return "network"
        case "sse": return "antenna.radiowaves.left.and.right"
        default: return "server.rack"
        }
    }
}

// MARK: - MCP Add/Edit Form Sheet

struct MCPFormSheet: View {
    @Environment(\.dismiss) var dismiss

    let server: MCPServer?
    let onSave: () -> Void

    @State private var id = ""
    @State private var transport = "stdio"
    @State private var command = ""
    @State private var argsText = ""
    @State private var url = ""
    @State private var errorMessage: String?

    private var isEditing: Bool { server != nil }
    private let service = MCPService.shared

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text(isEditing ? "编辑 MCP 服务器" : "添加 MCP 服务器")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                Section("基本信息") {
                    TextField("服务器 ID *", text: $id, prompt: Text("如：fetch、memory"))
                        .disabled(isEditing)

                    Picker("传输类型", selection: $transport) {
                        Text("stdio").tag("stdio")
                        Text("HTTP").tag("http")
                        Text("SSE").tag("sse")
                    }
                    .pickerStyle(.segmented)
                }

                if transport == "stdio" {
                    Section("stdio 配置") {
                        TextField("命令 *", text: $command, prompt: Text("如：npx、uvx"))
                        TextField("参数（逗号分隔）", text: $argsText, prompt: Text("-y, @modelcontextprotocol/server-time"))
                    }
                } else {
                    Section("\(transport.uppercased()) 配置") {
                        TextField("URL *", text: $url, prompt: Text("https://example.com/mcp"))
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "保存" : "添加") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(id.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 420)
        .onAppear {
            if let s = server {
                id = s.id
                transport = s.transport
                command = s.spec["command"] as? String ?? ""
                if let args = s.spec["args"] as? [String] {
                    argsText = args.joined(separator: ", ")
                }
                url = s.spec["url"] as? String ?? ""
            }
        }
    }

    private func save() {
        errorMessage = nil

        let args = argsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let formData = MCPFormData(
            id: id.trimmingCharacters(in: .whitespaces),
            transport: transport,
            command: command.trimmingCharacters(in: .whitespaces),
            args: args,
            url: url.trimmingCharacters(in: .whitespaces)
        )

        do {
            try service.upsertServer(formData)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - MCP Preset Sheet

struct MCPPresetSheet: View {
    @Environment(\.dismiss) var dismiss

    let onSave: () -> Void

    @State private var errorMessage: String?
    private let service = MCPService.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("从预设添加 MCP 服务器")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            List {
                ForEach(MCPPreset.presets) { preset in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.system(size: 13, weight: .medium))
                            Text(preset.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                ForEach(preset.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.blue.opacity(0.1))
                                        )
                                        .foregroundColor(.blue)
                                }
                            }
                        }

                        Spacer()

                        Button("安装") {
                            installPreset(preset)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)

            if let error = errorMessage {
                HStack {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 500, height: 400)
    }

    private func installPreset(_ preset: MCPPreset) {
        errorMessage = nil
        let formData = MCPFormData(
            id: preset.id,
            transport: preset.transport,
            command: preset.command,
            args: preset.args,
            url: ""
        )
        do {
            try service.upsertServer(formData)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
