import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import 'general_settings_view.dart';
import 'provider_settings_view.dart';
import 'mcp_settings_view.dart';
import 'skills_settings_view.dart';
import 'usage_settings_view.dart';
import 'about_settings_view.dart';

/// 内嵌式设置页面 — 覆盖在主窗口内，类似 Cursor IDE 风格
class InlineSettingsView extends StatefulWidget {
  final VoidCallback onClose;

  const InlineSettingsView({super.key, required this.onClose});

  @override
  State<InlineSettingsView> createState() => _InlineSettingsViewState();
}

class _InlineSettingsViewState extends State<InlineSettingsView> {
  SettingsTab _selectedTab = SettingsTab.general;

  static const _groupOrder = ['基础', '服务商', '工具', '高级', '其他'];

  List<(String, List<SettingsTab>)> get _groupedTabs {
    final groups = <String, List<SettingsTab>>{};
    for (final tab in SettingsTab.values) {
      groups.putIfAbsent(tab.group, () => []).add(tab);
    }
    return _groupOrder
        .where((g) => groups.containsKey(g))
        .map((g) => (g, groups[g]!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final sidebarBg = isDark ? const Color(0xFF232425) : const Color(0xFFF8F8F8);
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: bgColor,
          child: Row(
            children: [
              // 左侧菜单
              Container(
                width: 200,
                color: sidebarBg,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (group, tabs) in _groupedTabs) ...[
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 16,
                                  top: group == _groupedTabs.first.$1 ? 4 : 20,
                                  bottom: 4,
                                ),
                                child: Text(
                                  group.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500]?.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              for (final tab in tabs)
                                _SidebarItem(
                                  tab: tab,
                                  isSelected: _selectedTab == tab,
                                  onTap: () => setState(() => _selectedTab = tab),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: borderColor),
                    // 底部返回按钮
                    _SettingsBackButton(onTap: widget.onClose),
                  ],
                ),
              ),
              // 分隔线
              Container(width: 1, color: borderColor),
              // 右侧内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 14),
                      child: Text(
                        _selectedTab.label,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Divider(height: 1, color: borderColor),
                    // 内容
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: _buildContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case SettingsTab.general:
        return const GeneralSettingsView();
      case SettingsTab.claude:
        return const ProviderSettingsView(tool: 'claude_code', toolName: 'Claude Code');
      case SettingsTab.openai:
        return const ProviderSettingsView(tool: 'openai', toolName: 'OpenAI Codex');
      case SettingsTab.gemini:
        return const ProviderSettingsView(tool: 'gemini', toolName: 'Gemini CLI');
      case SettingsTab.mcp:
        return const MCPSettingsView();
      case SettingsTab.skills:
        return const SkillsSettingsView();
      case SettingsTab.usage:
        return const UsageSettingsView();
      case SettingsTab.about:
        return const AboutSettingsView();
    }
  }
}

/// 侧栏菜单项（带 Hover 效果）
class _SidebarItem extends StatefulWidget {
  final SettingsTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? const Color(0xFF37373D) : const Color(0xFFE8E8E8);
    final hoverBg = isDark
        ? const Color(0xFF37373D).withValues(alpha: 0.5)
        : const Color(0xFFE8E8E8).withValues(alpha: 0.5);

    Color bgColor;
    if (widget.isSelected) {
      bgColor = selectedBg;
    } else if (_isHovering) {
      bgColor = hoverBg;
    } else {
      bgColor = Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(
                    _iconForTab(widget.tab),
                    size: 13,
                    color: widget.isSelected
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.grey[500],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.tab.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isSelected
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForTab(SettingsTab tab) {
    switch (tab) {
      case SettingsTab.general:
        return Icons.settings;
      case SettingsTab.claude:
        return Icons.auto_awesome;
      case SettingsTab.openai:
        return Icons.psychology;
      case SettingsTab.gemini:
        return Icons.diamond;
      case SettingsTab.mcp:
        return Icons.dns;
      case SettingsTab.skills:
        return Icons.star;
      case SettingsTab.usage:
        return Icons.bar_chart;
      case SettingsTab.about:
        return Icons.info;
    }
  }
}

/// 返回按钮（带 Hover 效果）
class _SettingsBackButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SettingsBackButton({required this.onTap});

  @override
  State<_SettingsBackButton> createState() => _SettingsBackButtonState();
}

class _SettingsBackButtonState extends State<_SettingsBackButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _isHovering
        ? (isDark ? Colors.white : Colors.black87)
        : Colors.grey[500]!;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.transparent,
          child: Row(
            children: [
              Icon(Icons.chevron_left, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                '返回应用程序',
                style: TextStyle(fontSize: 14, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
