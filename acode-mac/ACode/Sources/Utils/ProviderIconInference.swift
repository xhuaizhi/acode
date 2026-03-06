import Foundation

/// Provider 图标自动推断
enum ProviderIconInference {

    struct IconInfo {
        let name: String
        let color: String
    }

    /// 默认图标映射表
    private static let iconMap: [(keyword: String, icon: IconInfo)] = [
        ("openai",      IconInfo(name: "openai",     color: "#00A67E")),
        ("anthropic",   IconInfo(name: "anthropic",  color: "#D4915D")),
        ("claude",      IconInfo(name: "anthropic",  color: "#D4915D")),
        ("google",      IconInfo(name: "gemini",     color: "#4285F4")),
        ("gemini",      IconInfo(name: "gemini",     color: "#4285F4")),
        ("deepseek",    IconInfo(name: "deepseek",   color: "#1E88E5")),
        ("kimi",        IconInfo(name: "kimi",       color: "#6366F1")),
        ("moonshot",    IconInfo(name: "moonshot",   color: "#6366F1")),
        ("meta",        IconInfo(name: "meta",       color: "#0081FB")),
        ("azure",       IconInfo(name: "azure",      color: "#0078D4")),
        ("aws",         IconInfo(name: "aws",        color: "#FF9900")),
        ("cloudflare",  IconInfo(name: "cloudflare", color: "#F38020")),
        ("mistral",     IconInfo(name: "mistral",    color: "#FF7000")),
        ("openrouter",  IconInfo(name: "openrouter", color: "#6366F1")),
        ("zhipu",       IconInfo(name: "zhipu",      color: "#0F62FE")),
        ("alibaba",     IconInfo(name: "alibaba",    color: "#FF6A00")),
        ("tencent",     IconInfo(name: "tencent",    color: "#00A4FF")),
        ("baidu",       IconInfo(name: "baidu",      color: "#2932E1")),
        ("cohere",      IconInfo(name: "cohere",     color: "#39594D")),
        ("perplexity",  IconInfo(name: "perplexity", color: "#20808D")),
        ("huggingface", IconInfo(name: "huggingface",color: "#FFD21E")),
    ]

    /// 根据 Provider 名称推断图标
    static func infer(name: String) -> IconInfo? {
        let lower = name.lowercased()

        // 精确匹配
        if let match = iconMap.first(where: { lower == $0.keyword }) {
            return match.icon
        }

        // 模糊匹配（名称包含关键词）
        if let match = iconMap.first(where: { lower.contains($0.keyword) }) {
            return match.icon
        }

        return nil
    }
}
