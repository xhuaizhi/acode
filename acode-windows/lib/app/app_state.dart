import 'package:flutter/foundation.dart';

import '../database/database_manager.dart';
import '../models/provider.dart';
import '../models/usage_tracker.dart';
import '../services/provider_service.dart';
import '../services/update_checker.dart';

/// 设置页面 Tab 枚举
enum SettingsTab {
  general('常规', 'settings', '基础'),
  claude('Claude Code', 'auto_awesome', '服务商'),
  openai('OpenAI Codex', 'psychology', '服务商'),
  gemini('Gemini CLI', 'diamond', '服务商'),
  mcp('MCP', 'dns', '工具'),
  skills('技能', 'star', '工具'),
  usage('用量', 'bar_chart', '高级'),
  about('关于', 'info', '其他');

  final String label;
  final String iconName;
  final String group;

  const SettingsTab(this.label, this.iconName, this.group);
}

/// 全局应用状态
class AppState extends ChangeNotifier {
  // 数据库 & 服务
  late final DatabaseManager dbManager;
  late final ProviderService providerService;
  final UpdateChecker updateChecker = UpdateChecker();

  // Provider 状态
  List<Provider> providers = [];
  Map<String, Provider> activeProviders = {};

  // UI 状态
  bool showSettings = false;
  SettingsTab settingsTab = SettingsTab.general;
  int terminalCount = 1;
  String statusMessage = '';

  // 当前活跃文件信息
  String? activeFilePath;
  int? activeFileLineCount;
  DateTime? activeFileModDate;

  // 用量统计
  UsageSummary sessionUsage = UsageSummary();

  AppState() {
    // 监听 UpdateChecker 变化，转发通知
    updateChecker.addListener(notifyListeners);
  }

  @override
  void dispose() {
    updateChecker.removeListener(notifyListeners);
    updateChecker.dispose();
    super.dispose();
  }

  /// 初始化
  Future<void> initialize() async {
    dbManager = DatabaseManager.instance;
    await dbManager.initialize();
    providerService = ProviderService(dbManager);
    await loadProviders();
  }

  /// 加载所有 Provider
  Future<void> loadProviders() async {
    try {
      providers = await providerService.getAllProviders();
      activeProviders = await providerService.getActiveProviders();
      notifyListeners();
    } catch (e) {
      debugPrint('加载 Provider 失败: $e');
    }
  }

  /// 切换 Provider
  Future<void> switchProvider(int id) async {
    try {
      final provider = providers.firstWhere((p) => p.id == id);
      await providerService.switchProvider(id, provider.tool);
      await loadProviders();
      statusMessage = '已切换到 ${provider.name}，新终端将使用新配置';
      notifyListeners();
    } catch (e) {
      debugPrint('切换 Provider 失败: $e');
    }
  }

  /// 删除 Provider
  Future<void> deleteProvider(int id) async {
    try {
      await providerService.deleteProvider(id);
      await loadProviders();
    } catch (e) {
      debugPrint('删除 Provider 失败: $e');
    }
  }

  /// 更新状态消息
  void setStatusMessage(String message) {
    statusMessage = message;
    notifyListeners();
  }

  /// 切换设置页面显示
  void toggleSettings() {
    showSettings = !showSettings;
    notifyListeners();
  }

  /// 更新终端数量
  void setTerminalCount(int count) {
    terminalCount = count;
    notifyListeners();
  }

  /// 更新活跃文件信息
  void setActiveFile({String? path, int? lineCount, DateTime? modDate}) {
    activeFilePath = path;
    activeFileLineCount = lineCount;
    activeFileModDate = modDate;
    notifyListeners();
  }

  /// 重置用量统计
  void resetUsage() {
    sessionUsage.reset();
    notifyListeners();
  }
}
