import SwiftUI
import Combine

/// 应用全局状态
@MainActor
final class AppState: ObservableObject {
    // MARK: - UI State
    @Published var statusMessage: String = ""
    @Published var terminalCount: Int = 1
    @Published var showSettings: Bool = false

    // MARK: - Active File Info
    @Published var activeFileURL: URL? = nil
    @Published var activeFileLineCount: Int? = nil
    @Published var activeFileModDate: Date? = nil

    // MARK: - Services
    let database: DatabaseManager
    let providerService: ProviderService

    // MARK: - Provider State
    @Published var providers: [Provider] = []
    @Published var activeProviders: [String: Provider] = [:] // tool -> active provider

    // MARK: - Usage Tracking
    @Published var sessionUsage = UsageSummary()

    init() {
        self.database = DatabaseManager()
        self.providerService = ProviderService(database: database)

        // 初始加载
        loadProviders()
    }

    // MARK: - Provider Operations

    func loadProviders() {
        do {
            providers = try providerService.listProviders()
            activeProviders = [:]
            for tool in ["claude_code", "openai", "gemini"] {
                if let active = try? providerService.getActiveProvider(tool: tool) {
                    activeProviders[tool] = active
                }
            }
        } catch {
            statusMessage = "加载供应商失败: \(error.localizedDescription)"
        }
    }

    func switchProvider(id: Int64) {
        do {
            let provider = try providerService.switchProvider(id: id)
            loadProviders()
            statusMessage = "已切换到 \(provider.name)"
            NotificationCenter.default.post(name: .providerSwitched, object: provider)
        } catch {
            statusMessage = "切换供应商失败: \(error.localizedDescription)"
        }
    }

    func deleteProvider(id: Int64) {
        do {
            try providerService.deleteProvider(id: id)
            loadProviders()
            statusMessage = "供应商已删除"
        } catch {
            statusMessage = "删除供应商失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "常规"
    case claude = "Claude"
    case openai = "OpenAI"
    case gemini = "Gemini"
    case usage = "用量"
    case about = "关于"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .claude: return "bubble.left.fill"
        case .openai: return "hexagon"
        case .gemini: return "sparkle"
        case .usage: return "chart.bar"
        case .about: return "info.circle"
        }
    }

    var group: String {
        switch self {
        case .general: return "基础"
        case .claude, .openai, .gemini: return "服务商"
        case .usage: return "高级"
        case .about: return "其他"
        }
    }
}
