import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../models/usage_tracker.dart';

/// 用量统计设置页
class UsageSettingsView extends StatefulWidget {
  const UsageSettingsView({super.key});

  @override
  State<UsageSettingsView> createState() => _UsageSettingsViewState();
}

class _UsageSettingsViewState extends State<UsageSettingsView> {
  List<ModelPricing> _pricingList = [];

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      final appState = context.read<AppState>();
      final list = await appState.dbManager.getAllModelPricing();
      if (mounted) setState(() => _pricingList = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final usage = appState.sessionUsage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('本次会话', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 0.5),
          ),
          child: Column(
            children: [
              _UsageRow(label: '请求次数', value: '${usage.requestCount}'),
              const Divider(height: 16),
              _UsageRow(label: '输入 Token', value: UsageSummary.formatTokens(usage.totalInputTokens)),
              const Divider(height: 16),
              _UsageRow(label: '输出 Token', value: UsageSummary.formatTokens(usage.totalOutputTokens)),
              const Divider(height: 16),
              _UsageRow(label: '缓存读取 Token', value: UsageSummary.formatTokens(usage.totalCacheReadTokens)),
              const Divider(height: 16),
              _UsageRow(
                label: '预估费用',
                value: UsageSummary.formatCost(usage.totalCost),
                valueColor: Colors.orange,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => appState.resetUsage(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('重置会话统计'),
        ),

        const SizedBox(height: 32),
        Text('模型定价参考', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 0.5),
          ),
          child: _pricingList.isEmpty
              ? Text('加载中...', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
              : Column(
                  children: _pricingList.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.displayName,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '输入 \$${p.inputCostPerMillion}/M',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '输出 \$${p.outputCostPerMillion}/M',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _UsageRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
