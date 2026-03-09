import 'package:flutter/material.dart';

import '../../models/mcp_server.dart';
import '../../services/mcp_service.dart';

/// MCP 服务器管理设置页
class MCPSettingsView extends StatefulWidget {
  const MCPSettingsView({super.key});

  @override
  State<MCPSettingsView> createState() => _MCPSettingsViewState();
}

class _MCPSettingsViewState extends State<MCPSettingsView> {
  List<MCPServer> _servers = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _servers = MCPService.shared.listServers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '已配置 (${_servers.length})',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const Spacer(),
            Text(
              '所有更改同步写入 Claude / Codex 配置',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_servers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Column(
                children: [
                  Text('暂无 MCP 服务器', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('点击下方按钮添加', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          )
        else
          ...List.generate(_servers.length, (i) {
            final server = _servers[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MCPServerRow(
                server: server,
                onEdit: () => _showEditDialog(server),
                onDelete: () => _showDeleteConfirm(server),
              ),
            );
          }),

        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('手动添加'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _showPresetDialog(),
              icon: const Icon(Icons.list, size: 16),
              label: const Text('从预设快速添加'),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _MCPFormDialog(onSave: _refresh),
    );
  }

  void _showEditDialog(MCPServer server) {
    showDialog(
      context: context,
      builder: (ctx) => _MCPFormDialog(server: server, onSave: _refresh),
    );
  }

  void _showDeleteConfirm(MCPServer server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 MCP 服务器 "${server.id}" 吗？\n将同时从 Claude 和 Codex 配置中移除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              MCPService.shared.deleteServer(server.id);
              _refresh();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showPresetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _MCPPresetDialog(onSave: _refresh),
    );
  }
}

class _MCPServerRow extends StatelessWidget {
  final MCPServer server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MCPServerRow({
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          // 圆形彩色图标 — 对标 Mac 版 MCPServerCard
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _transportColor(server.transport),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _transportIcon(server.transport),
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(server.id, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _transportColor(server.transport).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        server.transport.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _transportColor(server.transport),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  server.summary,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (server.sources.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: server.sources.map((source) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(source, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: const TextStyle(fontSize: 12),
              minimumSize: Size.zero,
            ),
            child: const Text('编辑'),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(4),
            child: Icon(Icons.delete_outline, size: 16, color: Colors.red[300]),
          ),
        ],
      ),
    );
  }

  Color _transportColor(String transport) {
    switch (transport) {
      case 'stdio':
        return Colors.blue;
      case 'http':
        return Colors.green;
      case 'sse':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _transportIcon(String transport) {
    switch (transport) {
      case 'stdio':
        return Icons.terminal;
      case 'http':
        return Icons.public;
      case 'sse':
        return Icons.cell_tower;
      default:
        return Icons.dns;
    }
  }
}

/// MCP 表单对话框
class _MCPFormDialog extends StatefulWidget {
  final MCPServer? server;
  final VoidCallback onSave;

  const _MCPFormDialog({this.server, required this.onSave});

  @override
  State<_MCPFormDialog> createState() => _MCPFormDialogState();
}

class _MCPFormDialogState extends State<_MCPFormDialog> {
  late TextEditingController _idCtrl;
  late TextEditingController _commandCtrl;
  late TextEditingController _argsCtrl;
  late TextEditingController _urlCtrl;
  String _transport = 'stdio';

  bool get _isEditing => widget.server != null;

  @override
  void initState() {
    super.initState();
    final s = widget.server;
    _idCtrl = TextEditingController(text: s?.id ?? '');
    _transport = s?.transport ?? 'stdio';
    _commandCtrl = TextEditingController(text: s?.spec['command'] as String? ?? '');
    _argsCtrl = TextEditingController(
      text: (s?.spec['args'] as List?)?.join(' ') ?? '',
    );
    _urlCtrl = TextEditingController(text: s?.spec['url'] as String? ?? '');
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _commandCtrl.dispose();
    _argsCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final formData = MCPFormData(
      id: _idCtrl.text.trim(),
      transport: _transport,
      command: _commandCtrl.text.trim(),
      args: _argsCtrl.text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList(),
      url: _urlCtrl.text.trim(),
    );
    MCPService.shared.upsertServer(formData);
    widget.onSave();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _isEditing ? '编辑 MCP 服务器' : '添加 MCP 服务器',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID
                  const Text('服务器 ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _idCtrl,
                    enabled: !_isEditing,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '如 fetch, memory',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Transport
                  const Text('传输方式', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'stdio', label: Text('stdio')),
                      ButtonSegment(value: 'http', label: Text('HTTP')),
                      ButtonSegment(value: 'sse', label: Text('SSE')),
                    ],
                    selected: {_transport},
                    onSelectionChanged: (val) => setState(() => _transport = val.first),
                  ),
                  const SizedBox(height: 12),

                  if (_transport == 'stdio') ...[
                    const Text('命令', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _commandCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: '如 npx, uvx',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('参数 (空格分隔)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _argsCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: '-y @modelcontextprotocol/server-fetch',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    const Text('URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'http://localhost:3000/sse',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _idCtrl.text.trim().isEmpty ? null : _save,
                    child: Text(_isEditing ? '保存' : '添加'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MCP 预设选择对话框
class _MCPPresetDialog extends StatelessWidget {
  final VoidCallback onSave;

  const _MCPPresetDialog({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 500,
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('从预设安装 MCP 服务器', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: MCPPreset.presets.length,
                itemBuilder: (context, i) {
                  final preset = MCPPreset.presets[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      title: Text(preset.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(preset.description, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      trailing: ElevatedButton(
                        onPressed: () {
                          final formData = MCPFormData(
                            id: preset.id,
                            transport: preset.transport,
                            command: preset.command,
                            args: preset.args,
                          );
                          MCPService.shared.upsertServer(formData);
                          onSave();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已安装 ${preset.name}')),
                          );
                        },
                        child: const Text('安装'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
