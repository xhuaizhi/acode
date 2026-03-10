import SwiftUI

/// 技能管理设置页 — 管理 Claude / OpenAI / Gemini 的自定义指令和行为配置
struct SkillsSettingsView: View {
    @State private var skills: [Skill] = []
    @State private var showAddSheet = false
    @State private var editingSkill: Skill?

    private let service = SkillsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 说明
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.blue.opacity(0.7))
                Text("技能是自定义指令文件，可为 AI 工具提供额外的上下文和行为规则。配置后将自动写入对应工具的配置目录。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.04))
            )

            // 技能列表
            SettingsSection(title: "已配置 (\(skills.count))") {
                if skills.isEmpty {
                    emptyState
                } else {
                    skillList
                }
            }

            // 操作按钮
            HStack(spacing: 10) {
                Button(action: { showAddSheet = true }) {
                    Label("添加技能", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
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
            SkillFormSheet(skill: nil) {
                refresh()
            }
        }
        .sheet(item: $editingSkill) { skill in
            SkillFormSheet(skill: skill) {
                refresh()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))

            Text("还没有自定义技能")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("添加技能为 Claude / Codex / Gemini 提供自定义指令")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Skill List

    private var skillList: some View {
        VStack(spacing: 0) {
            ForEach(skills) { skill in
                SkillCard(
                    skill: skill,
                    onEdit: { editingSkill = skill },
                    onDelete: { deleteSkill(skill) },
                    onToggle: { app, enabled in toggleSkill(skill, app: app, enabled: enabled) }
                )

                if skill.id != skills.last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Actions

    private func refresh() {
        skills = service.listSkills()
    }

    private func deleteSkill(_ skill: Skill) {
        service.deleteSkill(skill)
        refresh()
    }

    private func toggleSkill(_ skill: Skill, app: String, enabled: Bool) {
        service.toggleSkillApp(skill, app: app, enabled: enabled)
        refresh()
    }
}

// MARK: - Skill Card

struct SkillCard: View {
    let skill: Skill
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: (String, Bool) -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // 信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(skill.name)
                        .font(.system(size: 14, weight: .medium))
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
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
                        Text("确定要删除技能 \"\(skill.name)\" 吗？")
                    }
                }
            }

            // 应用启用开关
            HStack(spacing: 16) {
                ForEach(["claude", "codex", "gemini"], id: \.self) { app in
                    Toggle(isOn: Binding(
                        get: { skill.enabledApps.contains(app) },
                        set: { onToggle(app, $0) }
                    )) {
                        Text(appDisplayName(app))
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func appDisplayName(_ app: String) -> String {
        switch app {
        case "claude": return "Claude"
        case "codex": return "Codex"
        case "gemini": return "Gemini"
        default: return app
        }
    }
}

// MARK: - Skill Add/Edit Form Sheet

struct SkillFormSheet: View {
    @Environment(\.dismiss) var dismiss

    let skill: Skill?
    let onSave: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var content = ""
    @State private var enabledApps: Set<String> = ["claude", "codex", "gemini"]
    @State private var errorMessage: String?

    private var isEditing: Bool { skill != nil }
    private let service = SkillsService.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "编辑技能" : "添加技能")
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
                    TextField("名称 *", text: $name, prompt: Text("如：代码审查规则"))
                    TextField("描述", text: $description, prompt: Text("可选"))
                }

                Section("指令内容") {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                }

                Section("启用的工具") {
                    Toggle("Claude Code", isOn: appBinding("claude"))
                    Toggle("Codex CLI", isOn: appBinding("codex"))
                    Toggle("Gemini CLI", isOn: appBinding("gemini"))
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 540, height: 580)
        .onAppear {
            if let s = skill {
                name = s.name
                description = s.description
                content = s.content
                enabledApps = s.enabledApps
            }
        }
    }

    private func appBinding(_ app: String) -> Binding<Bool> {
        Binding(
            get: { enabledApps.contains(app) },
            set: { enabled in
                if enabled { enabledApps.insert(app) }
                else { enabledApps.remove(app) }
            }
        )
    }

    private func save() {
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "名称不能为空"
            return
        }

        let newSkill = Skill(
            id: skill?.id ?? UUID().uuidString,
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespaces),
            content: content,
            enabledApps: enabledApps
        )

        do {
            try service.saveSkill(newSkill)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
