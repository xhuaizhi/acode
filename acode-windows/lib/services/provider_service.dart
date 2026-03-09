import '../database/database_manager.dart';
import '../models/provider.dart';
import '../utils/provider_icon_inference.dart';
import 'provider_config_writer.dart';
import 'provider_env_generator.dart';

/// Provider 业务逻辑服务
class ProviderService {
  final DatabaseManager _db;

  ProviderService(this._db);

  /// 获取所有 Provider
  Future<List<Provider>> getAllProviders() async {
    return await _db.getAllProviders();
  }

  /// 获取指定工具的 Provider
  Future<List<Provider>> getProvidersByTool(String tool) async {
    return await _db.getProvidersByTool(tool);
  }

  /// 获取指定工具的激活 Provider
  Future<Provider?> getActiveProvider(String tool) async {
    return await _db.getActiveProvider(tool);
  }

  /// 获取所有工具的激活 Provider
  Future<Map<String, Provider>> getActiveProviders() async {
    final map = <String, Provider>{};
    for (final tool in ['claude_code', 'openai', 'gemini']) {
      final p = await _db.getActiveProvider(tool);
      if (p != null) map[tool] = p;
    }
    return map;
  }

  /// 创建 Provider
  Future<Provider> createProvider(ProviderFormData data) async {
    // 自动推断图标
    String? icon = data.icon;
    String? iconColor = data.iconColor;
    if (icon == null || icon.isEmpty) {
      final inferred = ProviderIconInference.infer(data.name);
      if (inferred != null) {
        icon = inferred.name;
        iconColor = inferred.color;
      }
    }

    // 如果 model 为空，使用默认模型
    final model = data.model.isEmpty
        ? DefaultModels.defaultModel(data.tool)
        : data.model;

    final provider = Provider(
      name: data.name,
      tool: data.tool,
      apiKey: data.apiKey,
      apiBase: data.apiBase,
      model: model,
      extraEnv: data.mergedExtraEnv,
      icon: icon,
      iconColor: iconColor,
      notes: data.notes,
      category: data.category,
      presetId: data.presetId,
    );

    final id = await _db.insertProvider(provider);
    final created = provider.copyWith(id: id);

    // 如果是第一个同工具 Provider，自动激活
    final siblings = await _db.getProvidersByTool(data.tool);
    if (siblings.length == 1) {
      await switchProvider(id, data.tool);
    }

    return created;
  }

  /// 更新 Provider
  Future<Provider> updateProvider(int id, ProviderFormData data) async {
    final existing = (await _db.getAllProviders()).firstWhere((p) => p.id == id);
    final updated = existing.copyWith(
      name: data.name,
      apiKey: data.apiKey,
      apiBase: data.apiBase,
      model: data.model,
      extraEnv: data.mergedExtraEnv,
      icon: data.icon,
      iconColor: data.iconColor,
      notes: data.notes,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await _db.updateProvider(updated);

    // 如果是激活的 Provider，重写配置文件
    if (updated.isActive) {
      await _writeConfig(updated);
    }

    return updated;
  }

  /// 删除 Provider
  Future<void> deleteProvider(int id) async {
    // 获取要删除的 Provider 的 tool 信息
    final all = await _db.getAllProviders();
    final target = all.where((p) => p.id == id).toList();
    final tool = target.isNotEmpty ? target.first.tool : null;

    await _db.deleteProvider(id);

    // 如果删除后有新的自动激活 Provider，写入 Live 配置
    if (tool != null) {
      final newActive = await _db.getActiveProvider(tool);
      if (newActive != null) {
        await _writeConfig(newActive);
      }
    }
  }

  /// 切换激活 Provider
  Future<void> switchProvider(int id, String tool) async {
    await _db.switchActiveProvider(id, tool);

    // 重写配置文件
    final active = await _db.getActiveProvider(tool);
    if (active != null) {
      await _writeConfig(active);
    }
  }

  /// 获取 Provider 环境变量（用于终端注入）
  Future<Map<String, String>> getProviderEnv(String tool) async {
    final provider = await _db.getActiveProvider(tool);
    if (provider == null) return {};
    return ProviderEnvGenerator.generate(provider);
  }

  /// 获取所有工具合并的环境变量
  Future<Map<String, String>> getAllProviderEnv() async {
    final env = <String, String>{};
    for (final tool in ['claude_code', 'openai', 'gemini']) {
      final toolEnv = await getProviderEnv(tool);
      env.addAll(toolEnv);
    }
    return env;
  }

  /// 写入配置文件
  Future<void> _writeConfig(Provider provider) async {
    try {
      await ProviderConfigWriter.writeConfig(provider);
    } catch (_) {
      // 配置写入失败不阻塞主流程
    }
  }
}
