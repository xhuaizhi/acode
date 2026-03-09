import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../../app/app_state.dart';
import '../../models/split_node.dart';

/// 终端面板视图（含标签栏和终端）
class TerminalPanelView extends StatelessWidget {
  final TerminalTab tab;
  final bool isFocused;
  final bool canClose;
  final VoidCallback onClose;
  final VoidCallback onFocus;

  const TerminalPanelView({
    super.key,
    required this.tab,
    required this.isFocused,
    required this.canClose,
    required this.onClose,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

    return GestureDetector(
      onTap: onFocus,
      child: Column(
        children: [
          // 分屏时显示标签栏
          if (canClose)
            _TabHeader(
              title: tab.title,
              isFocused: isFocused,
              onClose: onClose,
              borderColor: borderColor,
              isDark: isDark,
            ),
          // 终端视图
          Expanded(
            child: Container(
              decoration: canClose && isFocused
                  ? BoxDecoration(
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.8),
                        width: 1,
                      ),
                    )
                  : null,
              child: TerminalWidget(
                key: ValueKey(tab.id),
                tabId: tab.id,
                workingDirectory: tab.workingDirectory,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabHeader extends StatefulWidget {
  final String title;
  final bool isFocused;
  final VoidCallback onClose;
  final Color borderColor;
  final bool isDark;

  const _TabHeader({
    required this.title,
    required this.isFocused,
    required this.onClose,
    required this.borderColor,
    required this.isDark,
  });

  @override
  State<_TabHeader> createState() => _TabHeaderState();
}

class _TabHeaderState extends State<_TabHeader> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF252526) : const Color(0xFFF3F3F3),
          border: Border(bottom: BorderSide(color: widget.borderColor, width: 1)),
        ),
        child: Row(
          children: [
            Icon(Icons.terminal, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              widget.title,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const Spacer(),
            if (_isHovering)
              InkWell(
                onTap: widget.onClose,
                child: Text(
                  '关闭',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// xterm + flutter_pty 终端组件
class TerminalWidget extends StatefulWidget {
  final String tabId;
  final String? workingDirectory;

  const TerminalWidget({super.key, required this.tabId, this.workingDirectory});

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> with AutomaticKeepAliveClientMixin {
  late final Terminal _terminal;
  Pty? _pty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _startPty();
  }

  Future<void> _startPty() async {
    final appState = context.read<AppState>();
    final providerEnv = await appState.providerService.getAllProviderEnv();

    // 合并系统环境变量
    final env = Map<String, String>.from(Platform.environment);
    env.addAll(providerEnv);
    env['TERM'] = 'xterm-256color';
    env['COLORTERM'] = 'truecolor';
    env.putIfAbsent('LANG', () => 'en_US.UTF-8');

    // Windows 使用 powershell 或 cmd
    final shell = Platform.isWindows
        ? (env['COMSPEC'] ?? 'C:\\Windows\\System32\\cmd.exe')
        : (env['SHELL'] ?? '/bin/bash');

    // 工作目录
    String? cwd = widget.workingDirectory;
    if (cwd != null && cwd.isNotEmpty && !Directory(cwd).existsSync()) {
      cwd = null;
    }

    try {
      _pty = Pty.start(
        shell,
        arguments: Platform.isWindows ? [] : ['--login'],
        environment: env,
        workingDirectory: cwd,
      );

      // PTY 输出 → Terminal
      _pty!.output.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      // Terminal 输入 → PTY
      _terminal.onOutput = (data) {
        _pty?.write(utf8.encode(data));
      };

      // Terminal 窗口大小变化 → PTY
      _terminal.onResize = (w, h, pw, ph) {
        _pty?.resize(h, w);
      };
    } catch (e) {
      _terminal.write('终端启动失败: $e\r\n');
    }
  }

  @override
  void dispose() {
    _pty?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final termTheme = isDark
        ? TerminalTheme(
            cursor: const Color(0xFFD4D4D4),
            selection: const Color(0x80FFFFFF),
            foreground: const Color(0xFFD4D4D4),
            background: const Color(0xFF1C1E21),
            black: const Color(0xFF1D1F21),
            red: const Color(0xFFCC6666),
            green: const Color(0xFFB5BD68),
            yellow: const Color(0xFFF0C674),
            blue: const Color(0xFF81A2BE),
            magenta: const Color(0xFFB294BB),
            cyan: const Color(0xFF8ABEB7),
            white: const Color(0xFFC5C8C6),
            brightBlack: const Color(0xFF969896),
            brightRed: const Color(0xFFFF3334),
            brightGreen: const Color(0xFF9EC400),
            brightYellow: const Color(0xFFE7C547),
            brightBlue: const Color(0xFF7AA6DA),
            brightMagenta: const Color(0xFFB77EE0),
            brightCyan: const Color(0xFF54CED6),
            brightWhite: const Color(0xFFFFFFFF),
            searchHitBackground: const Color(0x80FFFF00),
            searchHitBackgroundCurrent: const Color(0xFFFF6600),
            searchHitForeground: const Color(0xFF000000),
          )
        : TerminalTheme(
            cursor: const Color(0xFF000000),
            selection: const Color(0x40000000),
            foreground: const Color(0xFF000000),
            background: const Color(0xFFFFFFFF),
            black: const Color(0xFF000000),
            red: const Color(0xFFC91B00),
            green: const Color(0xFF00C200),
            yellow: const Color(0xFFC7C400),
            blue: const Color(0xFF0025C7),
            magenta: const Color(0xFFC930C7),
            cyan: const Color(0xFF00C5C7),
            white: const Color(0xFFC7C7C7),
            brightBlack: const Color(0xFF686868),
            brightRed: const Color(0xFFFF6E67),
            brightGreen: const Color(0xFF5FF967),
            brightYellow: const Color(0xFFFEFB67),
            brightBlue: const Color(0xFF6871FF),
            brightMagenta: const Color(0xFFFF76FF),
            brightCyan: const Color(0xFF5FFDFF),
            brightWhite: const Color(0xFFFFFFFF),
            searchHitBackground: const Color(0x80FFFF00),
            searchHitBackgroundCurrent: const Color(0xFFFF6600),
            searchHitForeground: const Color(0xFF000000),
          );

    return Container(
      color: termTheme.background,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: TerminalView(
        _terminal,
        theme: termTheme,
        textStyle: const TerminalStyle(
          fontSize: 14,
          fontFamily: 'Cascadia Code, Consolas, Courier New, monospace',
        ),
      ),
    );
  }
}
