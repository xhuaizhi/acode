import 'package:flutter/material.dart';

/// Provider 图标自动推断
class ProviderIconInference {
  /// 根据 Provider 名称推断图标
  static IconData inferIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('claude') || lower.contains('anthropic')) {
      return Icons.auto_awesome;
    }
    if (lower.contains('openai') || lower.contains('gpt') || lower.contains('codex')) {
      return Icons.psychology;
    }
    if (lower.contains('gemini') || lower.contains('google')) {
      return Icons.diamond;
    }
    if (lower.contains('openrouter')) {
      return Icons.router;
    }
    if (lower.contains('deepseek')) {
      return Icons.explore;
    }
    if (lower.contains('mistral')) {
      return Icons.air;
    }
    return Icons.smart_toy;
  }

  /// 根据 Provider 名称推断颜色
  static Color inferColor(String name, {String? iconColor}) {
    if (iconColor != null && iconColor.isNotEmpty) {
      return hexToColor(iconColor);
    }
    final lower = name.toLowerCase();
    if (lower.contains('claude') || lower.contains('anthropic')) {
      return const Color(0xFFD4915D);
    }
    if (lower.contains('openai') || lower.contains('gpt') || lower.contains('codex')) {
      return const Color(0xFF00A67E);
    }
    if (lower.contains('gemini') || lower.contains('google')) {
      return const Color(0xFF4285F4);
    }
    if (lower.contains('openrouter')) {
      return const Color(0xFF6366F1);
    }
    if (lower.contains('deepseek')) {
      return const Color(0xFF0066FF);
    }
    return Colors.grey;
  }

  /// 根据工具类型获取默认颜色
  static Color toolColor(String tool) {
    switch (tool) {
      case 'claude_code':
        return const Color(0xFFD4915D);
      case 'openai':
        return const Color(0xFF00A67E);
      case 'gemini':
        return const Color(0xFF4285F4);
      default:
        return Colors.grey;
    }
  }

  /// Hex 转 Color
  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
