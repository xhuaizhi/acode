import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../models/usage_tracker.dart';
import '../../utils/provider_icon_inference.dart';

/// 底部状态栏
class StatusBarView extends StatefulWidget {
  const StatusBarView({super.key});

  @override
  State<StatusBarView> createState() => _StatusBarViewState();
}

class _StatusBarViewState extends State<StatusBarView> {
  String? _visibleMessage;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF232425) : const Color(0xFFF8F8F8);
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

    // 监听状态消息变化
    if (appState.statusMessage.isNotEmpty && appState.statusMessage != _visibleMessage) {
      _visibleMessage = appState.statusMessage;
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _visibleMessage = null);
      });
    }

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // 设置按钮
          InkWell(
            onTap: () => appState.toggleSettings(),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.settings, size: 14, color: Colors.grey[500]),
            ),
          ),
          const SizedBox(width: 6),

          // 终端数量
          Icon(Icons.terminal, size: 9, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            '${appState.terminalCount} 个终端',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),

          // 临时状态消息
          if (_visibleMessage != null) ...[
            const SizedBox(width: 8),
            Text(
              _visibleMessage!,
              style: const TextStyle(fontSize: 10, color: Colors.orange),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // 当前文件信息
          if (appState.activeFilePath != null) ...[
            const SizedBox(width: 8),
            Text(
              p.basename(appState.activeFilePath!),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
          if (appState.activeFileLineCount != null) ...[
            const SizedBox(width: 6),
            Text(
              '${appState.activeFileLineCount} 行',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
          if (appState.activeFileModDate != null) ...[
            const SizedBox(width: 6),
            Text(
              _formatDate(appState.activeFileModDate!),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],

          // Provider 指示器
          const SizedBox(width: 8),
          ...['claude_code', 'openai', 'gemini'].map((tool) {
            final provider = appState.activeProviders[tool];
            if (provider == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _ProviderIndicator(
                name: provider.name,
                model: provider.model,
                color: ProviderIconInference.inferColor(
                  provider.name,
                  iconColor: provider.iconColor,
                ),
              ),
            );
          }),

          const Spacer(),

          // Token 用量（点击弹出详细用量）
          _TokenUsageIndicator(usage: appState.sessionUsage),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

/// Provider 指示器
class _ProviderIndicator extends StatelessWidget {
  final String name;
  final String model;
  final Color color;

  const _ProviderIndicator({
    required this.name,
    required this.model,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2B2D) : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(name, style: const TextStyle(fontSize: 11)),
          if (model.isNotEmpty) ...[
            Text(' · ', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            Text(model, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ],
      ),
    );
  }
}

/// Token 用量指示器（含 Popover）
class _TokenUsageIndicator extends StatefulWidget {
  final UsageSummary usage;

  const _TokenUsageIndicator({required this.usage});

  @override
  State<_TokenUsageIndicator> createState() => _TokenUsageIndicatorState();
}

class _TokenUsageIndicatorState extends State<_TokenUsageIndicator> {
  final _popoverKey = GlobalKey();

  void _showPopover() {
    final renderBox = _popoverKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Stack(
          children: [
            Positioned(
              left: offset.dx - 80,
              top: offset.dy - 200,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('本次会话用量', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _popoverRow('输入 Token', UsageSummary.formatTokens(widget.usage.totalInputTokens)),
                      const SizedBox(height: 6),
                      _popoverRow('输出 Token', UsageSummary.formatTokens(widget.usage.totalOutputTokens)),
                      const SizedBox(height: 6),
                      _popoverRow('缓存读取', UsageSummary.formatTokens(widget.usage.totalCacheReadTokens)),
                      const Divider(height: 16),
                      _popoverRow('请求次数', '${widget.usage.requestCount}'),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('预估费用', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          Text(
                            UsageSummary.formatCost(widget.usage.totalCost),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _popoverRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showPopover(),
      child: GestureDetector(
        key: _popoverKey,
        onTap: _showPopover,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '输入 ${UsageSummary.formatTokens(widget.usage.totalInputTokens)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            const SizedBox(width: 8),
            Text(
              '输出 ${UsageSummary.formatTokens(widget.usage.totalOutputTokens)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            const SizedBox(width: 8),
            Text(
              UsageSummary.formatCost(widget.usage.totalCost),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
