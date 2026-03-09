import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/provider.dart';

/// 配置文件写入服务 — 写入 Claude/Codex/Gemini CLI 的配置文件
class ProviderConfigWriter {
  /// 根据 Provider 类型写入对应配置
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
    // 写入通用环境变量文件
    await _writeEnvFile(provider);
  }

  /// 写入 Claude Code 配置
  static Future<void> _writeClaudeConfig(Provider provider) async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    final configDir = Directory(p.join(home, '.claude'));
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }

    // 写入 settings.json
    final settingsFile = File(p.join(configDir.path, 'settings.json'));
    Map<String, dynamic> settings = {};
    if (settingsFile.existsSync()) {
      try {
        settings = jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (provider.apiBase.isNotEmpty) {
      settings['apiBaseUrl'] = provider.apiBase;
    } else {
      settings.remove('apiBaseUrl');
    }

    if (provider.model.isNotEmpty) {
      settings['model'] = provider.model;
    }

    // 合并 extraEnv 中的模型配置
    final extraEnv = provider.extraEnvDict;
    if (extraEnv != null) {
      if (extraEnv.containsKey('ANTHROPIC_DEFAULT_HAIKU_MODEL')) {
        settings['haikuModel'] = extraEnv['ANTHROPIC_DEFAULT_HAIKU_MODEL'];
      }
      if (extraEnv.containsKey('ANTHROPIC_DEFAULT_SONNET_MODEL')) {
        settings['sonnetModel'] = extraEnv['ANTHROPIC_DEFAULT_SONNET_MODEL'];
      }
      if (extraEnv.containsKey('ANTHROPIC_DEFAULT_OPUS_MODEL')) {
        settings['opusModel'] = extraEnv['ANTHROPIC_DEFAULT_OPUS_MODEL'];
      }
    }

    await _atomicWrite(settingsFile, const JsonEncoder.withIndent('  ').convert(settings));
  }

  /// 写入 OpenAI Codex 配置
  static Future<void> _writeCodexConfig(Provider provider) async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    final configDir = Directory(p.join(home, '.codex'));
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }

    final configFile = File(p.join(configDir.path, 'config.json'));
    Map<String, dynamic> config = {};
    if (configFile.existsSync()) {
      try {
        config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (provider.model.isNotEmpty) {
      config['model'] = provider.model;
    }
    if (provider.apiBase.isNotEmpty) {
      config['apiBaseUrl'] = provider.apiBase;
    }

    await _atomicWrite(configFile, const JsonEncoder.withIndent('  ').convert(config));
  }

  /// 写入 Gemini CLI 配置
  static Future<void> _writeGeminiConfig(Provider provider) async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    final configDir = Directory(p.join(home, '.gemini'));
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }

    final configFile = File(p.join(configDir.path, 'settings.json'));
    Map<String, dynamic> config = {};
    if (configFile.existsSync()) {
      try {
        config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (provider.model.isNotEmpty) {
      config['model'] = provider.model;
    }
    if (provider.apiBase.isNotEmpty) {
      config['apiBaseUrl'] = provider.apiBase;
    }

    await _atomicWrite(configFile, const JsonEncoder.withIndent('  ').convert(config));
  }

  /// 写入环境变量文件 (.env 风格)
  static Future<void> _writeEnvFile(Provider provider) async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    final configDir = Directory(p.join(home, '.acode'));
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }

    final envFile = File(p.join(configDir.path, '${provider.tool}.env'));
    final lines = <String>[];

    switch (provider.tool) {
      case 'claude_code':
        lines.add('ANTHROPIC_API_KEY=${provider.apiKey}');
        if (provider.apiBase.isNotEmpty) {
          lines.add('ANTHROPIC_BASE_URL=${provider.apiBase}');
        }
        if (provider.model.isNotEmpty) {
          lines.add('ANTHROPIC_MODEL=${provider.model}');
        }
        break;
      case 'openai':
        lines.add('OPENAI_API_KEY=${provider.apiKey}');
        if (provider.apiBase.isNotEmpty) {
          lines.add('OPENAI_BASE_URL=${provider.apiBase}');
        }
        if (provider.model.isNotEmpty) {
          lines.add('OPENAI_MODEL=${provider.model}');
        }
        break;
      case 'gemini':
        lines.add('GEMINI_API_KEY=${provider.apiKey}');
        if (provider.apiBase.isNotEmpty) {
          lines.add('GEMINI_BASE_URL=${provider.apiBase}');
        }
        break;
    }

    // 追加 extraEnv
    final extra = provider.extraEnvDict;
    if (extra != null) {
      for (final entry in extra.entries) {
        lines.add('${entry.key}=${entry.value}');
      }
    }

    await _atomicWrite(envFile, lines.join('\n'));
  }

  /// 原子写入
  static Future<void> _atomicWrite(File file, String content) async {
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsString(content, flush: true);
    await tmpFile.rename(file.path);
  }
}
