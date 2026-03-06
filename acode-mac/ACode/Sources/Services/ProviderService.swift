import Foundation

/// Provider 业务逻辑服务
final class ProviderService {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    // MARK: - CRUD

    func listProviders(tool: String? = nil) throws -> [Provider] {
        try database.getAllProviders(tool: tool)
    }

    func getActiveProvider(tool: String) throws -> Provider? {
        try database.getActiveProvider(tool: tool)
    }

    func createProvider(_ data: ProviderFormData) throws -> Provider {
        // 验证
        guard !data.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ProviderError.invalidName
        }
        guard !data.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ProviderError.invalidApiKey
        }
        if !data.apiBase.isEmpty {
            guard URL(string: data.apiBase) != nil else {
                throw ProviderError.invalidUrl
            }
        }

        // 构建 extraEnv（Claude 多模型字段写入 extra_env）
        var formData = data
        if data.tool == "claude_code" {
            var extra = (try? JSONDecoder().decode(
                [String: String].self,
                from: data.extraEnv.data(using: .utf8) ?? Data()
            )) ?? [:]

            if !data.haikuModel.isEmpty {
                extra["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = data.haikuModel
            }
            if !data.sonnetModel.isEmpty {
                extra["ANTHROPIC_DEFAULT_SONNET_MODEL"] = data.sonnetModel
            }
            if !data.opusModel.isEmpty {
                extra["ANTHROPIC_DEFAULT_OPUS_MODEL"] = data.opusModel
            }

            if let jsonData = try? JSONEncoder().encode(extra),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                formData.extraEnv = jsonString
            }
        }

        // 自动推断图标
        if formData.icon == nil {
            let inferred = ProviderIconInference.infer(name: data.name)
            formData.icon = inferred?.name
            formData.iconColor = inferred?.color
        }

        let rowId = try database.insertProvider(formData)

        guard let provider = try database.getProvider(id: rowId) else {
            throw ProviderError.notFound
        }

        // 如果自动激活了，写入 Live 配置
        if provider.isActive {
            try ProviderConfigWriter.writeConfig(provider)
        }

        return provider
    }

    func updateProvider(id: Int64, data: ProviderFormData) throws -> Provider {
        // 验证
        guard !data.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ProviderError.invalidName
        }
        guard !data.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ProviderError.invalidApiKey
        }
        if !data.apiBase.isEmpty {
            guard URL(string: data.apiBase) != nil else {
                throw ProviderError.invalidUrl
            }
        }

        // 构建 extraEnv（Claude 多模型字段）
        var formData = data
        if data.tool == "claude_code" {
            var extra = (try? JSONDecoder().decode(
                [String: String].self,
                from: data.extraEnv.data(using: .utf8) ?? Data()
            )) ?? [:]

            if !data.haikuModel.isEmpty {
                extra["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = data.haikuModel
            }
            if !data.sonnetModel.isEmpty {
                extra["ANTHROPIC_DEFAULT_SONNET_MODEL"] = data.sonnetModel
            }
            if !data.opusModel.isEmpty {
                extra["ANTHROPIC_DEFAULT_OPUS_MODEL"] = data.opusModel
            }

            if let jsonData = try? JSONEncoder().encode(extra),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                formData.extraEnv = jsonString
            }
        }

        try database.updateProvider(id: id, data: formData)

        guard let provider = try database.getProvider(id: id) else {
            throw ProviderError.notFound
        }

        // 如果是当前激活的 Provider，更新 Live 配置
        if provider.isActive {
            try ProviderConfigWriter.writeConfig(provider)
        }

        return provider
    }

    func deleteProvider(id: Int64) throws {
        let provider = try database.getProvider(id: id)
        try database.deleteProvider(id: id)

        // 如果删除后有新的自动激活 Provider，写入 Live 配置
        if let tool = provider?.tool,
           let newActive = try database.getActiveProvider(tool: tool) {
            try ProviderConfigWriter.writeConfig(newActive)
        }
    }

    // MARK: - 切换

    func switchProvider(id: Int64) throws -> Provider {
        let provider = try database.switchProvider(id: id)

        // 写入 Live 配置文件
        try ProviderConfigWriter.writeConfig(provider)

        return provider
    }

    // MARK: - 环境变量生成

    func getProviderEnv(tool: String) throws -> [String: String] {
        guard let provider = try getActiveProvider(tool: tool) else {
            return [:]
        }
        return ProviderEnvGenerator.generate(for: provider)
    }
}
