import 'dart:convert';

/// AI Provider 数据模型
class Provider {
  final int? id;
  final String name;
  final String tool; // claude_code, openai, gemini
  final String apiKey;
  final String apiBase;
  final String model;
  final String extraEnv; // JSON string
  final bool isActive;
  final String? icon;
  final String? iconColor;
  final String? notes;
  final String? category;
  final String? presetId;
  final DateTime createdAt;

  Provider({
    this.id,
    required this.name,
    required this.tool,
    required this.apiKey,
    this.apiBase = '',
    this.model = '',
    this.extraEnv = '{}',
    this.isActive = false,
    this.icon,
    this.iconColor,
    this.notes,
    this.category,
    this.presetId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// API Key 脱敏显示
  String get maskedApiKey {
    if (apiKey.isEmpty) return '(空)';
    if (apiKey.length <= 8) return '****';
    return '${apiKey.substring(0, 4)}****${apiKey.substring(apiKey.length - 4)}';
  }

  /// 解析 extraEnv JSON 为 Map
  Map<String, String>? get extraEnvDict {
    try {
      final decoded = jsonDecode(extraEnv);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return null;
  }

  /// 工具显示名称
  String get toolDisplayName {
    switch (tool) {
      case 'claude_code':
        return 'Claude Code';
      case 'openai':
        return 'OpenAI Codex';
      case 'gemini':
        return 'Gemini CLI';
      default:
        return tool;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'tool': tool,
      'api_key': apiKey,
      'api_base': apiBase,
      'model': model,
      'extra_env': extraEnv,
      'is_active': isActive ? 1 : 0,
      'icon': icon,
      'icon_color': iconColor,
      'notes': notes,
      'category': category,
      'preset_id': presetId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Provider.fromMap(Map<String, dynamic> map) {
    return Provider(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      tool: map['tool'] as String? ?? '',
      apiKey: map['api_key'] as String? ?? '',
      apiBase: map['api_base'] as String? ?? '',
      model: map['model'] as String? ?? '',
      extraEnv: map['extra_env'] as String? ?? '{}',
      isActive: (map['is_active'] as int?) == 1,
      icon: map['icon'] as String?,
      iconColor: map['icon_color'] as String?,
      notes: map['notes'] as String?,
      category: map['category'] as String?,
      presetId: map['preset_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Provider copyWith({
    int? id,
    String? name,
    String? tool,
    String? apiKey,
    String? apiBase,
    String? model,
    String? extraEnv,
    bool? isActive,
    String? icon,
    String? iconColor,
    String? notes,
    String? category,
    String? presetId,
  }) {
    return Provider(
      id: id ?? this.id,
      name: name ?? this.name,
      tool: tool ?? this.tool,
      apiKey: apiKey ?? this.apiKey,
      apiBase: apiBase ?? this.apiBase,
      model: model ?? this.model,
      extraEnv: extraEnv ?? this.extraEnv,
      isActive: isActive ?? this.isActive,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      presetId: presetId ?? this.presetId,
      createdAt: createdAt,
    );
  }
}

/// Provider 表单数据
class ProviderFormData {
  final String name;
  final String tool;
  final String apiKey;
  final String apiBase;
  final String model;
  final String extraEnv;
  final String? icon;
  final String? iconColor;
  final String? notes;
  final String? category;
  final String? presetId;
  // Claude 专用多模型
  final String haikuModel;
  final String sonnetModel;
  final String opusModel;

  ProviderFormData({
    required this.name,
    required this.tool,
    required this.apiKey,
    this.apiBase = '',
    this.model = '',
    this.extraEnv = '{}',
    this.icon,
    this.iconColor,
    this.notes,
    this.category,
    this.presetId,
    this.haikuModel = '',
    this.sonnetModel = '',
    this.opusModel = '',
  });

  /// 合并 Claude 多模型到 extraEnv
  String get mergedExtraEnv {
    if (tool != 'claude_code') return extraEnv;
    try {
      final map = Map<String, dynamic>.from(
        jsonDecode(extraEnv.isEmpty ? '{}' : extraEnv) as Map,
      );
      if (haikuModel.isNotEmpty) {
        map['ANTHROPIC_DEFAULT_HAIKU_MODEL'] = haikuModel;
      }
      if (sonnetModel.isNotEmpty) {
        map['ANTHROPIC_DEFAULT_SONNET_MODEL'] = sonnetModel;
      }
      if (opusModel.isNotEmpty) {
        map['ANTHROPIC_DEFAULT_OPUS_MODEL'] = opusModel;
      }
      return jsonEncode(map);
    } catch (_) {
      return extraEnv;
    }
  }
}

/// Provider 预设
class ProviderPreset {
  final String id;
  final String name;
  final String tool;
  final String apiBase;
  final String defaultModel;
  final String? icon;
  final String? iconColor;

  const ProviderPreset({
    required this.id,
    required this.name,
    required this.tool,
    this.apiBase = '',
    this.defaultModel = '',
    this.icon,
    this.iconColor,
  });

  static const List<ProviderPreset> presets = [
    // Claude Code
    ProviderPreset(
      id: 'claude_official',
      name: 'Anthropic 官方',
      tool: 'claude_code',
      defaultModel: 'claude-sonnet-4-20250514',
      iconColor: '#D4915D',
    ),
    ProviderPreset(
      id: 'claude_openrouter',
      name: 'OpenRouter (Claude)',
      tool: 'claude_code',
      apiBase: 'https://openrouter.ai/api/v1',
      defaultModel: 'anthropic/claude-sonnet-4-20250514',
      iconColor: '#6366F1',
    ),
    // OpenAI Codex
    ProviderPreset(
      id: 'openai_official',
      name: 'OpenAI 官方',
      tool: 'openai',
      defaultModel: 'o3-mini',
      iconColor: '#00A67E',
    ),
    ProviderPreset(
      id: 'openai_openrouter',
      name: 'OpenRouter (OpenAI)',
      tool: 'openai',
      apiBase: 'https://openrouter.ai/api/v1',
      defaultModel: 'openai/o3-mini',
      iconColor: '#6366F1',
    ),
    // Gemini CLI
    ProviderPreset(
      id: 'gemini_official',
      name: 'Google 官方',
      tool: 'gemini',
      defaultModel: 'gemini-2.5-pro',
      iconColor: '#4285F4',
    ),
    ProviderPreset(
      id: 'gemini_openrouter',
      name: 'OpenRouter (Gemini)',
      tool: 'gemini',
      apiBase: 'https://openrouter.ai/api/v1',
      defaultModel: 'google/gemini-2.5-pro-preview',
      iconColor: '#6366F1',
    ),
  ];
}
