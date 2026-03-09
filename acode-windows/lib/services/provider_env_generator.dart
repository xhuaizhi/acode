import '../models/provider.dart';

/// 生成注入终端的环境变量
class ProviderEnvGenerator {
  /// 根据 Provider 生成环境变量字典
  static Map<String, String> generate(Provider provider) {
    final env = <String, String>{};

    switch (provider.tool) {
      case 'claude_code':
        env['ANTHROPIC_API_KEY'] = provider.apiKey;
        if (provider.apiBase.isNotEmpty) {
          env['ANTHROPIC_BASE_URL'] = provider.apiBase;
        }
        if (provider.model.isNotEmpty) {
          env['ANTHROPIC_MODEL'] = provider.model;
        }
        break;

      case 'openai':
        env['OPENAI_API_KEY'] = provider.apiKey;
        if (provider.apiBase.isNotEmpty) {
          env['OPENAI_BASE_URL'] = provider.apiBase;
        }
        if (provider.model.isNotEmpty) {
          env['OPENAI_MODEL'] = provider.model;
        }
        break;

      case 'gemini':
        env['GEMINI_API_KEY'] = provider.apiKey;
        if (provider.apiBase.isNotEmpty) {
          env['GEMINI_BASE_URL'] = provider.apiBase;
        }
        break;
    }

    // 合并 extraEnv
    final extra = provider.extraEnvDict;
    if (extra != null) {
      env.addAll(extra);
    }

    return env;
  }

  /// 合并多个工具的环境变量
  static Map<String, String> mergeAll(Map<String, Provider> activeProviders) {
    final env = <String, String>{};
    for (final provider in activeProviders.values) {
      env.addAll(generate(provider));
    }
    return env;
  }
}
