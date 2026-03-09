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
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final sidebarBg = isDark ? const Color(0xFF252526) : const Color(0xFFF8F8F8);
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
                width: 190,
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
                    InkWell(
                      onTap: widget.onClose,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.chevron_left, size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '返回应用程序',
                              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Text(
                        _selectedTab.label,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Divider(height: 1, color: borderColor),
                    // 内容
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
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

/// 侧栏菜单项
class _SidebarItem extends StatelessWidget {
  final SettingsTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? const Color(0xFF37373D) : const Color(0xFFE8E8E8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: Icon(
                  _iconForTab(tab),
                  size: 12,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : Colors.grey[500],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
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
