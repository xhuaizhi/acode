import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../models/file_node.dart';
import '../../utils/provider_icon_inference.dart';

/// 左侧文件管理器
class FileExplorerView extends StatefulWidget {
  final String? rootPath;
  final ValueChanged<String>? onFileSelected;
  final ValueChanged<String>? onFolderOpened;

  const FileExplorerView({
    super.key,
    this.rootPath,
    this.onFileSelected,
    this.onFolderOpened,
  });

  @override
  State<FileExplorerView> createState() => _FileExplorerViewState();
}

class _FileExplorerViewState extends State<FileExplorerView> {
  FileNode? _rootNode;

  @override
  void initState() {
    super.initState();
    _loadRoot();
  }

  @override
  void didUpdateWidget(FileExplorerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath != widget.rootPath) {
      _loadRoot();
    }
  }

  void _loadRoot() {
    if (widget.rootPath == null) {
      setState(() => _rootNode = null);
      return;
    }
    final node = FileNode.fromPath(widget.rootPath!);
    node.isExpanded = true;
    node.loadChildren();
    setState(() => _rootNode = node);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF232425) : const Color(0xFFF8F8F8);
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

    return Container(
      color: bgColor,
      child: widget.rootPath == null ? _buildEmptyState() : _buildTree(borderColor),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.create_new_folder_outlined, size: 32, color: Colors.grey[400]),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => widget.onFolderOpened?.call(''),
            child: const Text('打开文件夹', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 4),
          Text('Ctrl+O', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildTree(Color borderColor) {
    return Column(
      children: [
        // 项目名称头部
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.folder, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _rootNode?.name ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: _loadRoot,
                borderRadius: BorderRadius.circular(4),
                child: Icon(Icons.refresh, size: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),

        // 文件树
        Expanded(
          child: _rootNode == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _buildNodeChildren(_rootNode!, 0),
                ),
        ),

        // 底部路径栏
        Divider(height: 1, color: borderColor),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.rootPath ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.rootPath ?? ''));
                },
                child: Icon(Icons.copy, size: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNodeChildren(FileNode node, int depth) {
    final widgets = <Widget>[
      _FileTreeNodeWidget(
        node: node,
        depth: depth,
        rootPath: widget.rootPath,
        onFileSelected: widget.onFileSelected,
        onRefresh: _loadRoot,
      ),
    ];

    if (node.isDirectory && node.isExpanded && node.children != null) {
      for (final child in node.children!) {
        widgets.addAll(_buildNodeChildren(child, depth + 1));
      }
    }

    return widgets;
  }
}

/// 文件树节点 Widget
class _FileTreeNodeWidget extends StatefulWidget {
  final FileNode node;
  final int depth;
  final String? rootPath;
  final ValueChanged<String>? onFileSelected;
  final VoidCallback? onRefresh;

  const _FileTreeNodeWidget({
    required this.node,
    required this.depth,
    this.rootPath,
    this.onFileSelected,
    this.onRefresh,
  });

  @override
  State<_FileTreeNodeWidget> createState() => _FileTreeNodeWidgetState();
}

class _FileTreeNodeWidgetState extends State<_FileTreeNodeWidget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return ListenableBuilder(
      listenable: widget.node,
      builder: (context, _) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: () {
              if (widget.node.isDirectory) {
                widget.node.isExpanded = !widget.node.isExpanded;
                if (widget.node.isExpanded) {
                  widget.node.loadChildren();
                }
              } else {
                widget.onFileSelected?.call(widget.node.path);
              }
            },
            onSecondaryTapUp: (details) {
              _showContextMenu(context, details.globalPosition);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                padding: EdgeInsets.only(
                  left: widget.depth * 18.0 + 8,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                decoration: BoxDecoration(
                  color: _isHovering ? hoverColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                children: [
                  // 展开箭头
                  if (widget.node.isDirectory)
                    SizedBox(
                      width: 14,
                      child: Icon(
                        widget.node.isExpanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                    )
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: 4),

                  // 图标
                  SizedBox(
                    width: 20,
                    child: Icon(
                      _getIcon(),
                      size: 14,
                      color: _getIconColor(),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // 文件名
                  Expanded(
                    child: Text(
                      widget.node.name,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon() {
    if (widget.node.isDirectory) {
      return widget.node.isExpanded ? Icons.folder_open : Icons.folder;
    }
    final iconName = widget.node.iconName;
    switch (iconName) {
      case 'code':
        return Icons.code;
      case 'javascript':
        return Icons.javascript;
      case 'data_object':
        return Icons.data_object;
      case 'description':
        return Icons.description;
      case 'web':
        return Icons.web;
      case 'terminal':
        return Icons.terminal;
      case 'image':
        return Icons.image;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor() {
    if (widget.node.isDirectory) {
      return Colors.grey[500]!;
    }
    final hex = widget.node.iconColorHex;
    if (hex != null) {
      return ProviderIconInference.hexToColor(hex);
    }
    return Colors.grey[500]!;
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final node = widget.node;
    final rootPath = widget.rootPath ?? '';
    final isWindows = Platform.isWindows;
    final items = <PopupMenuEntry<String>>[
      if (!node.isDirectory)
        const PopupMenuItem(value: 'open', child: Text('在编辑器中打开', style: TextStyle(fontSize: 13))),
      const PopupMenuItem(value: 'open_system', child: Text('用系统默认应用打开', style: TextStyle(fontSize: 13))),
      PopupMenuItem(value: 'reveal', child: Text(isWindows ? '在文件资源管理器中显示' : '在 Finder 中显示', style: const TextStyle(fontSize: 13))),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'copy', child: Text('复制', style: TextStyle(fontSize: 13))),
      const PopupMenuItem(value: 'copy_path', child: Text('复制路径', style: TextStyle(fontSize: 13))),
      const PopupMenuItem(value: 'copy_relative', child: Text('复制相对路径', style: TextStyle(fontSize: 13))),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'rename', child: Text('重命名…', style: TextStyle(fontSize: 13))),
      const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(fontSize: 13, color: Colors.red))),
    ];

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: items,
    );
    if (value == null || !mounted) return;
    switch (value) {
      case 'open':
        widget.onFileSelected?.call(node.path);
      case 'open_system':
        if (Platform.isWindows) {
          Process.run('explorer', [node.path]);
        } else if (Platform.isMacOS) {
          Process.run('open', [node.path]);
        }
      case 'reveal':
        if (Platform.isWindows) {
          if (node.isDirectory) {
            Process.run('explorer', [node.path]);
          } else {
            Process.run('explorer', ['/select,', node.path]);
          }
        } else if (Platform.isMacOS) {
          if (node.isDirectory) {
            Process.run('open', [node.path]);
          } else {
            Process.run('open', ['-R', node.path]);
          }
        }
      case 'copy':
        Clipboard.setData(ClipboardData(text: node.path));
      case 'copy_path':
        Clipboard.setData(ClipboardData(text: node.path));
      case 'copy_relative':
        final relative = rootPath.isNotEmpty
            ? node.path.replaceFirst('$rootPath${Platform.pathSeparator}', '')
            : node.path;
        Clipboard.setData(ClipboardData(text: relative));
      case 'rename':
        if (!context.mounted) return;
        _showRenameDialog(context, node);
      case 'delete':
        if (!context.mounted) return;
        _showDeleteDialog(context, node);
    }
  }

  void _showRenameDialog(BuildContext ctx, FileNode node) {
    final controller = TextEditingController(text: node.name);
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '新名称'),
          onSubmitted: (_) => Navigator.pop(context, controller.text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((newName) {
      if (newName == null || newName.trim().isEmpty || newName.trim() == node.name) return;
      try {
        final dir = p.dirname(node.path);
        final newPath = p.join(dir, newName.trim());
        File(node.path).existsSync()
            ? File(node.path).renameSync(newPath)
            : Directory(node.path).renameSync(newPath);
        widget.onRefresh?.call();
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
        }
      }
    });
  }

  Future<void> _showDeleteDialog(BuildContext ctx, FileNode node) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text('删除「${node.name}」？'),
        content: Text(node.isDirectory ? '文件夹及其内容将被移到回收站。' : '文件将被移到回收站。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (Platform.isWindows) {
        // Windows: 使用 PowerShell 移到回收站
        await Process.run('powershell', [
          '-Command',
          'Add-Type -AssemblyName Microsoft.VisualBasic; '
              '[Microsoft.VisualBasic.FileIO.FileSystem]::Delete${node.isDirectory ? "Directory" : "File"}('
              '"${node.path.replaceAll('"', '`"')}", '
              '[Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, '
              '[Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)'
        ]);
      } else if (Platform.isMacOS) {
        // macOS: 使用 osascript 移到废纸篓
        await Process.run('osascript', [
          '-e', 'tell application "Finder" to delete POSIX file "${node.path}"'
        ]);
      } else {
        if (node.isDirectory) {
          Directory(node.path).deleteSync(recursive: true);
        } else {
          File(node.path).deleteSync();
        }
      }
      widget.onRefresh?.call();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }
}
