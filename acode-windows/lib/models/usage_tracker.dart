/// Token 用量记录
class UsageRecord {
  final String id;
  final String tool;          // claude_code / openai / gemini
  final int providerId;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final double cost;          // 预估费用（美元）
  final DateTime timestamp;

  UsageRecord({
    String? id,
    this.tool = '',
    this.providerId = 0,
    required this.model,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheCreationTokens = 0,
    this.cost = 0.0,
    DateTime? timestamp,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       timestamp = timestamp ?? DateTime.now();

  int get totalTokens => inputTokens + outputTokens;
}

/// 用量汇总
class UsageSummary {
  int totalInputTokens;
  int totalOutputTokens;
  int totalCacheReadTokens;
  int requestCount;
  double totalCost;

  UsageSummary({
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.totalCacheReadTokens = 0,
    this.requestCount = 0,
    this.totalCost = 0.0,
  });

  void addRecord(UsageRecord record, {double? inputPrice, double? outputPrice}) {
    totalInputTokens += record.inputTokens;
    totalOutputTokens += record.outputTokens;
    totalCacheReadTokens += record.cacheReadTokens;
    requestCount += 1;

    // 优先使用 record.cost（已通过 CostCalculator 预计算）
    if (record.cost > 0) {
      totalCost += record.cost;
    } else if (inputPrice != null && outputPrice != null) {
      totalCost += (record.inputTokens / 1000000.0) * inputPrice +
          (record.outputTokens / 1000000.0) * outputPrice;
    }
  }

  void reset() {
    totalInputTokens = 0;
    totalOutputTokens = 0;
    totalCacheReadTokens = 0;
    requestCount = 0;
    totalCost = 0.0;
  }

  /// 格式化 Token 数量
  static String formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return '$tokens';
  }

  /// 格式化费用
  static String formatCost(double cost) {
    if (cost >= 1.0) {
      return '\$${cost.toStringAsFixed(2)}';
    } else if (cost >= 0.01) {
      return '\$${cost.toStringAsFixed(3)}';
    }
    return '\$${cost.toStringAsFixed(4)}';
  }
}

/// 模型定价数据
class ModelPricing {
  final String modelId;
  final String displayName;
  final double inputCostPerMillion;
  final double outputCostPerMillion;
  final double cacheReadCostPerMillion;
  final double cacheCreationCostPerMillion;

  const ModelPricing({
    required this.modelId,
    required this.displayName,
    required this.inputCostPerMillion,
    required this.outputCostPerMillion,
    this.cacheReadCostPerMillion = 0,
    this.cacheCreationCostPerMillion = 0,
  });
}

/// 成本明细
class CostBreakdown {
  final double inputCost;
  final double outputCost;
  final double cacheReadCost;
  final double cacheCreationCost;
  final double totalCost;

  const CostBreakdown({
    required this.inputCost,
    required this.outputCost,
    required this.cacheReadCost,
    required this.cacheCreationCost,
    required this.totalCost,
  });
}

/// Token 费用计算器
class CostCalculator {
  static const double _million = 1000000.0;

  /// 根据模型定价计算单次请求费用
  /// billable_input = max(input_tokens - cache_read_tokens, 0)
  static CostBreakdown calculate({
    required int inputTokens,
    required int outputTokens,
    int cacheReadTokens = 0,
    int cacheCreationTokens = 0,
    required ModelPricing pricing,
    double costMultiplier = 1.0,
  }) {
    final billableInput = (inputTokens - cacheReadTokens).clamp(0, inputTokens);
    final inputCost = billableInput * pricing.inputCostPerMillion / _million;
    final outputCost = outputTokens * pricing.outputCostPerMillion / _million;
    final cacheReadCost = cacheReadTokens * pricing.cacheReadCostPerMillion / _million;
    final cacheCreationCost = cacheCreationTokens * pricing.cacheCreationCostPerMillion / _million;
    final baseTotal = inputCost + outputCost + cacheReadCost + cacheCreationCost;
    return CostBreakdown(
      inputCost: inputCost,
      outputCost: outputCost,
      cacheReadCost: cacheReadCost,
      cacheCreationCost: cacheCreationCost,
      totalCost: baseTotal * costMultiplier,
    );
  }

  /// 便捷方法：返回 double 总费用
  static double calculateTotalCost({
    required int inputTokens,
    required int outputTokens,
    int cacheReadTokens = 0,
    int cacheCreationTokens = 0,
    required ModelPricing pricing,
    double costMultiplier = 1.0,
  }) {
    return calculate(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cacheReadTokens: cacheReadTokens,
      cacheCreationTokens: cacheCreationTokens,
      pricing: pricing,
      costMultiplier: costMultiplier,
    ).totalCost;
  }
}
