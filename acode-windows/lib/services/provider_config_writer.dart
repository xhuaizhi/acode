import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/provider.dart';

/// CLI 配置文件写入器
/// 负责将 Provider 配置写入各 CLI 工具的配置文件
class ProviderConfigWriter {
  static String get _home =>
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';

  /// 根据 Provider 工具类型写入对应的配置文件
  static Future<void> writeConfig(Provider provider) async {
    switch (provider.tool) {
      case 'claude_code':
        await _writeClaudeConfig(provider);
        break;
      case 'openai':
        await _writeCodexConfig(provider);
        break;
      case 'gemini':
        await _writeGeminiConfig(provider);
        break;
    }
  }

  // MARK: - Claude Code → ~/.claude/settings.json

  static Future<void> _writeClaudeConfig(Provider provider) async {
    if (_home.isEmpty) return;

    final claudeDir = Directory(p.join(_home, '.claude'));
    if (!claudeDir.existsSync()) claudeDir.createSync(recursive: true);

    final settingsFile = File(p.join(claudeDir.path, 'settings.json'));

    // 读取现有配置（合并写入，不覆盖用户其他配置）
    Map<String, dynamic> settings = {};
    if (settingsFile.existsSync()) {
      try {
        settings = jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 构建 env 对象
    final env = Map<String, dynamic>.from(
      (settings['env'] as Map?) ?? {},
    );

    // 写入核心字段
    if (provider.apiKey.isNotEmpty) {
      env['ANTHROPIC_API_KEY'] = provider.apiKey;
    }
    if (provider.apiBase.isNotEmpty) {
      env['ANTHROPIC_BASE_URL'] = provider.apiBase;
    } else {
      env.remove('ANTHROPIC_BASE_URL');
    }

    // 写入模型
    if (provider.model.isNotEmpty) {
      settings['model'] = provider.model;
    }

    // 合并 extra_env 到 env 对象（跳过 ACODE_ 前缀的内部变量）
    // 包括 Claude 多模型键（ANTHROPIC_DEFAULT_HAIKU_MODEL 等）
    final extraEnv = provider.extraEnvDict;
    if (extraEnv != null) {
      for (final entry in extraEnv.entries) {
        if (!entry.key.startsWith('ACODE_')) {
          env[entry.key] = entry.value;
        }
      }
    }

    settings['env'] = env;

    await _atomicWrite(settingsFile, const JsonEncoder.withIndent('  ').convert(settings));
  }

  // MARK: - OpenAI Codex → ~/.codex/auth.json + config.toml

  static Future<void> _writeCodexConfig(Provider provider) async {
    if (_home.isEmpty) return;

    final codexDir = Directory(p.join(_home, '.codex'));
    if (!codexDir.existsSync()) codexDir.createSync(recursive: true);

    // 1. 写入 auth.json
    if (provider.apiKey.isNotEmpty) {
      final authFile = File(p.join(codexDir.path, 'auth.json'));
      Map<String, dynamic> auth = {};
      if (authFile.existsSync()) {
        try {
          auth = jsonDecode(authFile.readAsStringSync()) as Map<String, dynamic>;
        } catch (_) {}
      }
      auth['OPENAI_API_KEY'] = provider.apiKey;
      await _atomicWrite(authFile, const JsonEncoder.withIndent('  ').convert(auth));
    }

    // 2. 生成并写入 config.toml
    final configFile = File(p.join(codexDir.path, 'config.toml'));
    final toml = _generateCodexToml(provider);
    await _atomicWrite(configFile, toml);
  }

  /// 生成 Codex config.toml 内容
  static String _generateCodexToml(Provider provider) {
    final model = provider.model.isEmpty ? 'o4-mini' : provider.model;

    // 官方 API（无自定义端点）
    if (provider.apiBase.isEmpty) {
      return 'model = "$model"\n';
    }

    // 第三方 API：需要 model_provider section
    final baseUrl = _normalizeCodexBaseUrl(provider.apiBase);
    return 'model_provider = "acode_provider"\n'
        'model = "$model"\n'
        'disable_response_storage = true\n'
        '\n'
        '[model_providers.acode_provider]\n'
        'name = "${provider.name}"\n'
        'base_url = "$baseUrl"\n'
        'wire_api = "responses"\n'
        'requires_openai_auth = true\n';
  }

  /// 规范化 Codex Base URL
  static String _normalizeCodexBaseUrl(String url) {
    var trimmed = url.replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/v1')) return trimmed;
    // 检查是否为纯 origin（无路径部分）
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.path.isEmpty || uri.path == '/')) {
      return '$trimmed/v1';
    }
    return trimmed;
  }

  // MARK: - Gemini CLI → ~/.gemini/.env + settings.json

  static Future<void> _writeGeminiConfig(Provider provider) async {
    if (_home.isEmpty) return;

    final geminiDir = Directory(p.join(_home, '.gemini'));
    if (!geminiDir.existsSync()) geminiDir.createSync(recursive: true);

    // 1. 写入 .env 文件
    await _writeGeminiEnvFile(provider, geminiDir.path);

    // 2. 写入 settings.json（认证类型）
    if (provider.apiKey.isNotEmpty) {
      await _writeGeminiSettingsJson(geminiDir.path);
    }
  }

  static Future<void> _writeGeminiEnvFile(Provider provider, String dirPath) async {
    final envFile = File(p.join(dirPath, '.env'));

    // 解析现有 .env
    final envMap = <String, String>{};
    if (envFile.existsSync()) {
      try {
        for (final line in envFile.readAsStringSync().split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final eqIdx = trimmed.indexOf('=');
          if (eqIdx > 0) {
            envMap[trimmed.substring(0, eqIdx).trim()] = trimmed.substring(eqIdx + 1).trim();
          }
        }
      } catch (_) {}
    }

    // 更新 Provider 相关字段
    if (provider.apiKey.isNotEmpty) {
      envMap['GEMINI_API_KEY'] = provider.apiKey;
    }
    if (provider.apiBase.isNotEmpty) {
      envMap['GOOGLE_GEMINI_BASE_URL'] = provider.apiBase;
    } else {
      envMap.remove('GOOGLE_GEMINI_BASE_URL');
    }
    if (provider.model.isNotEmpty) {
      envMap['GEMINI_MODEL'] = provider.model;
    }

    // 合并 extra_env
    final extra = provider.extraEnvDict;
    if (extra != null) {
      envMap.addAll(extra);
    }

    // 输出：优先核心键
    final priorityKeys = ['GEMINI_API_KEY', 'GOOGLE_GEMINI_BASE_URL', 'GEMINI_MODEL'];
    final lines = <String>[];
    for (final key in priorityKeys) {
      if (envMap.containsKey(key)) {
        lines.add('$key=${envMap[key]}');
      }
    }
    for (final entry in envMap.entries) {
      if (!priorityKeys.contains(entry.key)) {
        lines.add('${entry.key}=${entry.value}');
      }
    }

    await _atomicWrite(envFile, '${lines.join('\n')}\n');
  }

  static Future<void> _writeGeminiSettingsJson(String dirPath) async {
    final settingsFile = File(p.join(dirPath, 'settings.json'));

    Map<String, dynamic> settings = {};
    if (settingsFile.existsSync()) {
      try {
        settings = jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 设置认证类型
    final security = Map<String, dynamic>.from(
      (settings['security'] as Map?) ?? {},
    );
    final auth = Map<String, dynamic>.from(
      (security['auth'] as Map?) ?? {},
    );
    auth['selectedType'] = 'gemini-api-key';
    security['auth'] = auth;
    settings['security'] = security;

    await _atomicWrite(settingsFile, const JsonEncoder.withIndent('  ').convert(settings));
  }

  /// 原子写入
  static Future<void> _atomicWrite(File file, String content) async {
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsString(content, flush: true);
    await tmpFile.rename(file.path);
  }
}
