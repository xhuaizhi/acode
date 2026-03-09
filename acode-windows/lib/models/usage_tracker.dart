/// Token 用量记录
class UsageRecord {
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final DateTime timestamp;

  UsageRecord({
    required this.model,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
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

    if (inputPrice != null && outputPrice != null) {
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
    if (cost < 0.01) return '\$0.00';
    return '\$${cost.toStringAsFixed(2)}';
  }
}

/// 模型定价
class ModelPricing {
  final String model;
  final double inputPricePerMillion;
  final double outputPricePerMillion;

  const ModelPricing({
    required this.model,
    required this.inputPricePerMillion,
    required this.outputPricePerMillion,
  });

  static const List<ModelPricing> defaults = [
    ModelPricing(model: 'claude-sonnet-4-20250514', inputPricePerMillion: 3.0, outputPricePerMillion: 15.0),
    ModelPricing(model: 'claude-3-5-sonnet', inputPricePerMillion: 3.0, outputPricePerMillion: 15.0),
    ModelPricing(model: 'claude-3-opus', inputPricePerMillion: 15.0, outputPricePerMillion: 75.0),
    ModelPricing(model: 'claude-3-haiku', inputPricePerMillion: 0.25, outputPricePerMillion: 1.25),
    ModelPricing(model: 'o3-mini', inputPricePerMillion: 1.1, outputPricePerMillion: 4.4),
    ModelPricing(model: 'gpt-4o', inputPricePerMillion: 2.5, outputPricePerMillion: 10.0),
    ModelPricing(model: 'gemini-2.5-pro', inputPricePerMillion: 1.25, outputPricePerMillion: 10.0),
  ];
}
