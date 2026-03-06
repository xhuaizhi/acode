import Foundation

/// Provider 数据模型
struct Provider: Identifiable, Codable, Equatable {
    let id: Int64
    var name: String
    var tool: String           // claude_code / openai / gemini
    var apiKey: String
    var apiBase: String
    var model: String
    var isActive: Bool
    var sortOrder: Int32
    var presetId: String?
    var extraEnv: String       // JSON string
    var icon: String?
    var iconColor: String?
    var notes: String?
    var category: String?      // official / third_party / custom
    var createdAt: Int64
    var updatedAt: Int64

    /// 解析 extraEnv JSON 为字典
    var extraEnvDict: [String: String]? {
        guard let data = extraEnv.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// API Key 脱敏显示
    var maskedApiKey: String {
        guard apiKey.count > 8 else { return String(repeating: "•", count: apiKey.count) }
        let prefix = String(apiKey.prefix(4))
        let suffix = String(apiKey.suffix(4))
        return "\(prefix)•••\(suffix)"
    }

    /// 工具显示名称
    var toolDisplayName: String {
        switch tool {
        case "claude_code": return "Claude Code"
        case "openai": return "OpenAI Codex"
        case "gemini": return "Gemini CLI"
        default: return tool
        }
    }
}

/// 创建 Provider 的表单数据
struct ProviderFormData {
    var name: String = ""
    var tool: String = "claude_code"
    var apiKey: String = ""
    var apiBase: String = ""
    var model: String = ""
    var extraEnv: String = "{}"
    var icon: String?
    var iconColor: String?
    var notes: String?
    var category: String?
    var presetId: String?

    // Claude 专用模型字段
    var haikuModel: String = ""
    var sonnetModel: String = ""
    var opusModel: String = ""
}

/// Provider 预设
struct ProviderPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let tool: String
    let apiBase: String
    let defaultModel: String
    let icon: String?
    let iconColor: String?

    static let presets: [ProviderPreset] = [
        ProviderPreset(
            id: "claude-official", name: "Claude 官方", tool: "claude_code",
            apiBase: "", defaultModel: "claude-sonnet-4-20250514",
            icon: "anthropic", iconColor: "#D4915D"
        ),
        ProviderPreset(
            id: "openai-official", name: "OpenAI 官方", tool: "openai",
            apiBase: "", defaultModel: "o4-mini",
            icon: "openai", iconColor: "#00A67E"
        ),
        ProviderPreset(
            id: "gemini-official", name: "Gemini 官方", tool: "gemini",
            apiBase: "", defaultModel: "gemini-2.5-pro",
            icon: "gemini", iconColor: "#4285F4"
        ),
        ProviderPreset(
            id: "deepseek", name: "DeepSeek", tool: "openai",
            apiBase: "https://api.deepseek.com", defaultModel: "deepseek-chat",
            icon: "deepseek", iconColor: "#1E88E5"
        ),
        ProviderPreset(
            id: "openrouter", name: "OpenRouter", tool: "claude_code",
            apiBase: "https://openrouter.ai/api/v1", defaultModel: "anthropic/claude-sonnet-4",
            icon: "openrouter", iconColor: "#6366F1"
        ),
    ]
}

/// 默认模型配置
struct DefaultModels {
    static let claude: [String] = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-3.5-haiku-20241022",
        "claude-3-5-sonnet-20241022",
    ]

    static let openai: [String] = [
        "o4-mini",
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4.1-nano",
        "o3",
        "o3-mini",
        "codex-mini-latest",
    ]

    static let gemini: [String] = [
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.0-flash",
    ]

    static func models(for tool: String) -> [String] {
        switch tool {
        case "claude_code": return claude
        case "openai": return openai
        case "gemini": return gemini
        default: return []
        }
    }

    static func defaultModel(for tool: String) -> String {
        switch tool {
        case "claude_code": return "claude-sonnet-4-20250514"
        case "openai": return "o4-mini"
        case "gemini": return "gemini-2.5-pro"
        default: return ""
        }
    }
}
