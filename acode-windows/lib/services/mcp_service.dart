import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/mcp_server.dart';

/// MCP 服务器配置管理服务
class MCPService {
  static final MCPService shared = MCPService._();
  MCPService._();

  /// 获取所有 MCP 服务器（合并多个配置源）
  List<MCPServer> listServers() {
    final servers = <String, MCPServer>{};

    // 读取 Claude 配置
    _readClaudeConfig(servers);
    // 读取 Codex 配置
    _readCodexConfig(servers);
    // 读取全局 ACode 配置
    _readACodeConfig(servers);

    return servers.values.toList();
  }

  /// 添加或更新 MCP 服务器
  void upsertServer(MCPFormData data) {
    final spec = data.toSpec();

    // 写入 Claude MCP 配置
    _writeToClaudeConfig(data.id, data.transport, spec);
    // 写入 Codex MCP 配置
    _writeToCodexConfig(data.id, data.transport, spec);
    // 写入 ACode 自有配置
    _writeToACodeConfig(data.id, data.transport, spec);
  }

  /// 删除 MCP 服务器
  void deleteServer(String id) {
    _removeFromClaudeConfig(id);
    _removeFromCodexConfig(id);
    _removeFromACodeConfig(id);
  }

  // ==================== Claude MCP 配置 ====================

  String get _claudeConfigPath {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    return p.join(home, '.claude', 'claude_desktop_config.json');
  }

  void _readClaudeConfig(Map<String, MCPServer> servers) {
    try {
      final file = File(_claudeConfigPath);
      if (!file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final mcpServers = json['mcpServers'] as Map<String, dynamic>? ?? {};
      for (final entry in mcpServers.entries) {
        final spec = Map<String, dynamic>.from(entry.value as Map);
        final transport = spec.containsKey('url') ? 'http' : 'stdio';
        final existing = servers[entry.key];
        if (existing != null) {
          servers[entry.key] = MCPServer(
            id: entry.key,
            transport: transport,
            spec: spec,
            sources: [...existing.sources, 'Claude'],
          );
        } else {
          servers[entry.key] = MCPServer(
            id: entry.key,
            transport: transport,
            spec: spec,
            sources: ['Claude'],
          );
        }
      }
    } catch (_) {}
  }

  void _writeToClaudeConfig(String id, String transport, Map<String, dynamic> spec) {
    try {
      final file = File(_claudeConfigPath);
      Map<String, dynamic> json = {};
      if (file.existsSync()) {
        json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }
      final mcpServers = Map<String, dynamic>.from(json['mcpServers'] as Map? ?? {});
      mcpServers[id] = spec;
      json['mcpServers'] = mcpServers;
      _ensureDir(file);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {}
  }

  void _removeFromClaudeConfig(String id) {
    try {
      final file = File(_claudeConfigPath);
      if (!file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final mcpServers = Map<String, dynamic>.from(json['mcpServers'] as Map? ?? {});
      mcpServers.remove(id);
      json['mcpServers'] = mcpServers;
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {}
  }

  // ==================== Codex MCP 配置 ====================

  String get _codexConfigPath {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    return p.join(home, '.codex', 'mcp.json');
  }

  void _readCodexConfig(Map<String, MCPServer> servers) {
    try {
      final file = File(_codexConfigPath);
      if (!file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final mcpServers = json['mcpServers'] as Map<String, dynamic>? ?? {};
      for (final entry in mcpServers.entries) {
        final spec = Map<String, dynamic>.from(entry.value as Map);
        final transport = spec.containsKey('url') ? 'http' : 'stdio';
        final existing = servers[entry.key];
        if (existing != null) {
          servers[entry.key] = MCPServer(
            id: entry.key,
            transport: transport,
            spec: spec,
            sources: [...existing.sources, 'Codex'],
          );
        } else {
          servers[entry.key] = MCPServer(
            id: entry.key,
            transport: transport,
            spec: spec,
            sources: ['Codex'],
          );
        }
      }
    } catch (_) {}
  }

  void _writeToCodexConfig(String id, String transport, Map<String, dynamic> spec) {
    try {
      final file = File(_codexConfigPath);
      Map<String, dynamic> json = {};
      if (file.existsSync()) {
        json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }
      final mcpServers = Map<String, dynamic>.from(json['mcpServers'] as Map? ?? {});
      mcpServers[id] = spec;
      json['mcpServers'] = mcpServers;
      _ensureDir(file);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {}
  }

  void _removeFromCodexConfig(String id) {
    try {
      final file = File(_codexConfigPath);
      if (!file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final mcpServers = Map<String, dynamic>.from(json['mcpServers'] as Map? ?? {});
      mcpServers.remove(id);
      json['mcpServers'] = mcpServers;
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {}
  }

  // ==================== ACode 自有配置 ====================

  String get _acodeConfigPath {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    return p.join(home, '.acode', 'mcp_servers.json');
  }

  void _readACodeConfig(Map<String, MCPServer> servers) {
    try {
      final file = File(_acodeConfigPath);
      if (!file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final mcpServers = json['mcpServers'] as Map<String, dynamic>? ?? {};
      for (final entry in mcpServers.entries) {
        final spec = Map<String, dynamic>.from(entry.value as Map);
        final transport = spec.containsKey('url') ? 'http' : 'stdio';
        final existing = servers[entry.key];
        if (existing != null) {
          servers[entry.key] = MCPServer(
            id: entry.key,
            transport: transport,
            spec: spec,
            sources: [...existing.sources, 'ACode'],
          );
        } else {
          servers[entry.key] = MCPServer(
            id: entry.key,
            transport: transport,
            spec: spec,
            sources: ['ACode'],
          );
        }
      }
    } catch (_) {}
  }

  void _writeToACodeConfig(String id, String transport, Map<String, dynamic> spec) {
    try {
      final file = File(_acodeConfigPath);
      Map<String, dynamic> json = {};
      if (file.existsSync()) {
        json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }
      final mcpServers = Map<String, dynamic>.from(json['mcpServers'] as Map? ?? {});
      mcpServers[id] = spec;
      json['mcpServers'] = mcpServers;
      _ensureDir(file);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {}
  }

  void _removeFromACodeConfig(String id) {
    try {
      final file = File(_acodeConfigPath);
      if (!file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final mcpServers = Map<String, dynamic>.from(json['mcpServers'] as Map? ?? {});
      mcpServers.remove(id);
      json['mcpServers'] = mcpServers;
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {}
  }

  void _ensureDir(File file) {
    final dir = file.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
}
