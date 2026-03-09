import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../models/usage_tracker.dart';

/// 用量统计设置页
class UsageSettingsView extends StatelessWidget {
  const UsageSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final usage = appState.sessionUsage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('本次会话', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
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
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: ModelPricing.defaults.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.model,
                        style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                      ),
                    ),
                    Text(
                      '输入 \$${p.inputPricePerMillion}/M',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '输出 \$${p.outputPricePerMillion}/M',
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
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Consolas',
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
