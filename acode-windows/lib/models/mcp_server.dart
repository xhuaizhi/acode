/// MCP 服务器数据模型
class MCPServer {
  final String id;
  final String transport; // stdio, http, sse
  final Map<String, dynamic> spec;
  final List<String> sources;

  MCPServer({
    required this.id,
    this.transport = 'stdio',
    this.spec = const {},
    this.sources = const [],
  });

  /// 概要信息
  String get summary {
    switch (transport) {
      case 'stdio':
        final cmd = spec['command'] as String? ?? '';
        final args = (spec['args'] as List?)?.join(' ') ?? '';
        return '$cmd $args'.trim();
      case 'http':
      case 'sse':
        return spec['url'] as String? ?? '';
      default:
        return '';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transport': transport,
      'spec': spec,
      'sources': sources,
    };
  }

  factory MCPServer.fromMap(Map<String, dynamic> map) {
    return MCPServer(
      id: map['id'] as String? ?? '',
      transport: map['transport'] as String? ?? 'stdio',
      spec: Map<String, dynamic>.from(map['spec'] as Map? ?? {}),
      sources: (map['sources'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// MCP 表单数据
class MCPFormData {
  final String id;
  final String transport;
  final String command;
  final List<String> args;
  final String url;

  MCPFormData({
    required this.id,
    this.transport = 'stdio',
    this.command = '',
    this.args = const [],
    this.url = '',
  });

  Map<String, dynamic> toSpec() {
    if (transport == 'stdio') {
      return {
        'command': command,
        'args': args,
      };
    } else {
      return {
        'url': url,
      };
    }
  }
}

/// MCP 预设
class MCPPreset {
  final String id;
  final String name;
  final String description;
  final String transport;
  final String command;
  final List<String> args;
  final List<String> tags;

  const MCPPreset({
    required this.id,
    required this.name,
    required this.description,
    this.transport = 'stdio',
    this.command = '',
    this.args = const [],
    this.tags = const [],
  });

  static const List<MCPPreset> presets = [
    MCPPreset(
      id: 'fetch',
      name: 'Web Fetch',
      description: '抓取网页内容，为 AI 提供实时网页数据',
      command: 'uvx',
      args: ['mcp-server-fetch'],
      tags: ['网络', '数据获取'],
    ),
    MCPPreset(
      id: 'memory',
      name: 'Memory',
      description: '为 AI 提供持久化记忆存储能力',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-memory'],
      tags: ['记忆', '存储'],
    ),
    MCPPreset(
      id: 'filesystem',
      name: 'Filesystem',
      description: '安全的文件系统访问，可限制目录范围',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-filesystem'],
      tags: ['文件', '系统'],
    ),
    MCPPreset(
      id: 'time',
      name: 'Time',
      description: '获取当前时间和时区信息',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-time'],
      tags: ['工具', '时间'],
    ),
    MCPPreset(
      id: 'sequential-thinking',
      name: 'Sequential Thinking',
      description: '为 AI 提供逐步推理和思考链能力',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-sequential-thinking'],
      tags: ['推理', '思考'],
    ),
  ];
}
