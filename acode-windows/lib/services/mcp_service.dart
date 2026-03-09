import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/mcp_server.dart';

/// MCP 服务器配置管理服务
/// 读写 Claude / Codex / Gemini 的 MCP 配置文件，与 Mac 版对齐
class MCPService {
  static final MCPService shared = MCPService._();
  MCPService._();

  // MARK: - Config File Paths

  static String get _home =>
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';

  /// ~/.codex/config.toml
  String get _codexConfigPath => p.join(_home, '.codex', 'config.toml');

  /// ~/.claude.json
  String get _claudeRootPath => p.join(_home, '.claude.json');

  /// ~/.claude/settings.json
  String get _claudeSettingsPath => p.join(_home, '.claude', 'settings.json');

  /// ~/.gemini/settings.json
  String get _geminiSettingsPath => p.join(_home, '.gemini', 'settings.json');

  // MARK: - List

  /// 列出所有 MCP 服务器（合并多个来源）
  List<MCPServer> listServers() {
    final merged = <String, _MergedEntry>{};

    // Codex (TOML)
    final codexServers = _readCodexMCPServers();
    if (codexServers != null) {
      for (final entry in codexServers.entries) {
        merged.putIfAbsent(entry.key, () => _MergedEntry(entry.value));
        merged[entry.key]!.sources.add('codex');
        if (merged[entry.key]!.spec.isEmpty) merged[entry.key]!.spec = entry.value;
      }
    }

    // Claude (.claude.json)
    final claudeRoot = _readJSONMCPServers(_claudeRootPath);
    if (claudeRoot != null) {
      for (final entry in claudeRoot.entries) {
        merged.putIfAbsent(entry.key, () => _MergedEntry(entry.value));
        merged[entry.key]!.sources.add('claude');
        if (merged[entry.key]!.spec.isEmpty) merged[entry.key]!.spec = entry.value;
      }
    }

    // Claude settings (.claude/settings.json)
    final claudeSettings = _readJSONMCPServers(_claudeSettingsPath);
    if (claudeSettings != null) {
      for (final entry in claudeSettings.entries) {
        merged.putIfAbsent(entry.key, () => _MergedEntry(entry.value));
        merged[entry.key]!.sources.add('claude');
        if (merged[entry.key]!.spec.isEmpty) merged[entry.key]!.spec = entry.value;
      }
    }

    // Gemini
    final geminiServers = _readJSONMCPServers(_geminiSettingsPath);
    if (geminiServers != null) {
      for (final entry in geminiServers.entries) {
        merged.putIfAbsent(entry.key, () => _MergedEntry(entry.value));
        merged[entry.key]!.sources.add('gemini');
        if (merged[entry.key]!.spec.isEmpty) merged[entry.key]!.spec = entry.value;
      }
    }

    final result = merged.entries.map((e) => MCPServer(
      id: e.key,
      transport: _inferTransport(e.value.spec),
      spec: e.value.spec,
      sources: e.value.sources.toList()..sort(),
    )).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return result;
  }

  // MARK: - Upsert

  /// 添加或更新 MCP 服务器（同步写入所有配置文件）
  void upsertServer(MCPFormData data) {
    final id = data.id.trim();
    if (id.isEmpty) return;

    // 构建 JSON spec
    final jsonSpec = <String, dynamic>{};
    if (data.transport == 'stdio') {
      final command = data.command.trim();
      if (command.isEmpty) return;
      jsonSpec['command'] = command;
      if (data.args.isNotEmpty) jsonSpec['args'] = data.args;
    } else {
      final url = data.url.trim();
      if (url.isEmpty) return;
      jsonSpec['type'] = data.transport;
      jsonSpec['url'] = url;
    }

    // 写入 Codex TOML
    _upsertCodexMCPServer(id, data.transport, data);

    // 写入 Claude JSON
    _upsertJSONMCPServer(_claudeRootPath, id, jsonSpec);
    _upsertJSONMCPServer(_claudeSettingsPath, id, jsonSpec);

    // 写入 Gemini JSON
    _upsertJSONMCPServer(_geminiSettingsPath, id, jsonSpec);
  }

  // MARK: - Delete

  /// 从所有配置文件中删除 MCP 服务器
  void deleteServer(String id) {
    _removeCodexMCPServer(id);
    _removeJSONMCPServer(_claudeRootPath, id);
    _removeJSONMCPServer(_claudeSettingsPath, id);
    _removeJSONMCPServer(_geminiSettingsPath, id);
  }

  // MARK: - Toggle Per App

  /// 切换指定应用中的 MCP 服务器启用状态
  void toggleApp(String app, String id, bool enabled) {
    final servers = listServers();
    final matches = servers.where((s) => s.id == id).toList();
    if (matches.isEmpty) return;
    final spec = matches.first.spec;

    switch (app) {
      case 'claude':
        if (enabled) {
          _upsertJSONMCPServer(_claudeRootPath, id, spec);
          _upsertJSONMCPServer(_claudeSettingsPath, id, spec);
        } else {
          _removeJSONMCPServer(_claudeRootPath, id);
          _removeJSONMCPServer(_claudeSettingsPath, id);
        }
        break;
      case 'codex':
        if (enabled) {
          final formData = MCPFormData(
            id: id,
            transport: matches.first.transport,
            command: spec['command'] as String? ?? '',
            args: (spec['args'] as List?)?.cast<String>() ?? [],
            url: spec['url'] as String? ?? '',
          );
          _upsertCodexMCPServer(id, matches.first.transport, formData);
        } else {
          _removeCodexMCPServer(id);
        }
        break;
      case 'gemini':
        if (enabled) {
          _upsertJSONMCPServer(_geminiSettingsPath, id, spec);
        } else {
          _removeJSONMCPServer(_geminiSettingsPath, id);
        }
        break;
    }
  }

  // MARK: - JSON Config Read/Write

  Map<String, Map<String, dynamic>>? _readJSONMCPServers(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final servers = root['mcpServers'] as Map<String, dynamic>?;
      if (servers == null) return null;
      return servers.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return null;
    }
  }

  void _upsertJSONMCPServer(String filePath, String id, Map<String, dynamic> spec) {
    try {
      final file = File(filePath);
      Map<String, dynamic> root = {};
      if (file.existsSync()) {
        root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }

      final servers = Map<String, dynamic>.from(root['mcpServers'] as Map? ?? {});
      servers[id] = spec;
      root['mcpServers'] = servers;

      _ensureDir(file);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
    } catch (_) {}
  }

  void _removeJSONMCPServer(String filePath, String id) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;
      final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final servers = Map<String, dynamic>.from(root['mcpServers'] as Map? ?? {});
      if (servers.remove(id) == null) return;

      if (servers.isEmpty) {
        root.remove('mcpServers');
      } else {
        root['mcpServers'] = servers;
      }
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
    } catch (_) {}
  }

  // MARK: - Codex TOML Read/Write

  Map<String, Map<String, dynamic>>? _readCodexMCPServers() {
    try {
      final file = File(_codexConfigPath);
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync().trim();
      if (content.isEmpty) return null;

      final result = <String, Map<String, dynamic>>{};
      final lines = content.split('\n');
      String? currentServer;
      var currentSpec = <String, dynamic>{};

      for (final line in lines) {
        final trimmed = line.trim();

        // 检测 [mcp_servers.xxx] 段头
        final match = RegExp(r'^\[mcp_servers\.(.+)\]$').firstMatch(trimmed);
        if (match != null) {
          if (currentServer != null) result[currentServer] = currentSpec;
          currentServer = match.group(1)!;
          currentSpec = {};
          continue;
        }

        // 遇到其他段头，结束当前 server
        if (trimmed.startsWith('[') && currentServer != null) {
          result[currentServer] = currentSpec;
          currentServer = null;
          currentSpec = {};
          continue;
        }

        // 解析键值对
        if (currentServer != null) {
          final eqIdx = trimmed.indexOf('=');
          if (eqIdx > 0) {
            final key = trimmed.substring(0, eqIdx).trim();
            final rawValue = trimmed.substring(eqIdx + 1).trim();

            if (rawValue.startsWith('"') && rawValue.endsWith('"')) {
              currentSpec[key] = rawValue.substring(1, rawValue.length - 1);
            } else if (rawValue.startsWith('[')) {
              final inner = rawValue.substring(1, rawValue.length - 1);
              final items = inner.split(',').map((item) {
                final t = item.trim();
                if (t.startsWith('"') && t.endsWith('"')) {
                  return t.substring(1, t.length - 1);
                }
                return t;
              }).where((s) => s.isNotEmpty).toList();
              currentSpec[key] = items;
            }
          }
        }
      }

      if (currentServer != null) result[currentServer] = currentSpec;
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  void _upsertCodexMCPServer(String id, String transport, MCPFormData data) {
    try {
      var content = '';
      final file = File(_codexConfigPath);
      if (file.existsSync()) content = file.readAsStringSync();

      // 移除已有同名段
      content = _removeTomlSection(content, 'mcp_servers.$id');

      // 追加新段
      var section = '\n[mcp_servers.$id]\n';
      if (transport == 'stdio') {
        final command = data.command.trim();
        section += 'command = "${_escapeToml(command)}"\n';
        if (data.args.isNotEmpty) {
          final argsStr = data.args.map((a) => '"${_escapeToml(a)}"').join(', ');
          section += 'args = [$argsStr]\n';
        }
      } else {
        section += 'type = "$transport"\n';
        final url = data.url.trim();
        section += 'url = "${_escapeToml(url)}"\n';
      }
      content += section;

      _ensureDir(file);
      file.writeAsStringSync(content);
    } catch (_) {}
  }

  void _removeCodexMCPServer(String id) {
    try {
      final file = File(_codexConfigPath);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();
      final newContent = _removeTomlSection(content, 'mcp_servers.$id');
      if (newContent != content) {
        file.writeAsStringSync(newContent);
      }
    } catch (_) {}
  }

  // MARK: - TOML Helpers

  String _removeTomlSection(String content, String sectionName) {
    final lines = content.split('\n');
    final result = <String>[];
    var skipping = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '[$sectionName]') {
        skipping = true;
        continue;
      }
      if (skipping && trimmed.startsWith('[')) {
        skipping = false;
      }
      if (!skipping) {
        result.add(line);
      }
    }

    // 去除尾部连续空行
    while (result.isNotEmpty && result.last.trim().isEmpty) {
      result.removeLast();
    }

    return result.join('\n');
  }

  String _escapeToml(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  // MARK: - Inference Helpers

  String _inferTransport(Map<String, dynamic> spec) {
    if (spec.containsKey('type')) return spec['type'] as String;
    if (spec.containsKey('command')) return 'stdio';
    if (spec.containsKey('httpUrl')) return 'http';
    if (spec.containsKey('url')) return 'sse';
    return 'unknown';
  }

  // MARK: - Utils

  void _ensureDir(File file) {
    final dir = file.parent;
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }
}

/// 合并条目（内部使用）
class _MergedEntry {
  Map<String, dynamic> spec;
  final Set<String> sources = {};
  _MergedEntry(this.spec);
}
