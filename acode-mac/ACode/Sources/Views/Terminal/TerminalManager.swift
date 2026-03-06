import Foundation
import Combine

/// 终端会话管理器
/// 负责管理多个终端会话的生命周期和环境变量注入
@MainActor
final class TerminalManager: ObservableObject {
    @Published var sessions: [TerminalSession] = []

    private let providerService: ProviderService

    init(providerService: ProviderService) {
        self.providerService = providerService
    }

    /// 创建新终端会话
    func createSession(
        tool: String = "claude_code",
        workingDirectory: URL? = nil
    ) -> TerminalSession {
        // 获取当前激活 Provider 的环境变量
        let providerEnv = (try? providerService.getProviderEnv(tool: tool)) ?? [:]

        let session = TerminalSession(
            tool: tool,
            workingDirectory: workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser,
            providerEnv: providerEnv
        )

        sessions.append(session)
        return session
    }

    /// 关闭终端会话
    func closeSession(id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    /// 获取指定工具类型的合并环境变量
    func getEnvironment(tool: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let providerEnv = (try? providerService.getProviderEnv(tool: tool)) ?? [:]
        for (key, value) in providerEnv {
            env[key] = value
        }
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        return env
    }
}

/// 终端会话模型
struct TerminalSession: Identifiable {
    let id = UUID()
    let tool: String
    let workingDirectory: URL
    let providerEnv: [String: String]
    var title: String = "Terminal"
    let createdAt = Date()
}
