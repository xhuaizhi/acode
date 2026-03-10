import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../utils/provider_icon_inference.dart';

/// 编辑器标签栏
class EditorTabBar extends StatelessWidget {
  final List<String> files;
  final int? activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onCloseAll;

  const EditorTabBar({
    super.key,
    required this.files,
    this.activeIndex,
    required this.onSelect,
    required this.onClose,
    required this.onCloseAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF232425) : const Color(0xFFF8F8F8);
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              itemBuilder: (context, index) {
                return _EditorTab(
                  fileName: p.basename(files[index]),
                  ext: p.extension(files[index]).replaceFirst('.', ''),
                  isActive: activeIndex == index,
                  onSelect: () => onSelect(index),
                  onClose: () => onClose(index),
                );
              },
            ),
          ),
          if (files.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 14, color: Colors.grey[500]),
              padding: EdgeInsets.zero,
              iconSize: 14,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'close_all', child: Text('关闭所有文件')),
              ],
              onSelected: (value) {
                if (value == 'close_all') onCloseAll();
              },
            ),
        ],
      ),
    );
  }
}

/// 单个编辑器标签
class _EditorTab extends StatefulWidget {
  final String fileName;
  final String ext;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const _EditorTab({
    required this.fileName,
    required this.ext,
    required this.isActive,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<_EditorTab> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isActive ? activeBg : (_isHovering ? hoverBg : Colors.transparent),
            border: Border(
              right: BorderSide(
                color: isDark
                    ? const Color(0xFF3C3C3C).withValues(alpha: 0.2)
                    : const Color(0xFFE0E0E0).withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconForExt(widget.ext),
                size: 10,
                color: _colorForExt(widget.ext),
              ),
              const SizedBox(width: 4),
              Text(
                widget.fileName,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isActive
                      ? (isDark ? Colors.white : Colors.black87)
                      : Colors.grey[500],
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onClose,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: Icon(
                    Icons.close,
                    size: 9,
                    color: (_isHovering || widget.isActive)
                        ? Colors.grey[500]
                        : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'dart':
      case 'swift':
      case 'py':
      case 'rs':
        return Icons.code;
      case 'js':
      case 'ts':
      case 'jsx':
      case 'tsx':
        return Icons.javascript;
      case 'json':
        return Icons.data_object;
      case 'md':
      case 'txt':
        return Icons.description;
      case 'html':
      case 'css':
        return Icons.web;
      case 'sh':
      case 'bash':
      case 'zsh':
        return Icons.terminal;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _colorForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'dart':
        return ProviderIconInference.hexToColor('#00B4AB');
      case 'swift':
        return ProviderIconInference.hexToColor('#F05138');
      case 'js':
      case 'jsx':
        return ProviderIconInference.hexToColor('#F7DF1E');
      case 'ts':
      case 'tsx':
        return ProviderIconInference.hexToColor('#3178C6');
      case 'py':
        return ProviderIconInference.hexToColor('#3776AB');
      case 'rs':
        return ProviderIconInference.hexToColor('#DEA584');
      case 'html':
        return ProviderIconInference.hexToColor('#E34F26');
      case 'css':
        return ProviderIconInference.hexToColor('#1572B6');
      default:
        return Colors.grey;
    }
  }
}
