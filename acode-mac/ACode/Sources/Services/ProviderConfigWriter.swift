import Foundation

/// CLI 配置文件写入器
/// 负责将 Provider 配置写入各 CLI 工具的配置文件
enum ProviderConfigWriter {

    /// 原子移动：先删除目标（如果存在），再移动临时文件
    private static func atomicMove(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dst.path) {
            try fm.removeItem(at: dst)
        }
        try fm.moveItem(at: src, to: dst)
    }

    /// 根据 Provider 工具类型写入对应的配置文件
    static func writeConfig(_ provider: Provider) throws {
        switch provider.tool {
        case "claude_code":
            try writeClaudeConfig(provider)
        case "openai":
            try writeCodexConfig(provider)
        case "gemini":
            try writeGeminiConfig(provider)
        default:
            break
        }
    }

    // MARK: - Claude Code → ~/.claude/settings.json

    private static func writeClaudeConfig(_ provider: Provider) throws {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        let settingsPath = claudeDir.appendingPathComponent("settings.json")
        let tmpPath = claudeDir.appendingPathComponent("settings.json.tmp")

        // 读取现有配置（合并写入，不覆盖用户其他配置）
        var settings: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsPath.path),
           let data = try? Data(contentsOf: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // 构建 env 对象
        var env = (settings["env"] as? [String: Any]) ?? [:]

        // 写入核心字段
        if !provider.apiKey.isEmpty {
            env["ANTHROPIC_API_KEY"] = provider.apiKey
        }
        if !provider.apiBase.isEmpty {
            env["ANTHROPIC_BASE_URL"] = provider.apiBase
        } else {
            env.removeValue(forKey: "ANTHROPIC_BASE_URL")
        }

        // 写入模型
        if !provider.model.isEmpty {
            settings["model"] = provider.model
        }

        // 合并 extra_env 到 env 对象（跳过 ACODE_ 前缀的内部变量）
        // 包括 Claude 多模型键（ANTHROPIC_DEFAULT_HAIKU_MODEL 等），Claude Code 通过环境变量读取
        if let extraEnvDict = provider.extraEnvDict {
            for (key, value) in extraEnvDict where !key.hasPrefix("ACODE_") {
                env[key] = value
            }
        }

        settings["env"] = env

        // 原子写入
        let jsonData = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try jsonData.write(to: tmpPath)
        try atomicMove(from: tmpPath, to: settingsPath)
    }

    // MARK: - OpenAI Codex → ~/.codex/auth.json + config.toml

    private static func writeCodexConfig(_ provider: Provider) throws {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)

        // 1. 写入 auth.json
        if !provider.apiKey.isEmpty {
            let authPath = codexDir.appendingPathComponent("auth.json")
            let tmpAuth = codexDir.appendingPathComponent("auth.json.tmp")

            var auth: [String: Any] = [:]
            if FileManager.default.fileExists(atPath: authPath.path),
               let data = try? Data(contentsOf: authPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                auth = json
            }
            auth["OPENAI_API_KEY"] = provider.apiKey

            let jsonData = try JSONSerialization.data(
                withJSONObject: auth,
                options: [.prettyPrinted, .sortedKeys]
            )
            try jsonData.write(to: tmpAuth)
            try atomicMove(from: tmpAuth, to: authPath)
        }

        // 2. 生成并写入 config.toml
        let configPath = codexDir.appendingPathComponent("config.toml")
        let tmpConfig = codexDir.appendingPathComponent("config.toml.tmp")
        let toml = generateCodexToml(provider)
        try toml.write(to: tmpConfig, atomically: true, encoding: .utf8)
        try atomicMove(from: tmpConfig, to: configPath)
    }

    /// 生成 Codex config.toml 内容
    private static func generateCodexToml(_ provider: Provider) -> String {
        let model = provider.model.isEmpty ? "o4-mini" : provider.model

        // 官方 API（无自定义端点）
        if provider.apiBase.isEmpty {
            return "model = \"\(model)\"\n"
        }

        // 第三方 API：需要 model_provider section
        let baseUrl = normalizeCodexBaseUrl(provider.apiBase)
        return """
model_provider = "acode_provider"
model = "\(model)"
disable_response_storage = true

[model_providers.acode_provider]
name = "\(provider.name)"
base_url = "\(baseUrl)"
wire_api = "responses"
requires_openai_auth = true

"""
    }

    /// 规范化 Codex Base URL
    /// - 纯 origin (如 "https://api.example.com") → 自动补 "/v1"
    /// - 已有路径 → 直接使用
    private static func normalizeCodexBaseUrl(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.hasSuffix("/v1") { return trimmed }

        // 检查是否为纯 origin（无路径部分）
        if let components = URLComponents(string: trimmed),
           components.path.isEmpty || components.path == "/" {
            return trimmed + "/v1"
        }
        return trimmed
    }

    // MARK: - Gemini CLI → ~/.gemini/.env + settings.json

    private static func writeGeminiConfig(_ provider: Provider) throws {
        let geminiDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini")
        try FileManager.default.createDirectory(at: geminiDir, withIntermediateDirectories: true)

        // 1. 写入 .env 文件
        try writeGeminiEnvFile(provider, in: geminiDir)

        // 2. 写入 settings.json（认证类型）
        if !provider.apiKey.isEmpty {
            try writeGeminiSettingsJson(in: geminiDir)
        }
    }

    private static func writeGeminiEnvFile(_ provider: Provider, in dir: URL) throws {
        let envPath = dir.appendingPathComponent(".env")
        let tmpPath = dir.appendingPathComponent(".env.tmp")

        // 解析现有 .env
        var envMap: [(String, String)] = []
        if FileManager.default.fileExists(atPath: envPath.path),
           let content = try? String(contentsOf: envPath, encoding: .utf8) {
            for line in content.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                if let eqIndex = trimmed.firstIndex(of: "=") {
                    let key = String(trimmed[trimmed.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                    envMap.append((key, value))
                }
            }
        }

        // 更新/添加 Provider 相关字段
        func setEnv(_ key: String, _ value: String) {
            if let idx = envMap.firstIndex(where: { $0.0 == key }) {
                envMap[idx] = (key, value)
            } else {
                envMap.append((key, value))
            }
        }

        func removeEnv(_ key: String) {
            envMap.removeAll { $0.0 == key }
        }

        if !provider.apiKey.isEmpty {
            setEnv("GEMINI_API_KEY", provider.apiKey)
        }
        if !provider.apiBase.isEmpty {
            setEnv("GOOGLE_GEMINI_BASE_URL", provider.apiBase)
        } else {
            removeEnv("GOOGLE_GEMINI_BASE_URL")
        }
        if !provider.model.isEmpty {
            setEnv("GEMINI_MODEL", provider.model)
        }

        // 合并 extra_env
        if let extra = provider.extraEnvDict {
            for (k, v) in extra {
                setEnv(k, v)
            }
        }

        // 输出：优先核心键
        let priorityKeys = ["GEMINI_API_KEY", "GOOGLE_GEMINI_BASE_URL", "GEMINI_MODEL"]
        var lines: [String] = []
        for key in priorityKeys {
            if let entry = envMap.first(where: { $0.0 == key }) {
                lines.append("\(entry.0)=\(entry.1)")
            }
        }
        for entry in envMap where !priorityKeys.contains(entry.0) {
            lines.append("\(entry.0)=\(entry.1)")
        }

        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: tmpPath, atomically: true, encoding: .utf8)
        try atomicMove(from: tmpPath, to: envPath)
    }

    private static func writeGeminiSettingsJson(in dir: URL) throws {
        let settingsPath = dir.appendingPathComponent("settings.json")
        let tmpPath = dir.appendingPathComponent("settings.json.tmp")

        var settings: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsPath.path),
           let data = try? Data(contentsOf: settingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // 设置认证类型
        var security = (settings["security"] as? [String: Any]) ?? [:]
        var auth = (security["auth"] as? [String: Any]) ?? [:]
        auth["selectedType"] = "gemini-api-key"
        security["auth"] = auth
        settings["security"] = security

        let jsonData = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try jsonData.write(to: tmpPath)
        try atomicMove(from: tmpPath, to: settingsPath)
    }
}
