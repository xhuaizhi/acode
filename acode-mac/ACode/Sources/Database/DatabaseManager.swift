import Foundation
import SQLite

/// SQLite 数据库管理器
final class DatabaseManager {
    private var db: Connection

    /// 数据库文件路径
    static var databasePath: String {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            return NSTemporaryDirectory() + "acode.db"
        }
        let appSupport = base.appendingPathComponent("ACode", isDirectory: true)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        return appSupport.appendingPathComponent("acode.db").path
    }

    init() {
        do {
            db = try Connection(Self.databasePath)
            db.busyTimeout = 5
            try setupTables()
            try seedModelPricing()
        } catch {
            NSLog("数据库文件初始化失败，回退到内存数据库: \(error)")
            do {
                db = try Connection(.inMemory)
                try setupTables()
                try seedModelPricing()
            } catch {
                NSLog("内存数据库初始化也失败（极端情况）: \(error)")
                // .inMemory 仅在 SQLite 库本身损坏时才会失败，此时别无选择
                db = try! Connection(.inMemory)
            }
        }
    }

    init(inMemory: Bool) {
        do {
            db = try Connection(.inMemory)
            try setupTables()
        } catch {
            NSLog("内存数据库初始化失败（极端情况）: \(error)")
            db = try! Connection(.inMemory)
        }
    }

    // MARK: - Table Definitions

    struct ProvidersTable {
        static let table = Table("providers")
        static let id = SQLite.Expression<Int64>("id")
        static let name = SQLite.Expression<String>("name")
        static let tool = SQLite.Expression<String>("tool")
        static let apiKey = SQLite.Expression<String>("api_key")
        static let apiBase = SQLite.Expression<String>("api_base")
        static let model = SQLite.Expression<String>("model")
        static let isActive = SQLite.Expression<Bool>("is_active")
        static let sortOrder = SQLite.Expression<Int64>("sort_order")
        static let presetId = SQLite.Expression<String?>("preset_id")
        static let extraEnv = SQLite.Expression<String>("extra_env")
        static let icon = SQLite.Expression<String?>("icon")
        static let iconColor = SQLite.Expression<String?>("icon_color")
        static let notes = SQLite.Expression<String?>("notes")
        static let category = SQLite.Expression<String?>("category")
        static let createdAt = SQLite.Expression<Int64>("created_at")
        static let updatedAt = SQLite.Expression<Int64>("updated_at")
    }

    struct ModelPricingTable {
        static let table = Table("model_pricing")
        static let modelId = SQLite.Expression<String>("model_id")
        static let displayName = SQLite.Expression<String>("display_name")
        static let inputCostPerMillion = SQLite.Expression<String>("input_cost_per_million")
        static let outputCostPerMillion = SQLite.Expression<String>("output_cost_per_million")
        static let cacheReadCostPerMillion = SQLite.Expression<String>("cache_read_cost_per_million")
        static let cacheCreationCostPerMillion = SQLite.Expression<String>("cache_creation_cost_per_million")
    }

    struct SettingsTable {
        static let table = Table("settings")
        static let key = SQLite.Expression<String>("key")
        static let value = SQLite.Expression<String?>("value")
    }

    // MARK: - Schema Setup

    private func setupTables() throws {
        // providers 表
        try db.run(ProvidersTable.table.create(ifNotExists: true) { t in
            t.column(ProvidersTable.id, primaryKey: .autoincrement)
            t.column(ProvidersTable.name)
            t.column(ProvidersTable.tool)
            t.column(ProvidersTable.apiKey)
            t.column(ProvidersTable.apiBase, defaultValue: "")
            t.column(ProvidersTable.model, defaultValue: "")
            t.column(ProvidersTable.isActive, defaultValue: false)
            t.column(ProvidersTable.sortOrder, defaultValue: 0)
            t.column(ProvidersTable.presetId)
            t.column(ProvidersTable.extraEnv, defaultValue: "{}")
            t.column(ProvidersTable.icon)
            t.column(ProvidersTable.iconColor)
            t.column(ProvidersTable.notes)
            t.column(ProvidersTable.category)
            t.column(ProvidersTable.createdAt)
            t.column(ProvidersTable.updatedAt)
        })

        // model_pricing 表
        try db.run(ModelPricingTable.table.create(ifNotExists: true) { t in
            t.column(ModelPricingTable.modelId, primaryKey: true)
            t.column(ModelPricingTable.displayName)
            t.column(ModelPricingTable.inputCostPerMillion)
            t.column(ModelPricingTable.outputCostPerMillion)
            t.column(ModelPricingTable.cacheReadCostPerMillion, defaultValue: "0")
            t.column(ModelPricingTable.cacheCreationCostPerMillion, defaultValue: "0")
        })

        // settings 表
        try db.run(SettingsTable.table.create(ifNotExists: true) { t in
            t.column(SettingsTable.key, primaryKey: true)
            t.column(SettingsTable.value)
        })
    }

    // MARK: - Provider CRUD

    func getAllProviders(tool: String? = nil) throws -> [Provider] {
        let t = ProvidersTable.self
        var query = t.table.order(t.sortOrder.asc, t.createdAt.asc)
        if let tool = tool {
            query = query.filter(t.tool == tool)
        }

        return try db.prepare(query).map { row in
            Provider(
                id: row[t.id],
                name: row[t.name],
                tool: row[t.tool],
                apiKey: row[t.apiKey],
                apiBase: row[t.apiBase],
                model: row[t.model],
                isActive: row[t.isActive],
                sortOrder: Int32(row[t.sortOrder]),
                presetId: row[t.presetId],
                extraEnv: row[t.extraEnv],
                icon: row[t.icon],
                iconColor: row[t.iconColor],
                notes: row[t.notes],
                category: row[t.category],
                createdAt: row[t.createdAt],
                updatedAt: row[t.updatedAt]
            )
        }
    }

    func getProvider(id: Int64) throws -> Provider? {
        let t = ProvidersTable.self
        let query = t.table.filter(t.id == id)

        return try db.pluck(query).map { row in
            Provider(
                id: row[t.id],
                name: row[t.name],
                tool: row[t.tool],
                apiKey: row[t.apiKey],
                apiBase: row[t.apiBase],
                model: row[t.model],
                isActive: row[t.isActive],
                sortOrder: Int32(row[t.sortOrder]),
                presetId: row[t.presetId],
                extraEnv: row[t.extraEnv],
                icon: row[t.icon],
                iconColor: row[t.iconColor],
                notes: row[t.notes],
                category: row[t.category],
                createdAt: row[t.createdAt],
                updatedAt: row[t.updatedAt]
            )
        }
    }

    func getActiveProvider(tool: String) throws -> Provider? {
        let t = ProvidersTable.self
        let query = t.table.filter(t.tool == tool && t.isActive == true)

        return try db.pluck(query).map { row in
            Provider(
                id: row[t.id],
                name: row[t.name],
                tool: row[t.tool],
                apiKey: row[t.apiKey],
                apiBase: row[t.apiBase],
                model: row[t.model],
                isActive: row[t.isActive],
                sortOrder: Int32(row[t.sortOrder]),
                presetId: row[t.presetId],
                extraEnv: row[t.extraEnv],
                icon: row[t.icon],
                iconColor: row[t.iconColor],
                notes: row[t.notes],
                category: row[t.category],
                createdAt: row[t.createdAt],
                updatedAt: row[t.updatedAt]
            )
        }
    }

    @discardableResult
    func insertProvider(_ data: ProviderFormData) throws -> Int64 {
        let t = ProvidersTable.self
        let now = Int64(Date().timeIntervalSince1970)

        // 检查该 tool 是否已有激活的 Provider
        let hasActive = try db.scalar(
            t.table.filter(t.tool == data.tool && t.isActive == true).count
        ) > 0

        let rowId = try db.run(t.table.insert(
            t.name <- data.name,
            t.tool <- data.tool,
            t.apiKey <- data.apiKey,
            t.apiBase <- data.apiBase,
            t.model <- data.model.isEmpty ? DefaultModels.defaultModel(for: data.tool) : data.model,
            t.isActive <- !hasActive, // 如果没有激活的，自动激活
            t.sortOrder <- 0,
            t.presetId <- data.presetId,
            t.extraEnv <- data.extraEnv,
            t.icon <- data.icon,
            t.iconColor <- data.iconColor,
            t.notes <- data.notes,
            t.category <- data.category,
            t.createdAt <- now,
            t.updatedAt <- now
        ))

        return rowId
    }

    func updateProvider(id: Int64, data: ProviderFormData) throws {
        let t = ProvidersTable.self
        let now = Int64(Date().timeIntervalSince1970)
        let row = t.table.filter(t.id == id)

        try db.run(row.update(
            t.name <- data.name,
            t.apiKey <- data.apiKey,
            t.apiBase <- data.apiBase,
            t.model <- data.model,
            t.extraEnv <- data.extraEnv,
            t.icon <- data.icon,
            t.iconColor <- data.iconColor,
            t.notes <- data.notes,
            t.category <- data.category,
            t.updatedAt <- now
        ))
    }

    func deleteProvider(id: Int64) throws {
        let t = ProvidersTable.self

        // 获取要删除的 Provider
        guard let provider = try getProvider(id: id) else { return }

        try db.run(t.table.filter(t.id == id).delete())

        // 如果删除了激活的 Provider，自动激活同 tool 下一个
        if provider.isActive {
            let now = Int64(Date().timeIntervalSince1970)
            if let next = try db.pluck(
                t.table.filter(t.tool == provider.tool).order(t.updatedAt.desc).limit(1)
            ) {
                try db.run(
                    t.table.filter(t.id == next[t.id])
                        .update(t.isActive <- true, t.updatedAt <- now)
                )
            }
        }
    }

    /// 切换激活 Provider
    func switchProvider(id: Int64) throws -> Provider {
        let t = ProvidersTable.self

        guard let provider = try getProvider(id: id) else {
            throw ProviderError.notFound
        }

        let now = Int64(Date().timeIntervalSince1970)

        // 停用同 tool 所有 Provider
        try db.run(
            t.table.filter(t.tool == provider.tool)
                .update(t.isActive <- false, t.updatedAt <- now)
        )

        // 激活目标 Provider
        try db.run(
            t.table.filter(t.id == id)
                .update(t.isActive <- true, t.updatedAt <- now)
        )

        // 从数据库重新读取最新数据返回
        guard let updated = try getProvider(id: id) else {
            throw ProviderError.notFound
        }
        return updated
    }

    // MARK: - Settings

    func getSetting(key: String) throws -> String? {
        let t = SettingsTable.self
        return try db.pluck(t.table.filter(t.key == key))?[t.value]
    }

    func setSetting(key: String, value: String?) throws {
        let t = SettingsTable.self
        try db.run(t.table.insert(or: .replace, t.key <- key, t.value <- value))
    }

    // MARK: - Model Pricing Seed Data

    // MARK: - Model Pricing Queries

    func getAllModelPricing() throws -> [ModelPricing] {
        let t = ModelPricingTable.self
        return try db.prepare(t.table.order(t.modelId)).map { row in
            ModelPricing(
                modelId: row[t.modelId],
                displayName: row[t.displayName],
                inputCostPerMillion: Double(row[t.inputCostPerMillion]) ?? 0,
                outputCostPerMillion: Double(row[t.outputCostPerMillion]) ?? 0,
                cacheReadCostPerMillion: Double(row[t.cacheReadCostPerMillion]) ?? 0,
                cacheCreationCostPerMillion: Double(row[t.cacheCreationCostPerMillion]) ?? 0
            )
        }
    }

    func getModelPricing(modelId: String) throws -> ModelPricing? {
        let t = ModelPricingTable.self
        guard let row = try db.pluck(t.table.filter(t.modelId == modelId)) else { return nil }
        return ModelPricing(
            modelId: row[t.modelId],
            displayName: row[t.displayName],
            inputCostPerMillion: Double(row[t.inputCostPerMillion]) ?? 0,
            outputCostPerMillion: Double(row[t.outputCostPerMillion]) ?? 0,
            cacheReadCostPerMillion: Double(row[t.cacheReadCostPerMillion]) ?? 0,
            cacheCreationCostPerMillion: Double(row[t.cacheCreationCostPerMillion]) ?? 0
        )
    }

    private func seedModelPricing() throws {
        let t = ModelPricingTable.self
        let count = try db.scalar(t.table.count)
        guard count == 0 else { return }

        let seedData: [(String, String, String, String, String, String)] = [
            // Claude
            ("claude-3.5-haiku-20241022",       "Claude 3.5 Haiku",    "0.8",  "4.0",   "0.08",  "1.0"),
            ("claude-3-5-sonnet-20241022",      "Claude 3.5 Sonnet",   "3.0",  "15.0",  "0.3",   "3.75"),
            ("claude-sonnet-4-20250514",        "Claude 4 Sonnet",     "3.0",  "15.0",  "0.3",   "3.75"),
            ("claude-opus-4-20250514",          "Claude 4 Opus",       "15.0", "75.0",  "1.5",   "18.75"),
            // OpenAI
            ("gpt-4o",                          "GPT-4o",              "2.5",  "10.0",  "1.25",  "0"),
            ("gpt-4o-mini",                     "GPT-4o Mini",         "0.15", "0.6",   "0.075", "0"),
            ("gpt-4.1",                         "GPT-4.1",             "2.0",  "8.0",   "0.5",   "0"),
            ("gpt-4.1-mini",                    "GPT-4.1 Mini",        "0.4",  "1.6",   "0.1",   "0"),
            ("gpt-4.1-nano",                    "GPT-4.1 Nano",        "0.1",  "0.4",   "0.025", "0"),
            ("o3",                              "o3",                  "2.0",  "8.0",   "0.5",   "0"),
            ("o3-mini",                         "o3 Mini",             "1.1",  "4.4",   "0.275", "0"),
            ("o4-mini",                         "o4 Mini",             "1.1",  "4.4",   "0.275", "0"),
            ("codex-mini-latest",               "Codex Mini",          "1.5",  "6.0",   "0.375", "0"),
            // Gemini
            ("gemini-2.5-pro-preview-05-06",    "Gemini 2.5 Pro",      "1.25", "10.0",  "0.31",  "0"),
            ("gemini-2.5-flash-preview-05-20",  "Gemini 2.5 Flash",    "0.15", "0.6",   "0.0375","0"),
            ("gemini-2.0-flash",                "Gemini 2.0 Flash",    "0.1",  "0.4",   "0.025", "0"),
            // DeepSeek
            ("deepseek-chat",                   "DeepSeek V3",         "0.27", "1.1",   "0.07",  "0"),
            ("deepseek-reasoner",               "DeepSeek R1",         "0.55", "2.19",  "0.14",  "0"),
        ]

        for (modelId, displayName, input, output, cacheRead, cacheCreate) in seedData {
            try db.run(t.table.insert(or: .ignore,
                t.modelId <- modelId,
                t.displayName <- displayName,
                t.inputCostPerMillion <- input,
                t.outputCostPerMillion <- output,
                t.cacheReadCostPerMillion <- cacheRead,
                t.cacheCreationCostPerMillion <- cacheCreate
            ))
        }
    }
}

// MARK: - Errors

enum ProviderError: LocalizedError {
    case notFound
    case invalidName
    case invalidApiKey
    case invalidUrl

    var errorDescription: String? {
        switch self {
        case .notFound: return "供应商不存在"
        case .invalidName: return "供应商名称不能为空"
        case .invalidApiKey: return "API Key 不能为空"
        case .invalidUrl: return "API 端点 URL 格式无效"
        }
    }
}
