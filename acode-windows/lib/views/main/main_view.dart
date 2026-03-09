import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../app/app_state.dart';
import '../../models/split_node.dart';
import '../terminal/split_node_view.dart';
import '../file_explorer/file_explorer_view.dart';
import '../file_explorer/editor_tab_bar.dart';
import '../file_explorer/file_editor_view.dart';
import '../settings/inline_settings_view.dart';
import '../components/status_bar_view.dart';
import '../components/update_toast_view.dart';

/// 主窗口视图
class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  late SplitNode _rootNode;
  String? _focusedTabId;
  String? _projectPath;
  bool _showSidebar = true;
  bool _showTerminal = true;
  final List<String> _openedFiles = [];
  int? _activeFileIndex;
  bool _showUpdateToast = false;

  @override
  void initState() {
    super.initState();
    _rootNode = SplitNode.terminal(TerminalTab());
    _focusedTabId = _rootNode.allTabs.first.id;
    _restoreState();
    _checkForUpdates();
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();

    // 检查更新后重启标记
    final updatedVer = prefs.getString('lastUpdatedVersion');
    if (updatedVer != null && updatedVer.isNotEmpty) {
      await prefs.remove('lastUpdatedVersion');
      try {
        await launchUrl(Uri.parse('https://acode.anna.tf/versions'));
      } catch (_) {}
    }

    // 恢复上次项目路径
    final savedPath = prefs.getString('lastProjectPath');
    if (savedPath != null && savedPath.isNotEmpty && Directory(savedPath).existsSync()) {
      setState(() => _projectPath = savedPath);
    }

    // 恢复终端数量
    final savedCount = prefs.getInt('lastTerminalCount') ?? 1;
    if (savedCount > 1) {
      _rootNode.restoreTerminals(savedCount);
      setState(() {
        _focusedTabId = _rootNode.allTabs.first.id;
      });
      if (mounted) {
        final appState = context.read<AppState>();
        appState.setTerminalCount(_rootNode.allTabs.length);
      }
    }
  }

  Future<void> _checkForUpdates() async {
    final appState = context.read<AppState>();
    await appState.updateChecker.checkForUpdates();
    if (appState.updateChecker.hasUpdate && mounted) {
      setState(() => _showUpdateToast = true);
      await appState.updateChecker.downloadUpdate();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): _addNewTab,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _openFolderDialog,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _splitVertical,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true): _splitHorizontal,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          appState.toggleSettings();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (appState.showSettings) {
            appState.toggleSettings();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Column(
              children: [
                // 工具栏
                _buildToolbar(appState, borderColor),
                // 主内容区
                Expanded(
                  child: Row(
                    children: [
                      // 左侧文件浏览器
                      if (_showSidebar) ...[
                        SizedBox(
                          width: 220,
                          child: FileExplorerView(
                            rootPath: _projectPath,
                            onFileSelected: _openFile,
                            onFolderOpened: (path) {
                              if (path.isEmpty) {
                                _openFolderDialog();
                              } else {
                                _switchProject(path);
                              }
                            },
                          ),
                        ),
                        Container(width: 1, color: borderColor),
                      ],

                      // 中间编辑器
                      if (_openedFiles.isNotEmpty) ...[
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              EditorTabBar(
                                files: _openedFiles,
                                activeIndex: _activeFileIndex,
                                onSelect: (idx) => setState(() {
                                  _activeFileIndex = idx;
                                  _updateActiveFileInfo();
                                }),
                                onClose: _closeFile,
                                onCloseAll: _closeAllFiles,
                              ),
                              Expanded(
                                child: _activeFileIndex != null &&
                                        _activeFileIndex! < _openedFiles.length
                                    ? FileEditorView(
                                        key: ValueKey(_openedFiles[_activeFileIndex!]),
                                        filePath: _openedFiles[_activeFileIndex!],
                                      )
                                    : Container(color: bgColor),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, color: borderColor),
                      ],

                      // 右侧终端
                      if (_showTerminal)
                        Expanded(
                          flex: 3,
                          child: SplitNodeView(
                            node: _rootNode,
                            focusedTabId: _focusedTabId,
                            totalTabCount: _rootNode.allTabs.length,
                            onFocus: (tabId) => setState(() => _focusedTabId = tabId),
                            onCloseTab: _closePanel,
                          ),
                        ),
                    ],
                  ),
                ),
                // 状态栏
                const StatusBarView(),
              ],
            ),

            // 设置覆盖层
            if (appState.showSettings)
              InlineSettingsView(
                onClose: () {
                  appState.toggleSettings();
                },
              ),

            // 更新 Toast
            if (_showUpdateToast && appState.updateChecker.latestVersion != null)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: UpdateToastView(
                      version: appState.updateChecker.latestVersion!,
                      notes: appState.updateChecker.isDownloading
                          ? '正在下载更新...'
                          : (appState.updateChecker.isDownloaded
                              ? '更新已就绪，点击重启应用'
                              : appState.updateChecker.releaseNotes),
                      isDownloaded: appState.updateChecker.isDownloaded,
                      isDownloading: appState.updateChecker.isDownloading,
                      onUpdate: () {
                        if (appState.updateChecker.isDownloaded) {
                          appState.updateChecker.installAndRestart();
                        }
                      },
                      onDismiss: () => setState(() => _showUpdateToast = false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(AppState appState, Color borderColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252526) : const Color(0xFFF3F3F3),
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.folder_open,
            tooltip: '打开文件夹 (Ctrl+O)',
            onPressed: _openFolderDialog,
          ),
          _ToolbarButton(
            icon: Icons.vertical_split,
            tooltip: _showSidebar ? '隐藏侧栏' : '显示侧栏',
            onPressed: () => setState(() => _showSidebar = !_showSidebar),
          ),
          _ToolbarButton(
            icon: Icons.terminal,
            tooltip: _showTerminal ? '隐藏终端' : '显示终端',
            onPressed: () => setState(() => _showTerminal = !_showTerminal),
          ),
          const Spacer(),
          _ToolbarButton(
            icon: Icons.splitscreen,
            tooltip: '垂直分屏 (Ctrl+D)',
            onPressed: _splitVertical,
          ),
          _ToolbarButton(
            icon: Icons.view_column,
            tooltip: '水平分屏 (Ctrl+Shift+D)',
            onPressed: _splitHorizontal,
          ),
          _ToolbarButton(
            icon: Icons.add,
            tooltip: '新建终端 (Ctrl+T)',
            onPressed: _addNewTab,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ==================== File Management ====================

  void _openFile(String filePath) {
    final existingIdx = _openedFiles.indexOf(filePath);
    if (existingIdx >= 0) {
      setState(() => _activeFileIndex = existingIdx);
    } else {
      setState(() {
        _openedFiles.add(filePath);
        _activeFileIndex = _openedFiles.length - 1;
      });
    }
    _updateActiveFileInfo();
  }

  void _closeFile(int index) {
    if (index >= _openedFiles.length) return;
    final wasActive = _activeFileIndex == index;
    setState(() {
      _openedFiles.removeAt(index);
      if (_openedFiles.isEmpty) {
        _activeFileIndex = null;
      } else if (wasActive) {
        _activeFileIndex = index.clamp(0, _openedFiles.length - 1);
      } else if (_activeFileIndex != null && _activeFileIndex! > index) {
        _activeFileIndex = _activeFileIndex! - 1;
      }
    });
    _updateActiveFileInfo();
  }

  void _closeAllFiles() {
    setState(() {
      _openedFiles.clear();
      _activeFileIndex = null;
    });
    _updateActiveFileInfo();
  }

  void _updateActiveFileInfo() {
    final appState = context.read<AppState>();
    if (_activeFileIndex == null || _activeFileIndex! >= _openedFiles.length) {
      appState.setActiveFile();
      return;
    }
    final filePath = _openedFiles[_activeFileIndex!];
    appState.setActiveFile(path: filePath);

    // 异步读取文件行数和修改日期
    Future(() async {
      int? lineCount;
      DateTime? modDate;
      try {
        final file = File(filePath);
        final stat = await file.stat();
        modDate = stat.modified;
        final text = await file.readAsString();
        lineCount = text.split('\n').length;
      } catch (_) {}

      if (mounted && appState.activeFilePath == filePath) {
        appState.setActiveFile(path: filePath, lineCount: lineCount, modDate: modDate);
      }
    });
  }

  void _switchProject(String path) {
    _closeAllFiles();
    setState(() => _projectPath = path);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('lastProjectPath', path);
    });
  }

  Future<void> _openFolderDialog() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; '
            '\$dialog = New-Object System.Windows.Forms.FolderBrowserDialog; '
            '\$dialog.Description = "选择要打开的项目文件夹"; '
            'if (\$dialog.ShowDialog() -eq "OK") { Write-Output \$dialog.SelectedPath }'
      ]);
      final path = (result.stdout as String).trim();
      if (path.isNotEmpty && Directory(path).existsSync()) {
        _switchProject(path);
      }
    } catch (e) {
      debugPrint('打开文件夹对话框失败: $e');
    }
  }

  // ==================== Terminal Management ====================

  void _addNewTab() {
    if (_focusedTabId != null) {
      _rootNode.splitTerminal(_focusedTabId!, SplitDirection.horizontal, workingDirectory: _projectPath);
      final newTab = _rootNode.allTabs.last;
      setState(() => _focusedTabId = newTab.id);
      _saveTerminalCount();
    }
  }

  void _splitHorizontal() {
    if (_focusedTabId != null) {
      _rootNode.splitTerminal(_focusedTabId!, SplitDirection.horizontal, workingDirectory: _projectPath);
      final newTab = _rootNode.allTabs.last;
      setState(() => _focusedTabId = newTab.id);
      _saveTerminalCount();
    }
  }

  void _splitVertical() {
    if (_focusedTabId != null) {
      _rootNode.splitTerminal(_focusedTabId!, SplitDirection.vertical, workingDirectory: _projectPath);
      final newTab = _rootNode.allTabs.last;
      setState(() => _focusedTabId = newTab.id);
      _saveTerminalCount();
    }
  }

  void _closePanel(String tabId) {
    final allTabs = _rootNode.allTabs;
    if (allTabs.length <= 1) return;

    final previousFocused = _focusedTabId;
    _rootNode.closeTerminal(tabId);

    final remaining = _rootNode.allTabs;
    setState(() {
      if (previousFocused != null &&
          previousFocused != tabId &&
          remaining.any((t) => t.id == previousFocused)) {
        _focusedTabId = previousFocused;
      } else {
        _focusedTabId = remaining.first.id;
      }
    });
    _saveTerminalCount();
  }

  void _saveTerminalCount() {
    final count = _rootNode.allTabs.length;
    context.read<AppState>().setTerminalCount(count);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('lastTerminalCount', count);
    });
  }
}

/// 工具栏按钮
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }
}
