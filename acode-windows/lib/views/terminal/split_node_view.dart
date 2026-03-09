import 'package:flutter/material.dart';

import '../../models/split_node.dart';
import 'terminal_panel_view.dart';

/// 递归渲染分屏树
class SplitNodeView extends StatelessWidget {
  final SplitNode node;
  final String? focusedTabId;
  final int totalTabCount;
  final ValueChanged<String>? onFocus;
  final ValueChanged<String>? onCloseTab;

  const SplitNodeView({
    super.key,
    required this.node,
    this.focusedTabId,
    this.totalTabCount = 1,
    this.onFocus,
    this.onCloseTab,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        switch (node.type) {
          case TerminalLeaf(:final tab):
            return TerminalPanelView(
              tab: tab,
              isFocused: focusedTabId == tab.id,
              canClose: totalTabCount > 1,
              onClose: () => onCloseTab?.call(tab.id),
              onFocus: () => onFocus?.call(tab.id),
            );

          case SplitContainer(:final direction, :final first, :final second):
            if (direction == SplitDirection.horizontal) {
              return _HorizontalSplitPane(
                ratio: node.splitRatio,
                onRatioChanged: (r) => node.updateSplitRatio(r),
                first: SplitNodeView(
                  node: first,
                  focusedTabId: focusedTabId,
                  totalTabCount: totalTabCount,
                  onFocus: onFocus,
                  onCloseTab: onCloseTab,
                ),
                second: SplitNodeView(
                  node: second,
                  focusedTabId: focusedTabId,
                  totalTabCount: totalTabCount,
                  onFocus: onFocus,
                  onCloseTab: onCloseTab,
                ),
              );
            } else {
              return _VerticalSplitPane(
                ratio: node.splitRatio,
                onRatioChanged: (r) => node.updateSplitRatio(r),
                first: SplitNodeView(
                  node: first,
                  focusedTabId: focusedTabId,
                  totalTabCount: totalTabCount,
                  onFocus: onFocus,
                  onCloseTab: onCloseTab,
                ),
                second: SplitNodeView(
                  node: second,
                  focusedTabId: focusedTabId,
                  totalTabCount: totalTabCount,
                  onFocus: onFocus,
                  onCloseTab: onCloseTab,
                ),
              );
            }
        }
      },
    );
  }
}

/// 水平分屏（左右）
class _HorizontalSplitPane extends StatefulWidget {
  final double ratio;
  final ValueChanged<double> onRatioChanged;
  final Widget first;
  final Widget second;

  const _HorizontalSplitPane({
    required this.ratio,
    required this.onRatioChanged,
    required this.first,
    required this.second,
  });

  @override
  State<_HorizontalSplitPane> createState() => _HorizontalSplitPaneState();
}

class _HorizontalSplitPaneState extends State<_HorizontalSplitPane> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = _isDragging
        ? Colors.white.withValues(alpha: 0.4)
        : (isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final firstWidth = (totalWidth * widget.ratio).clamp(80.0, totalWidth - 80.0);
        final secondWidth = totalWidth - firstWidth - 1;

        return Row(
          children: [
            SizedBox(width: firstWidth, child: widget.first),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                onHorizontalDragUpdate: (details) {
                  if (totalWidth > 1) {
                    final newRatio = (firstWidth + details.delta.dx) / totalWidth;
                    widget.onRatioChanged(newRatio);
                  }
                },
                onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                child: Container(
                  width: 5,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(width: 1, color: dividerColor),
                  ),
                ),
              ),
            ),
            SizedBox(width: secondWidth.clamp(0.0, double.infinity), child: widget.second),
          ],
        );
      },
    );
  }
}

/// 垂直分屏（上下）
class _VerticalSplitPane extends StatefulWidget {
  final double ratio;
  final ValueChanged<double> onRatioChanged;
  final Widget first;
  final Widget second;

  const _VerticalSplitPane({
    required this.ratio,
    required this.onRatioChanged,
    required this.first,
    required this.second,
  });

  @override
  State<_VerticalSplitPane> createState() => _VerticalSplitPaneState();
}

class _VerticalSplitPaneState extends State<_VerticalSplitPane> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = _isDragging
        ? Colors.white.withValues(alpha: 0.4)
        : (isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final firstHeight = (totalHeight * widget.ratio).clamp(60.0, totalHeight - 60.0);
        final secondHeight = totalHeight - firstHeight - 1;

        return Column(
          children: [
            SizedBox(height: firstHeight, child: widget.first),
            MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (_) => setState(() => _isDragging = true),
                onVerticalDragUpdate: (details) {
                  if (totalHeight > 1) {
                    final newRatio = (firstHeight + details.delta.dy) / totalHeight;
                    widget.onRatioChanged(newRatio);
                  }
                },
                onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                child: Container(
                  height: 5,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(height: 1, color: dividerColor),
                  ),
                ),
              ),
            ),
            SizedBox(height: secondHeight.clamp(0.0, double.infinity), child: widget.second),
          ],
        );
      },
    );
  }
}
