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
      name: 'mcp-server-fetch',
      description: '通过 HTTP 获取网页内容并提取文本。',
      command: 'uvx',
      args: ['mcp-server-fetch'],
      tags: ['stdio', 'http', 'web'],
    ),
    MCPPreset(
      id: 'time',
      name: '@modelcontextprotocol/server-time',
      description: '获取当前时间和时区转换。',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-time'],
      tags: ['stdio', 'time', 'utility'],
    ),
    MCPPreset(
      id: 'memory',
      name: '@modelcontextprotocol/server-memory',
      description: '基于知识图谱的持久化记忆存储。',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-memory'],
      tags: ['stdio', 'memory', 'graph'],
    ),
    MCPPreset(
      id: 'sequential-thinking',
      name: '@modelcontextprotocol/server-sequential-thinking',
      description: '逐步推理与结构化思考。',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-sequential-thinking'],
      tags: ['stdio', 'thinking', 'reasoning'],
    ),
    MCPPreset(
      id: 'context7',
      name: '@upstash/context7-mcp',
      description: '从文档库中检索代码上下文和示例。',
      command: 'npx',
      args: ['-y', '@upstash/context7-mcp'],
      tags: ['stdio', 'docs', 'search'],
    ),
  ];
}
