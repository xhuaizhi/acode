import Foundation

/// Provider 环境变量生成器
/// 根据激活的 Provider 生成注入到 PTY 进程的环境变量
enum ProviderEnvGenerator {

    /// 为指定 Provider 生成环境变量字典
    static func generate(for provider: Provider) -> [String: String] {
        var env: [String: String] = [:]

        switch provider.tool {
        case "claude_code":
            if !provider.apiKey.isEmpty {
                env["ANTHROPIC_API_KEY"] = provider.apiKey
            }
            if !provider.apiBase.isEmpty {
                env["ANTHROPIC_BASE_URL"] = provider.apiBase
            }
            if !provider.model.isEmpty {
                env["ANTHROPIC_MODEL"] = provider.model
            }

        case "openai":
            if !provider.apiKey.isEmpty {
                env["OPENAI_API_KEY"] = provider.apiKey
            }
            if !provider.apiBase.isEmpty {
                env["OPENAI_BASE_URL"] = provider.apiBase
            }
            if !provider.model.isEmpty {
                env["OPENAI_MODEL"] = provider.model
            }

        case "gemini":
            if !provider.apiKey.isEmpty {
                env["GOOGLE_API_KEY"] = provider.apiKey
                env["GEMINI_API_KEY"] = provider.apiKey
            }
            if !provider.apiBase.isEmpty {
                env["GOOGLE_GEMINI_BASE_URL"] = provider.apiBase
                env["GEMINI_BASE_URL"] = provider.apiBase
            }
            if !provider.model.isEmpty {
                env["GEMINI_MODEL"] = provider.model
            }

        default:
            break
        }

        // 合并 extra_env
        if let extra = provider.extraEnvDict {
            for (key, value) in extra {
                env[key] = value
            }
        }

        return env
    }
}
