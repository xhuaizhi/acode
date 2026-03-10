import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_state.dart';

/// 常规设置页
class GeneralSettingsView extends StatefulWidget {
  const GeneralSettingsView({super.key});

  @override
  State<GeneralSettingsView> createState() => _GeneralSettingsViewState();
}

class _GeneralSettingsViewState extends State<GeneralSettingsView> {
  String _theme = 'dark';
  double _terminalFontSize = 14;
  double _editorFontSize = 13;
  String _defaultShell = 'C:\\Windows\\System32\\cmd.exe';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _theme = prefs.getString('theme') ?? 'dark';
      _terminalFontSize = prefs.getDouble('fontSize') ?? 14;
      _editorFontSize = prefs.getDouble('editorFontSize') ?? 13;
      _defaultShell = prefs.getString('defaultShell') ?? 'C:\\Windows\\System32\\cmd.exe';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: '外观'),
        const SizedBox(height: 8),
        _SettingCard(
          borderColor: borderColor,
          children: [
            _DropdownSetting(
              label: '主题',
              value: _theme,
              items: const {
                'system': '跟随系统',
                'light': '浅色',
                'dark': '深色',
              },
              onChanged: (v) {
                setState(() => _theme = v);
                _saveSetting('theme', v);
                context.read<AppState>().setThemeMode(v);
              },
            ),
            const Divider(height: 1),
            _SliderSetting(
              label: '终端字体大小',
              value: _terminalFontSize,
              min: 10,
              max: 24,
              onChanged: (v) {
                setState(() => _terminalFontSize = v);
                _saveSetting('fontSize', v);
              },
            ),
            const Divider(height: 1),
            _SliderSetting(
              label: '编辑器字体大小',
              value: _editorFontSize,
              min: 10,
              max: 28,
              onChanged: (v) {
                setState(() => _editorFontSize = v);
                _saveSetting('editorFontSize', v);
              },
            ),
          ],
        ),

        const SizedBox(height: 24),
        _SectionHeader(title: '终端'),
        const SizedBox(height: 8),
        _SettingCard(
          borderColor: borderColor,
          children: [
            _TextFieldSetting(
              label: '默认 Shell',
              value: _defaultShell,
              onChanged: (v) {
                setState(() => _defaultShell = v);
                _saveSetting('defaultShell', v);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Color borderColor;
  final List<Widget> children;

  const _SettingCard({required this.borderColor, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _DropdownSetting extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _DropdownSetting({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: items.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14))))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              onChanged: (v) => onChanged(v.roundToDouble()),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${value.toInt()}pt',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextFieldSetting extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _TextFieldSetting({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
              onSubmitted: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
