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
  final int sortOrder;
  final String? icon;
  final String? iconColor;
  final String? notes;
  final String? category;
  final String? presetId;
  final int createdAt;  // unix timestamp
  final int updatedAt;  // unix timestamp

  Provider({
    this.id,
    required this.name,
    required this.tool,
    required this.apiKey,
    this.apiBase = '',
    this.model = '',
    this.extraEnv = '{}',
    this.isActive = false,
    this.sortOrder = 0,
    this.icon,
    this.iconColor,
    this.notes,
    this.category,
    this.presetId,
    int? createdAt,
    int? updatedAt,
  }) : createdAt = createdAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
       updatedAt = updatedAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

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
      'sort_order': sortOrder,
      'icon': icon,
      'icon_color': iconColor,
      'notes': notes,
      'category': category,
      'preset_id': presetId,
      'created_at': createdAt,
      'updated_at': updatedAt,
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
      sortOrder: (map['sort_order'] as int?) ?? 0,
      icon: map['icon'] as String?,
      iconColor: map['icon_color'] as String?,
      notes: map['notes'] as String?,
      category: map['category'] as String?,
      presetId: map['preset_id'] as String?,
      createdAt: (map['created_at'] as int?) ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      updatedAt: (map['updated_at'] as int?) ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
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
    int? sortOrder,
    String? icon,
    String? iconColor,
    String? notes,
    String? category,
    String? presetId,
    int? updatedAt,
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
      sortOrder: sortOrder ?? this.sortOrder,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      presetId: presetId ?? this.presetId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    ProviderPreset(
      id: 'claude-official',
      name: 'Claude 官方',
      tool: 'claude_code',
      defaultModel: 'claude-sonnet-4-20250514',
      icon: 'anthropic',
      iconColor: '#D4915D',
    ),
    ProviderPreset(
      id: 'openai-official',
      name: 'OpenAI 官方',
      tool: 'openai',
      defaultModel: 'o4-mini',
      icon: 'openai',
      iconColor: '#00A67E',
    ),
    ProviderPreset(
      id: 'gemini-official',
      name: 'Gemini 官方',
      tool: 'gemini',
      defaultModel: 'gemini-2.5-pro',
      icon: 'gemini',
      iconColor: '#4285F4',
    ),
    ProviderPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      tool: 'openai',
      apiBase: 'https://api.deepseek.com',
      defaultModel: 'deepseek-chat',
      icon: 'deepseek',
      iconColor: '#1E88E5',
    ),
    ProviderPreset(
      id: 'openrouter',
      name: 'OpenRouter',
      tool: 'claude_code',
      apiBase: 'https://openrouter.ai/api/v1',
      defaultModel: 'anthropic/claude-sonnet-4',
      icon: 'openrouter',
      iconColor: '#6366F1',
    ),
  ];
}

/// 默认模型配置
class DefaultModels {
  static const List<String> claude = [
    'claude-sonnet-4-20250514',
    'claude-opus-4-20250514',
    'claude-3.5-haiku-20241022',
    'claude-3-5-sonnet-20241022',
  ];

  static const List<String> openai = [
    'o4-mini',
    'gpt-4.1',
    'gpt-4.1-mini',
    'gpt-4.1-nano',
    'o3',
    'o3-mini',
    'codex-mini-latest',
  ];

  static const List<String> gemini = [
    'gemini-2.5-pro',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static List<String> modelsForTool(String tool) {
    switch (tool) {
      case 'claude_code': return claude;
      case 'openai': return openai;
      case 'gemini': return gemini;
      default: return [];
    }
  }

  static String defaultModel(String tool) {
    switch (tool) {
      case 'claude_code': return 'claude-sonnet-4-20250514';
      case 'openai': return 'o4-mini';
      case 'gemini': return 'gemini-2.5-pro';
      default: return '';
    }
  }
}
