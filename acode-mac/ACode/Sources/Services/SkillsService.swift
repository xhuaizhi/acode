import Foundation

/// 技能管理服务
/// 将技能持久化到本地 JSON 文件，并根据启用状态写入对应 AI 工具的配置目录
final class SkillsService {

    static let shared = SkillsService()

    // MARK: - Storage Path

    private var skillsDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("ACode/skills", isDirectory: true)
    }

    private var indexPath: URL {
        skillsDir.appendingPathComponent("index.json")
    }

    // MARK: - Claude CLAUDE.md path

    private var homeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// ~/.claude/CLAUDE.md — Claude Code 的自定义指令文件
    private var claudeInstructionsPath: URL {
        homeDir.appendingPathComponent(".claude/CLAUDE.md")
    }

    /// ~/.codex/instructions.md — Codex CLI 的自定义指令文件
    private var codexInstructionsPath: URL {
        homeDir.appendingPathComponent(".codex/instructions.md")
    }

    /// ~/.gemini/GEMINI.md — Gemini CLI 的自定义指令文件
    private var geminiInstructionsPath: URL {
        homeDir.appendingPathComponent(".gemini/GEMINI.md")
    }

    // MARK: - CRUD

    /// 获取所有技能
    func listSkills() -> [Skill] {
        guard let data = try? Data(contentsOf: indexPath),
              let skills = try? JSONDecoder().decode([Skill].self, from: data) else {
            return []
        }
        return skills
    }

    /// 保存技能（新建或更新）
    func saveSkill(_ skill: Skill) throws {
        var skills = listSkills()

        if let idx = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[idx] = skill
        } else {
            skills.append(skill)
        }

        try persistSkills(skills)
        syncInstructionFiles(skills: skills)
    }

    /// 删除技能
    func deleteSkill(_ skill: Skill) {
        var skills = listSkills()
        skills.removeAll { $0.id == skill.id }
        try? persistSkills(skills)
        syncInstructionFiles(skills: skills)
    }

    /// 切换技能在指定 app 的启用状态
    func toggleSkillApp(_ skill: Skill, app: String, enabled: Bool) {
        var skills = listSkills()
        guard let idx = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        if enabled {
            skills[idx].enabledApps.insert(app)
        } else {
            skills[idx].enabledApps.remove(app)
        }
        try? persistSkills(skills)
        syncInstructionFiles(skills: skills)
    }

    // MARK: - Persistence

    private func persistSkills(_ skills: [Skill]) throws {
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(skills)
        try data.write(to: indexPath)
    }

    // MARK: - Sync to AI Tool Config Files

    /// 将启用的技能合并写入各工具的指令文件
    private func syncInstructionFiles(skills: [Skill]) {
        let marker = "<!-- ACode Skills -->"
        let endMarker = "<!-- /ACode Skills -->"

        syncInstructionFile(
            path: claudeInstructionsPath,
            skills: skills.filter { $0.enabledApps.contains("claude") },
            marker: marker,
            endMarker: endMarker
        )

        syncInstructionFile(
            path: codexInstructionsPath,
            skills: skills.filter { $0.enabledApps.contains("codex") },
            marker: marker,
            endMarker: endMarker
        )

        syncInstructionFile(
            path: geminiInstructionsPath,
            skills: skills.filter { $0.enabledApps.contains("gemini") },
            marker: marker,
            endMarker: endMarker
        )
    }

    /// 在指令文件中替换 ACode Skills 区块
    private func syncInstructionFile(path: URL, skills: [Skill], marker: String, endMarker: String) {
        // 确保父目录存在
        let parent = path.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        var existing = (try? String(contentsOf: path, encoding: .utf8)) ?? ""

        // 移除旧的 ACode Skills 区块
        if let startRange = existing.range(of: marker),
           let endRange = existing.range(of: endMarker) {
            let fullRange = startRange.lowerBound..<endRange.upperBound
            existing.removeSubrange(fullRange)
            // 清理多余空行
            existing = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 如果没有技能需要写入，只保留清理后的内容
        if skills.isEmpty {
            if existing.isEmpty {
                // 如果文件完全为空，不写入
                return
            }
            try? existing.write(to: path, atomically: true, encoding: .utf8)
            return
        }

        // 构建新的技能区块
        var block = "\n\n\(marker)\n"
        for skill in skills {
            block += "## \(skill.name)\n"
            if !skill.description.isEmpty {
                block += "> \(skill.description)\n"
            }
            block += "\n\(skill.content)\n\n"
        }
        block += "\(endMarker)"

        existing += block

        try? existing.write(to: path, atomically: true, encoding: .utf8)
    }
}
