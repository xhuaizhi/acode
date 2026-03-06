import Foundation

/// Token 用量记录
struct UsageRecord: Identifiable, Codable {
    let id: UUID
    let tool: String           // claude_code / openai / gemini
    let providerId: Int64
    let model: String
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheCreationTokens: Int64
    let cost: Double           // 预估费用（美元）
    let timestamp: Date

    var totalTokens: Int64 {
        inputTokens + outputTokens
    }
}

/// 用量统计摘要
struct UsageSummary {
    var totalInputTokens: Int64 = 0
    var totalOutputTokens: Int64 = 0
    var totalCacheReadTokens: Int64 = 0
    var totalCost: Double = 0.0
    var requestCount: Int = 0

    var totalTokens: Int64 { totalInputTokens + totalOutputTokens }

    /// 格式化 Token 数量（K/M）
    static func formatTokens(_ count: Int64) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    /// 格式化费用
    static func formatCost(_ cost: Double) -> String {
        if cost >= 1.0 {
            return String(format: "$%.2f", cost)
        } else if cost >= 0.01 {
            return String(format: "$%.3f", cost)
        }
        return String(format: "$%.4f", cost)
    }
}

/// 成本明细（Decimal 高精度）
struct CostBreakdown {
    let inputCost: Decimal
    let outputCost: Decimal
    let cacheReadCost: Decimal
    let cacheCreationCost: Decimal
    let totalCost: Decimal

    var totalCostDouble: Double {
        NSDecimalNumber(decimal: totalCost).doubleValue
    }
}

/// Token 费用计算器（使用 Decimal 128 位高精度，避免浮点精度丢失）
enum CostCalculator {
    private static let million = Decimal(1_000_000)

    /// 根据模型定价计算单次请求费用
    /// - billable_input = max(input_tokens - cache_read_tokens, 0)（扣除缓存命中）
    /// - total_cost = base_total × costMultiplier
    static func calculate(
        inputTokens: Int64,
        outputTokens: Int64,
        cacheReadTokens: Int64 = 0,
        cacheCreationTokens: Int64 = 0,
        pricing: ModelPricing,
        costMultiplier: Decimal = 1.0
    ) -> CostBreakdown {
        let billableInput = max(Int64(0), inputTokens - cacheReadTokens)
        let inputCost = Decimal(billableInput) * pricing.inputCostPerMillionDecimal / million
        let outputCost = Decimal(outputTokens) * pricing.outputCostPerMillionDecimal / million
        let cacheReadCost = Decimal(cacheReadTokens) * pricing.cacheReadCostPerMillionDecimal / million
        let cacheCreationCost = Decimal(cacheCreationTokens) * pricing.cacheCreationCostPerMillionDecimal / million
        let baseTotal = inputCost + outputCost + cacheReadCost + cacheCreationCost
        return CostBreakdown(
            inputCost: inputCost,
            outputCost: outputCost,
            cacheReadCost: cacheReadCost,
            cacheCreationCost: cacheCreationCost,
            totalCost: baseTotal * costMultiplier
        )
    }

    /// 便捷方法：返回 Double 总费用（向后兼容）
    static func calculateTotalCost(
        inputTokens: Int64,
        outputTokens: Int64,
        cacheReadTokens: Int64 = 0,
        cacheCreationTokens: Int64 = 0,
        pricing: ModelPricing,
        costMultiplier: Decimal = 1.0
    ) -> Double {
        calculate(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens,
            pricing: pricing,
            costMultiplier: costMultiplier
        ).totalCostDouble
    }
}

/// 模型定价数据
struct ModelPricing {
    let modelId: String
    let displayName: String
    let inputCostPerMillion: Double
    let outputCostPerMillion: Double
    let cacheReadCostPerMillion: Double
    let cacheCreationCostPerMillion: Double

    // Decimal 精度访问器
    var inputCostPerMillionDecimal: Decimal { Decimal(string: String(inputCostPerMillion)) ?? Decimal(inputCostPerMillion) }
    var outputCostPerMillionDecimal: Decimal { Decimal(string: String(outputCostPerMillion)) ?? Decimal(outputCostPerMillion) }
    var cacheReadCostPerMillionDecimal: Decimal { Decimal(string: String(cacheReadCostPerMillion)) ?? Decimal(cacheReadCostPerMillion) }
    var cacheCreationCostPerMillionDecimal: Decimal { Decimal(string: String(cacheCreationCostPerMillion)) ?? Decimal(cacheCreationCostPerMillion) }
}
