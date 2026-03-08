import Foundation

/// MCP 服务器数据模型
struct MCPServer: Identifiable, Equatable {
    var id: String           // 服务器唯一 ID（如 "fetch", "memory"）
    var transport: String    // stdio / http / sse
    var summary: String      // 命令或 URL 摘要
    var sources: [String]    // 来源列表（codex / claude / gemini）
    var spec: [String: Any]  // 原始配置

    static func == (lhs: MCPServer, rhs: MCPServer) -> Bool {
        lhs.id == rhs.id && lhs.transport == rhs.transport && lhs.summary == rhs.summary && lhs.sources == rhs.sources
    }
}

/// MCP 创建/编辑表单数据
struct MCPFormData {
    var id: String = ""
    var transport: String = "stdio"   // stdio / http / sse
    var command: String = ""          // stdio 模式的命令
    var args: [String] = []           // stdio 模式的参数
    var url: String = ""              // http/sse 模式的 URL
}

/// MCP 预设服务器
struct MCPPreset: Identifiable {
    let id: String
    let name: String
    let description: String
    let tags: [String]
    let docs: String
    let transport: String
    let command: String
    let args: [String]

    static let presets: [MCPPreset] = [
        MCPPreset(
            id: "fetch",
            name: "mcp-server-fetch",
            description: "通过 HTTP 获取网页内容并提取文本。",
            tags: ["stdio", "http", "web"],
            docs: "https://github.com/modelcontextprotocol/servers/tree/main/src/fetch",
            transport: "stdio",
            command: "uvx",
            args: ["mcp-server-fetch"]
        ),
        MCPPreset(
            id: "time",
            name: "@modelcontextprotocol/server-time",
            description: "获取当前时间和时区转换。",
            tags: ["stdio", "time", "utility"],
            docs: "https://github.com/modelcontextprotocol/servers/tree/main/src/time",
            transport: "stdio",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-time"]
        ),
        MCPPreset(
            id: "memory",
            name: "@modelcontextprotocol/server-memory",
            description: "基于知识图谱的持久化记忆存储。",
            tags: ["stdio", "memory", "graph"],
            docs: "https://github.com/modelcontextprotocol/servers/tree/main/src/memory",
            transport: "stdio",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-memory"]
        ),
        MCPPreset(
            id: "sequential-thinking",
            name: "@modelcontextprotocol/server-sequential-thinking",
            description: "逐步推理与结构化思考。",
            tags: ["stdio", "thinking", "reasoning"],
            docs: "https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking",
            transport: "stdio",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-sequential-thinking"]
        ),
        MCPPreset(
            id: "context7",
            name: "@upstash/context7-mcp",
            description: "从文档库中检索代码上下文和示例。",
            tags: ["stdio", "docs", "search"],
            docs: "https://github.com/upstash/context7/blob/master/README.md",
            transport: "stdio",
            command: "npx",
            args: ["-y", "@upstash/context7-mcp"]
        ),
    ]
}
