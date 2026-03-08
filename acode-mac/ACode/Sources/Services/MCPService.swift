import Foundation

/// MCP 服务器配置管理服务
/// 读写 Claude / Codex / Gemini 的 MCP 配置文件，与桌面端 Tauri 后端逻辑对齐
final class MCPService {

    static let shared = MCPService()

    // MARK: - Config File Paths

    private var homeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// ~/.codex/config.toml
    private var codexConfigPath: URL {
        homeDir.appendingPathComponent(".codex/config.toml")
    }

    /// ~/.claude.json
    private var claudeRootPath: URL {
        homeDir.appendingPathComponent(".claude.json")
    }

    /// ~/.claude/settings.json
    private var claudeSettingsPath: URL {
        homeDir.appendingPathComponent(".claude/settings.json")
    }

    /// ~/.gemini/settings.json
    private var geminiSettingsPath: URL {
        homeDir.appendingPathComponent(".gemini/settings.json")
    }

    // MARK: - List

    /// 列出所有 MCP 服务器（合并多个来源）
    func listServers() -> [MCPServer] {
        var merged: [String: (spec: [String: Any], sources: Set<String>)] = [:]

        // Codex (TOML)
        if let servers = readCodexMCPServers() {
            for (id, spec) in servers {
                merged[id, default: (spec: spec, sources: [])].sources.insert("codex")
                if merged[id]?.spec.isEmpty == true { merged[id]?.spec = spec }
            }
        }

        // Claude (.claude.json)
        if let servers = readJSONMCPServers(path: claudeRootPath) {
            for (id, spec) in servers {
                merged[id, default: (spec: spec, sources: [])].sources.insert("claude")
                if merged[id]?.spec.isEmpty == true { merged[id]?.spec = spec }
            }
        }

        // Claude settings (.claude/settings.json)
        if let servers = readJSONMCPServers(path: claudeSettingsPath) {
            for (id, spec) in servers {
                merged[id, default: (spec: spec, sources: [])].sources.insert("claude")
                if merged[id]?.spec.isEmpty == true { merged[id]?.spec = spec }
            }
        }

        // Gemini
        if let servers = readJSONMCPServers(path: geminiSettingsPath) {
            for (id, spec) in servers {
                merged[id, default: (spec: spec, sources: [])].sources.insert("gemini")
                if merged[id]?.spec.isEmpty == true { merged[id]?.spec = spec }
            }
        }

        return merged.map { id, entry in
            MCPServer(
                id: id,
                transport: inferTransport(spec: entry.spec),
                summary: inferSummary(spec: entry.spec),
                sources: entry.sources.sorted(),
                spec: entry.spec
            )
        }.sorted { $0.id < $1.id }
    }

    // MARK: - Upsert

    /// 添加或更新 MCP 服务器（同步写入所有配置文件）
    func upsertServer(_ data: MCPFormData) throws {
        let id = data.id.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { throw MCPError.emptyId }

        let transport = data.transport.lowercased()
        guard ["stdio", "http", "sse"].contains(transport) else { throw MCPError.invalidTransport }

        // 构建 JSON spec
        var jsonSpec: [String: Any] = [:]
        if transport == "stdio" {
            let command = data.command.trimmingCharacters(in: .whitespaces)
            guard !command.isEmpty else { throw MCPError.emptyCommand }
            jsonSpec["command"] = command
            if !data.args.isEmpty {
                jsonSpec["args"] = data.args
            }
        } else {
            let url = data.url.trimmingCharacters(in: .whitespaces)
            guard !url.isEmpty else { throw MCPError.emptyUrl }
            jsonSpec["type"] = transport
            jsonSpec["url"] = url
        }

        // 写入 Codex TOML
        try upsertCodexMCPServer(id: id, transport: transport, data: data)

        // 写入 Claude JSON
        try upsertJSONMCPServer(path: claudeRootPath, id: id, spec: jsonSpec)
        try upsertJSONMCPServer(path: claudeSettingsPath, id: id, spec: jsonSpec)

        // 写入 Gemini JSON
        try upsertJSONMCPServer(path: geminiSettingsPath, id: id, spec: jsonSpec)
    }

    // MARK: - Delete

    /// 从所有配置文件中删除 MCP 服务器
    func deleteServer(id: String) throws {
        removeCodexMCPServer(id: id)
        try removeJSONMCPServer(path: claudeRootPath, id: id)
        try removeJSONMCPServer(path: claudeSettingsPath, id: id)
        try removeJSONMCPServer(path: geminiSettingsPath, id: id)
    }

    // MARK: - Toggle Per App

    /// 切换指定应用中的 MCP 服务器启用状态
    func toggleApp(app: String, id: String, enabled: Bool) throws {
        // 先获取当前 spec
        let servers = listServers()
        guard let server = servers.first(where: { $0.id == id }) else {
            throw MCPError.serverNotFound(id)
        }

        switch app {
        case "claude":
            if enabled {
                try upsertJSONMCPServer(path: claudeRootPath, id: id, spec: server.spec)
                try upsertJSONMCPServer(path: claudeSettingsPath, id: id, spec: server.spec)
            } else {
                try removeJSONMCPServer(path: claudeRootPath, id: id)
                try removeJSONMCPServer(path: claudeSettingsPath, id: id)
            }
        case "codex":
            if enabled {
                let formData = MCPFormData(
                    id: id,
                    transport: server.transport,
                    command: server.spec["command"] as? String ?? "",
                    args: server.spec["args"] as? [String] ?? [],
                    url: server.spec["url"] as? String ?? ""
                )
                try upsertCodexMCPServer(id: id, transport: server.transport, data: formData)
            } else {
                removeCodexMCPServer(id: id)
            }
        case "gemini":
            if enabled {
                try upsertJSONMCPServer(path: geminiSettingsPath, id: id, spec: server.spec)
            } else {
                try removeJSONMCPServer(path: geminiSettingsPath, id: id)
            }
        default:
            throw MCPError.unsupportedApp(app)
        }
    }

    // MARK: - Validate Command

    /// 验证命令是否存在于 PATH 中
    func validateCommand(_ cmd: String) -> Bool {
        let trimmed = cmd.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [trimmed]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - JSON Config Read/Write

    private func readJSONMCPServers(path: URL) -> [String: [String: Any]]? {
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        guard let data = try? Data(contentsOf: path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = root["mcpServers"] as? [String: [String: Any]] else {
            return nil
        }
        return servers
    }

    private func upsertJSONMCPServer(path: URL, id: String, spec: [String: Any]) throws {
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: path.path),
           let data = try? Data(contentsOf: path),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }

        var servers = root["mcpServers"] as? [String: Any] ?? [:]
        servers[id] = spec
        root["mcpServers"] = servers

        // 确保父目录存在
        let parent = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let jsonData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: path)
    }

    private func removeJSONMCPServer(path: URL, id: String) throws {
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        guard var servers = root["mcpServers"] as? [String: Any] else { return }
        guard servers.removeValue(forKey: id) != nil else { return }

        if servers.isEmpty {
            root.removeValue(forKey: "mcpServers")
        } else {
            root["mcpServers"] = servers
        }

        let jsonData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: path)
    }

    // MARK: - Codex TOML Read/Write (简单解析)

    private func readCodexMCPServers() -> [String: [String: Any]]? {
        guard FileManager.default.fileExists(atPath: codexConfigPath.path),
              let content = try? String(contentsOf: codexConfigPath, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var result: [String: [String: Any]] = [:]

        // 简单 TOML 解析：查找 [mcp_servers.xxx] 段
        let lines = content.components(separatedBy: .newlines)
        var currentServer: String?
        var currentSpec: [String: Any] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 检测 [mcp_servers.xxx] 段头
            if let match = trimmed.range(of: #"^\[mcp_servers\.(.+)\]$"#, options: .regularExpression) {
                // 保存上一个 server
                if let prev = currentServer {
                    result[prev] = currentSpec
                }
                let fullMatch = String(trimmed[match])
                let serverName = String(fullMatch.dropFirst("[mcp_servers.".count).dropLast(1))
                currentServer = serverName
                currentSpec = [:]
                continue
            }

            // 如果遇到其他段头，结束当前 server
            if trimmed.hasPrefix("[") && currentServer != nil {
                result[currentServer!] = currentSpec
                currentServer = nil
                currentSpec = [:]
                continue
            }

            // 解析键值对
            if currentServer != nil, let eqIdx = trimmed.firstIndex(of: "=") {
                let key = trimmed[trimmed.startIndex..<eqIdx].trimmingCharacters(in: .whitespaces)
                let rawValue = trimmed[trimmed.index(after: eqIdx)...].trimmingCharacters(in: .whitespaces)

                if rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"") {
                    // 字符串值
                    let strValue = String(rawValue.dropFirst().dropLast())
                    currentSpec[key] = strValue
                } else if rawValue.hasPrefix("[") {
                    // 数组值 — 简单解析字符串数组
                    let inner = rawValue.dropFirst().dropLast()
                    let items = inner.components(separatedBy: ",").compactMap { item -> String? in
                        let t = item.trimmingCharacters(in: .whitespaces)
                        if t.hasPrefix("\"") && t.hasSuffix("\"") {
                            return String(t.dropFirst().dropLast())
                        }
                        return t.isEmpty ? nil : t
                    }
                    currentSpec[key] = items
                }
            }
        }

        // 保存最后一个 server
        if let last = currentServer {
            result[last] = currentSpec
        }

        return result.isEmpty ? nil : result
    }

    private func upsertCodexMCPServer(id: String, transport: String, data: MCPFormData) throws {
        var content = ""
        if FileManager.default.fileExists(atPath: codexConfigPath.path) {
            content = (try? String(contentsOf: codexConfigPath, encoding: .utf8)) ?? ""
        }

        // 先移除已有的同名段
        content = removeTomlSection(content: content, sectionName: "mcp_servers.\(id)")

        // 追加新段
        var section = "\n[mcp_servers.\(id)]\n"
        if transport == "stdio" {
            let command = data.command.trimmingCharacters(in: .whitespaces)
            section += "command = \"\(escapeTomlString(command))\"\n"
            if !data.args.isEmpty {
                let argsStr = data.args.map { "\"\(escapeTomlString($0))\"" }.joined(separator: ", ")
                section += "args = [\(argsStr)]\n"
            }
        } else {
            section += "type = \"\(transport)\"\n"
            let url = data.url.trimmingCharacters(in: .whitespaces)
            section += "url = \"\(escapeTomlString(url))\"\n"
        }

        content += section

        // 确保父目录存在
        let parent = codexConfigPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try content.write(to: codexConfigPath, atomically: true, encoding: .utf8)
    }

    @discardableResult
    private func removeCodexMCPServer(id: String) -> Bool {
        guard FileManager.default.fileExists(atPath: codexConfigPath.path),
              var content = try? String(contentsOf: codexConfigPath, encoding: .utf8) else {
            return false
        }

        let newContent = removeTomlSection(content: content, sectionName: "mcp_servers.\(id)")
        guard newContent != content else { return false }
        content = newContent
        try? content.write(to: codexConfigPath, atomically: true, encoding: .utf8)
        return true
    }

    // MARK: - TOML Helpers

    private func removeTomlSection(content: String, sectionName: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var result: [String] = []
        var skipping = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[\(sectionName)]" {
                skipping = true
                continue
            }
            if skipping && trimmed.hasPrefix("[") {
                skipping = false
            }
            if !skipping {
                result.append(line)
            }
        }

        // 去除尾部连续空行
        while result.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            result.removeLast()
        }

        return result.joined(separator: "\n")
    }

    private func escapeTomlString(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Inference Helpers

    private func inferTransport(spec: [String: Any]) -> String {
        if let t = spec["type"] as? String { return t }
        if spec["command"] != nil { return "stdio" }
        if spec["httpUrl"] != nil { return "http" }
        if spec["url"] != nil { return "sse" }
        return "unknown"
    }

    private func inferSummary(spec: [String: Any]) -> String {
        if let cmd = spec["command"] as? String { return cmd }
        if let url = spec["url"] as? String { return url }
        if let url = spec["httpUrl"] as? String { return url }
        return "已配置"
    }
}

// MARK: - Errors

enum MCPError: LocalizedError {
    case emptyId
    case invalidTransport
    case emptyCommand
    case emptyUrl
    case serverNotFound(String)
    case unsupportedApp(String)

    var errorDescription: String? {
        switch self {
        case .emptyId: return "MCP 名称不能为空"
        case .invalidTransport: return "MCP 类型仅支持 stdio / http / sse"
        case .emptyCommand: return "stdio 类型需要 command 字段"
        case .emptyUrl: return "http/sse 类型需要 url 字段"
        case .serverNotFound(let id): return "MCP 服务器 \(id) 不存在"
        case .unsupportedApp(let app): return "不支持的应用类型: \(app)"
        }
    }
}
