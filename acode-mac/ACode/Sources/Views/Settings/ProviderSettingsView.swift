import SwiftUI

/// Provider 管理设置页 — 显示指定工具类型的所有供应商，支持添加/编辑/删除/切换
struct ProviderSettingsView: View {
    @EnvironmentObject var appState: AppState
    let tool: String
    let toolName: String

    @State private var showAddSheet = false
    @State private var showPresetSheet = false
    @State private var editingProvider: Provider?

    private var toolProviders: [Provider] {
        appState.providers.filter { $0.tool == tool }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                HStack {
                    Text("\(toolName) 供应商管理")
                        .font(.title2.bold())
                    Spacer()
                }
                .padding(.horizontal)

                // Provider 列表
                if toolProviders.isEmpty {
                    emptyState
                } else {
                    providerList
                }

                // 操作按钮
                HStack(spacing: 12) {
                    Button(action: { showAddSheet = true }) {
                        Label("添加供应商", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { showPresetSheet = true }) {
                        Label("从预设添加", systemImage: "list.bullet")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(toolName)
        .sheet(isPresented: $showAddSheet) {
            ProviderFormSheet(tool: tool, toolName: toolName, provider: nil) {
                appState.loadProviders()
            }
            .environmentObject(appState)
        }
        .sheet(item: $editingProvider) { provider in
            ProviderFormSheet(tool: tool, toolName: toolName, provider: provider) {
                appState.loadProviders()
            }
            .environmentObject(appState)
        }
        .sheet(isPresented: $showPresetSheet) {
            PresetPickerSheet(tool: tool) {
                appState.loadProviders()
            }
            .environmentObject(appState)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))

            Text("还没有 \(toolName) 供应商")
                .foregroundColor(.secondary)

            Text("添加一个供应商以开始使用")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Provider List

    private var providerList: some View {
        VStack(spacing: 8) {
            ForEach(toolProviders) { provider in
                ProviderCard(
                    provider: provider,
                    onEdit: { editingProvider = provider },
                    onDelete: { appState.deleteProvider(id: provider.id) },
                    onSwitch: { appState.switchProvider(id: provider.id) }
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Provider Card

struct ProviderCard: View {
    let provider: Provider
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSwitch: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Circle()
                .fill(iconColor)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if provider.isActive {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    Text(provider.name)
                        .font(.system(size: 13, weight: provider.isActive ? .semibold : .regular))
                }

                HStack(spacing: 8) {
                    if !provider.model.isEmpty {
                        Text(provider.model)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Text(provider.maskedApiKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                if !provider.apiBase.isEmpty {
                    Text(provider.apiBase)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 8) {
                Button("编辑", action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                if !provider.isActive {
                    Button("切换到此", action: onSwitch)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }

                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
                    Button("删除", role: .destructive, action: onDelete)
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("确定要删除供应商 \"\(provider.name)\" 吗？此操作不可撤销。")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(provider.isActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }

    private var iconColor: Color {
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

    private var iconSystemName: String {
        switch provider.tool {
        case "claude_code": return "bubble.left.fill"
        case "openai": return "hexagon"
        case "gemini": return "sparkle"
        default: return "server.rack"
        }
    }
}

// MARK: - Provider Add/Edit Form Sheet

struct ProviderFormSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let tool: String
    let toolName: String
    let provider: Provider? // nil = 新建模式
    let onSave: () -> Void

    @State private var name = ""
    @State private var apiKey = ""
    @State private var apiBase = ""
    @State private var model = ""
    @State private var extraEnv = "{}"
    @State private var notes = ""

    // Claude 专用
    @State private var haikuModel = ""
    @State private var sonnetModel = ""
    @State private var opusModel = ""

    @State private var errorMessage: String?

    private var isEditing: Bool { provider != nil }

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text(isEditing ? "编辑 \(toolName) 供应商" : "添加 \(toolName) 供应商")
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

            // 表单
            Form {
                Section("基本信息") {
                    TextField("名称 *", text: $name, prompt: Text("如：官方 Claude"))
                    SecureField("API Key *", text: $apiKey, prompt: Text("sk-xxx"))
                    TextField("API 端点", text: $apiBase, prompt: Text("空=使用官方默认端点"))
                }

                Section("模型设置") {
                    TextField("主模型", text: $model, prompt: Text("空=使用默认模型"))

                    // Claude 专用多模型字段
                    if tool == "claude_code" {
                        TextField("Haiku 模型", text: $haikuModel, prompt: Text("空=默认"))
                        TextField("Sonnet 模型", text: $sonnetModel, prompt: Text("空=默认"))
                        TextField("Opus 模型", text: $opusModel, prompt: Text("空=默认"))
                    }
                }

                Section("高级") {
                    TextField("额外环境变量 (JSON)", text: $extraEnv, prompt: Text("{}"), axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3...6)

                    TextField("备注", text: $notes, prompt: Text("可选"))
                }

                // 错误提示
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // 操作按钮
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "保存" : "添加") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if let p = provider {
                name = p.name
                apiKey = p.apiKey
                apiBase = p.apiBase
                model = p.model
                extraEnv = p.extraEnv
                notes = p.notes ?? ""

                // 解析 Claude 多模型
                if let extra = p.extraEnvDict {
                    haikuModel = extra["ANTHROPIC_DEFAULT_HAIKU_MODEL"] ?? ""
                    sonnetModel = extra["ANTHROPIC_DEFAULT_SONNET_MODEL"] ?? ""
                    opusModel = extra["ANTHROPIC_DEFAULT_OPUS_MODEL"] ?? ""
                }
            }
        }
    }

    private func save() {
        errorMessage = nil

        let formData = ProviderFormData(
            name: name.trimmingCharacters(in: .whitespaces),
            tool: tool,
            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
            apiBase: apiBase.trimmingCharacters(in: .whitespaces),
            model: model,
            extraEnv: extraEnv,
            icon: provider?.icon,
            iconColor: provider?.iconColor,
            notes: notes.isEmpty ? nil : notes,
            category: provider?.category,
            presetId: provider?.presetId,
            haikuModel: haikuModel,
            sonnetModel: sonnetModel,
            opusModel: opusModel
        )

        do {
            if let existingProvider = provider {
                _ = try appState.providerService.updateProvider(id: existingProvider.id, data: formData)
            } else {
                _ = try appState.providerService.createProvider(formData)
            }
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let tool: String
    let onSave: () -> Void

    @State private var selectedPreset: ProviderPreset?
    @State private var apiKey = ""
    @State private var errorMessage: String?

    private var filteredPresets: [ProviderPreset] {
        ProviderPreset.presets.filter { $0.tool == tool }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("从预设添加")
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
                ForEach(filteredPresets) { preset in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(preset.name)
                                .font(.system(size: 13, weight: .medium))
                            Text(preset.apiBase.isEmpty ? "官方默认端点" : preset.apiBase)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(preset.defaultModel)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        if selectedPreset?.id == preset.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedPreset = preset }
                    .listRowBackground(
                        selectedPreset?.id == preset.id
                            ? Color(nsColor: .separatorColor).opacity(0.3)
                            : Color.clear
                    )
                }
            }
            .listStyle(.inset)

            if selectedPreset != nil {
                Divider()
                HStack {
                    SecureField("API Key *", text: $apiKey, prompt: Text("输入 API Key"))
                    Button("添加") { addFromPreset() }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .frame(width: 450, height: 400)
    }

    private func addFromPreset() {
        guard let preset = selectedPreset else { return }
        errorMessage = nil

        let formData = ProviderFormData(
            name: preset.name,
            tool: preset.tool,
            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
            apiBase: preset.apiBase,
            model: preset.defaultModel,
            icon: preset.icon,
            iconColor: preset.iconColor,
            presetId: preset.id
        )

        do {
            _ = try appState.providerService.createProvider(formData)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
