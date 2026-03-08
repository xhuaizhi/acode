import Foundation

/// 技能数据模型 — 自定义指令，可按工具启用
struct Skill: Identifiable, Codable, Equatable {
    var id: String              // UUID 字符串
    var name: String            // 技能名称
    var description: String     // 技能描述
    var content: String         // 指令内容（Markdown/纯文本）
    var enabledApps: Set<String> // 启用的工具列表（claude / codex / gemini）

    static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.content == rhs.content && lhs.enabledApps == rhs.enabledApps
    }
}
