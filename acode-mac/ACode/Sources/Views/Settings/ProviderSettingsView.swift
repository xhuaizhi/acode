import SwiftUI

/// Provider 管理设置页 — 原生 Form/List 风格，支持添加/编辑/删除/切换
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
        VStack(alignment: .leading, spacing: 20) {
            // 供应商列表
            SettingsSection(title: "已配置 (\(toolProviders.count))") {
                if toolProviders.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "tray")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("暂无供应商")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text("点击下方按钮添加")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
                } else {
                    ForEach(toolProviders) { provider in
                        ProviderRow(
                            provider: provider,
                            onEdit: { editingProvider = provider },
                            onDelete: { appState.deleteProvider(id: provider.id) },
                            onSwitch: { appState.switchProvider(id: provider.id) }
                        )

                        if provider.id != toolProviders.last?.id {
                            Divider()
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }

            // 操作按钮
            HStack(spacing: 10) {
                Button(action: { showAddSheet = true }) {
                    Label("手动添加", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button(action: { showPresetSheet = true }) {
                    Label("从预设添加", systemImage: "list.bullet")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Text("点击圆点切换激活")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

// MARK: - Provider Row (原生列表行)

struct ProviderRow: View {
    let provider: Provider
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSwitch: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // 激活状态指示（点击切换）
            Button(action: onSwitch) {
                Image(systemName: provider.isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(provider.isActive ? .green : .secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .help(provider.isActive ? "当前激活" : "切换到此供应商")

            // 信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .font(.system(size: 14, weight: provider.isActive ? .medium : .regular))
                    if provider.isActive {
                        Text("使用中")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                HStack(spacing: 6) {
                    if !provider.model.isEmpty {
                        Text(provider.model)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Text(provider.maskedApiKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            Spacer()

            // 编辑/删除
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
                Text("确定要删除供应商 \"\(provider.name)\" 吗？")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
