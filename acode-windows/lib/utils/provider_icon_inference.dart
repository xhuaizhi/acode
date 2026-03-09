import 'package:flutter/material.dart';

/// 推断结果
class InferredIcon {
  final String name;
  final String color;
  const InferredIcon(this.name, this.color);
}

/// Provider 图标自动推断
class ProviderIconInference {
  static const _iconMap = <String, InferredIcon>{
    'openai':      InferredIcon('openai',     '#00A67E'),
    'anthropic':   InferredIcon('anthropic',  '#D4915D'),
    'claude':      InferredIcon('anthropic',  '#D4915D'),
    'google':      InferredIcon('gemini',     '#4285F4'),
    'gemini':      InferredIcon('gemini',     '#4285F4'),
    'deepseek':    InferredIcon('deepseek',   '#1E88E5'),
    'kimi':        InferredIcon('kimi',       '#6366F1'),
    'moonshot':    InferredIcon('moonshot',   '#6366F1'),
    'meta':        InferredIcon('meta',       '#0081FB'),
    'azure':       InferredIcon('azure',      '#0078D4'),
    'aws':         InferredIcon('aws',        '#FF9900'),
    'cloudflare':  InferredIcon('cloudflare', '#F38020'),
    'mistral':     InferredIcon('mistral',    '#FF7000'),
    'openrouter':  InferredIcon('openrouter', '#6366F1'),
    'zhipu':       InferredIcon('zhipu',      '#0F62FE'),
    'alibaba':     InferredIcon('alibaba',    '#FF6A00'),
    'tencent':     InferredIcon('tencent',    '#00A4FF'),
    'baidu':       InferredIcon('baidu',      '#2932E1'),
    'cohere':      InferredIcon('cohere',     '#39594D'),
    'perplexity':  InferredIcon('perplexity', '#20808D'),
    'huggingface': InferredIcon('huggingface','#FFD21E'),
  };

  /// 根据名称推断图标名和颜色
  static InferredIcon? infer(String name) {
    final lower = name.toLowerCase();

    // 精确匹配
    if (_iconMap.containsKey(lower)) {
      return _iconMap[lower];
    }

    // 模糊匹配（名称包含关键词）
    for (final entry in _iconMap.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

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
