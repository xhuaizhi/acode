import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// 终端标签
class TerminalTab {
  final String id;
  String title;
  String workingDirectory;

  TerminalTab({
    String? id,
    this.title = 'Terminal',
    String? workingDirectory,
  })  : id = id ?? const Uuid().v4(),
        workingDirectory = workingDirectory ?? _defaultHome;

  static String get _defaultHome {
    final home = Platform.environment['USERPROFILE']
        ?? Platform.environment['HOME']
        ?? (Platform.isWindows ? 'C:\\' : '/');
    return home;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TerminalTab && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 分屏方向
enum SplitDirection { horizontal, vertical }

/// 分屏节点类型
sealed class SplitNodeType {}

class TerminalLeaf extends SplitNodeType {
  final TerminalTab tab;
  TerminalLeaf(this.tab);
}

class SplitContainer extends SplitNodeType {
  final SplitDirection direction;
  final SplitNode first;
  final SplitNode second;
  SplitContainer(this.direction, this.first, this.second);
}

/// 分屏树节点
class SplitNode extends ChangeNotifier {
  final String id;
  SplitNodeType type;
  double splitRatio;

  SplitNode.terminal(TerminalTab tab)
      : id = const Uuid().v4(),
        type = TerminalLeaf(tab),
        splitRatio = 0.5;

  SplitNode.split(SplitDirection direction, SplitNode first, SplitNode second)
      : id = const Uuid().v4(),
        type = SplitContainer(direction, first, second),
        splitRatio = 0.5;

  /// 获取所有终端标签
  List<TerminalTab> get allTabs {
    switch (type) {
      case TerminalLeaf(:final tab):
        return [tab];
      case SplitContainer(:final first, :final second):
        return [...first.allTabs, ...second.allTabs];
    }
  }

  /// 检查是否包含某个 tab
  bool containsTab(String tabId) {
    switch (type) {
      case TerminalLeaf(:final tab):
        return tab.id == tabId;
      case SplitContainer(:final first, :final second):
        return first.containsTab(tabId) || second.containsTab(tabId);
    }
  }

  /// 在指定终端旁分屏，新终端继承工作目录
  void splitTerminal(String tabId, SplitDirection direction, {String? workingDirectory}) {
    switch (type) {
      case TerminalLeaf(:final tab) when tab.id == tabId:
        final newTab = TerminalTab(workingDirectory: workingDirectory ?? tab.workingDirectory);
        final firstNode = SplitNode.terminal(tab);
        final secondNode = SplitNode.terminal(newTab);
        type = SplitContainer(direction, firstNode, secondNode);
        splitRatio = 0.5;
        notifyListeners();
        break;

      case SplitContainer(:final first, :final second):
        if (first.containsTab(tabId)) {
          first.splitTerminal(tabId, direction, workingDirectory: workingDirectory);
        } else if (second.containsTab(tabId)) {
          second.splitTerminal(tabId, direction, workingDirectory: workingDirectory);
        }
        break;

      default:
        break;
    }
  }

  /// 关闭终端面板
  bool closeTerminal(String tabId) {
    switch (type) {
      case TerminalLeaf(:final tab) when tab.id == tabId:
        return false; // 根节点不能自己关闭

      case TerminalLeaf():
        return false;

      case SplitContainer(:final first, :final second):
        // 检查直接子节点
        if (first.type case TerminalLeaf(:final tab) when tab.id == tabId) {
          type = second.type;
          splitRatio = second.splitRatio;
          notifyListeners();
          return true;
        }
        if (second.type case TerminalLeaf(:final tab) when tab.id == tabId) {
          type = first.type;
          splitRatio = first.splitRatio;
          notifyListeners();
          return true;
        }

        // 递归
        if (first.closeTerminal(tabId)) return true;
        if (second.closeTerminal(tabId)) return true;
        return false;
    }
  }

  /// 恢复多个终端（构建平衡分屏树）
  void restoreTerminals(int count, {SplitDirection direction = SplitDirection.horizontal}) {
    if (count <= 1) return;
    if (type case TerminalLeaf(:final tab)) {
      SplitNode buildBalanced(int n) {
        if (n <= 1) return SplitNode.terminal(TerminalTab());
        final half = n ~/ 2;
        return SplitNode.split(direction, buildBalanced(half), buildBalanced(n - half));
      }

      final remaining = buildBalanced(count - 1);
      type = SplitContainer(direction, SplitNode.terminal(tab), remaining);
      splitRatio = 1.0 / count;
      notifyListeners();
    }
  }

  void updateSplitRatio(double ratio) {
    splitRatio = ratio.clamp(0.15, 0.85);
    notifyListeners();
  }
}
