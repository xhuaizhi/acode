import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// 文件树节点模型
class FileNode extends ChangeNotifier {
  final String path;
  final String name;
  final bool isDirectory;
  List<FileNode>? children;
  bool _isExpanded = false;

  FileNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.children,
  });

  bool get isExpanded => _isExpanded;
  set isExpanded(bool value) {
    if (_isExpanded != value) {
      _isExpanded = value;
      notifyListeners();
    }
  }

  /// 从 URL 创建根节点
  factory FileNode.fromPath(String dirPath) {
    final name = p.basename(dirPath);
    return FileNode(
      path: dirPath,
      name: name,
      isDirectory: true,
    );
  }

  /// 加载子节点
  void loadChildren() {
    if (!isDirectory) return;
    try {
      final dir = Directory(path);
      final entries = dir.listSync()
        ..sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
          return p.basename(a.path).toLowerCase().compareTo(
                p.basename(b.path).toLowerCase(),
              );
        });

      children = entries
          .where((e) => !_isHidden(e))
          .map((e) => FileNode(
                path: e.path,
                name: p.basename(e.path),
                isDirectory: e is Directory,
              ))
          .toList();
      notifyListeners();
    } catch (_) {
      children = [];
      notifyListeners();
    }
  }

  /// 过滤隐藏文件和常见忽略目录
  static bool _isHidden(FileSystemEntity entity) {
    final name = p.basename(entity.path);
    if (name.startsWith('.')) return true;
    const ignoreDirs = {
      'node_modules', '__pycache__', '.git', '.svn', '.hg',
      'build', '.dart_tool', '.idea', '.vscode',
    };
    if (entity is Directory && ignoreDirs.contains(name)) return true;
    return false;
  }

  /// 文件图标名称（Material Icons name）
  String get iconName {
    if (isDirectory) {
      return isExpanded ? 'folder_open' : 'folder';
    }
    final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
    switch (ext) {
      case 'dart':
        return 'code';
      case 'swift':
        return 'code';
      case 'js':
      case 'jsx':
      case 'ts':
      case 'tsx':
        return 'javascript';
      case 'py':
        return 'code';
      case 'json':
        return 'data_object';
      case 'md':
      case 'txt':
        return 'description';
      case 'html':
      case 'css':
        return 'web';
      case 'sh':
      case 'bash':
      case 'zsh':
        return 'terminal';
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'webp':
      case 'ico':
        return 'image';
      case 'yaml':
      case 'yml':
      case 'toml':
        return 'settings';
      default:
        return 'insert_drive_file';
    }
  }

  /// 文件图标颜色 hex
  String? get iconColorHex {
    if (isDirectory) return null;
    final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
    switch (ext) {
      case 'dart':
        return '#00B4AB';
      case 'swift':
        return '#F05138';
      case 'js':
      case 'jsx':
        return '#F7DF1E';
      case 'ts':
      case 'tsx':
        return '#3178C6';
      case 'py':
        return '#3776AB';
      case 'rs':
        return '#DEA584';
      case 'html':
        return '#E34F26';
      case 'css':
        return '#1572B6';
      case 'json':
        return '#A0A0A0';
      default:
        return null;
    }
  }
}
