import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;

import '../../app/app_state.dart';
import '../../models/provider.dart';
/// Provider 管理设置页
class ProviderSettingsView extends StatefulWidget {
  final String tool;
  final String toolName;

  const ProviderSettingsView({
    super.key,
    required this.tool,
    required this.toolName,
  });

  @override
  State<ProviderSettingsView> createState() => _ProviderSettingsViewState();
}

class _ProviderSettingsViewState extends State<ProviderSettingsView> {
  List<Provider> get _toolProviders {
    final appState = p.Provider.of<AppState>(context, listen: true);
    return appState.providers.where((pr) => pr.tool == widget.tool).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = p.Provider.of<AppState>(context, listen: true);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 已配置列表
        Row(
          children: [
            Text(
              '已配置 (${_toolProviders.length})',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const Spacer(),
            Text(
              '点击左侧圆点切换激活',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_toolProviders.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                children: [
                  Text('暂无供应商', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('点击下方按钮添加', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          )
        else
          ...List.generate(_toolProviders.length, (i) {
            final provider = _toolProviders[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ProviderRow(
                provider: provider,
                onSwitch: () => appState.switchProvider(provider.id!),
                onEdit: () => _showEditDialog(provider),
                onDelete: () => _showDeleteConfirm(provider),
              ),
            );
          }),

        const SizedBox(height: 16),

        // 操作按钮
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('手动添加供应商'),
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
      builder: (ctx) => _ProviderFormDialog(
        tool: widget.tool,
        toolName: widget.toolName,
        onSave: () {
          p.Provider.of<AppState>(context, listen: false).loadProviders();
        },
      ),
    );
  }

  void _showEditDialog(Provider provider) {
    showDialog(
      context: context,
      builder: (ctx) => _ProviderFormDialog(
        tool: widget.tool,
        toolName: widget.toolName,
        provider: provider,
        onSave: () {
          p.Provider.of<AppState>(context, listen: false).loadProviders();
        },
      ),
    );
  }

  void _showDeleteConfirm(Provider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除供应商 "${provider.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              p.Provider.of<AppState>(context, listen: false).deleteProvider(provider.id!);
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
      builder: (ctx) => _PresetPickerDialog(
        tool: widget.tool,
        onSave: () {
          p.Provider.of<AppState>(context, listen: false).loadProviders();
        },
      ),
    );
  }
}

/// Provider 行
class _ProviderRow extends StatelessWidget {
  final Provider provider;
  final VoidCallback onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProviderRow({
    required this.provider,
    required this.onSwitch,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 激活状态指示
          InkWell(
            onTap: onSwitch,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              provider.isActive ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: provider.isActive ? Colors.green : Colors.grey[400],
            ),
          ),
          const SizedBox(width: 10),

          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      provider.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: provider.isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (provider.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '使用中',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.green),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (provider.model.isNotEmpty) ...[
                      Text(
                        provider.model,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      provider.maskedApiKey,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 操作按钮
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
}

/// Provider 添加/编辑表单对话框
class _ProviderFormDialog extends StatefulWidget {
  final String tool;
  final String toolName;
  final Provider? provider;
  final VoidCallback onSave;

  const _ProviderFormDialog({
    required this.tool,
    required this.toolName,
    this.provider,
    required this.onSave,
  });

  @override
  State<_ProviderFormDialog> createState() => _ProviderFormDialogState();
}

class _ProviderFormDialogState extends State<_ProviderFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _apiBaseCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _extraEnvCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _haikuCtrl;
  late TextEditingController _sonnetCtrl;
  late TextEditingController _opusCtrl;
  String? _errorMessage;

  bool get _isEditing => widget.provider != null;

  @override
  void initState() {
    super.initState();
    final pr = widget.provider;
    _nameCtrl = TextEditingController(text: pr?.name ?? '');
    _apiKeyCtrl = TextEditingController(text: pr?.apiKey ?? '');
    _apiBaseCtrl = TextEditingController(text: pr?.apiBase ?? '');
    _modelCtrl = TextEditingController(text: pr?.model ?? '');
    _extraEnvCtrl = TextEditingController(text: pr?.extraEnv ?? '{}');
    _notesCtrl = TextEditingController(text: pr?.notes ?? '');

    final extra = pr?.extraEnvDict;
    _haikuCtrl = TextEditingController(text: extra?['ANTHROPIC_DEFAULT_HAIKU_MODEL'] ?? '');
    _sonnetCtrl = TextEditingController(text: extra?['ANTHROPIC_DEFAULT_SONNET_MODEL'] ?? '');
    _opusCtrl = TextEditingController(text: extra?['ANTHROPIC_DEFAULT_OPUS_MODEL'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _apiBaseCtrl.dispose();
    _modelCtrl.dispose();
    _extraEnvCtrl.dispose();
    _notesCtrl.dispose();
    _haikuCtrl.dispose();
    _sonnetCtrl.dispose();
    _opusCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errorMessage = null);

    final formData = ProviderFormData(
      name: _nameCtrl.text.trim(),
      tool: widget.tool,
      apiKey: _apiKeyCtrl.text.trim(),
      apiBase: _apiBaseCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      extraEnv: _extraEnvCtrl.text.trim(),
      icon: widget.provider?.icon,
      iconColor: widget.provider?.iconColor,
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      category: widget.provider?.category,
      presetId: widget.provider?.presetId,
      haikuModel: _haikuCtrl.text.trim(),
      sonnetModel: _sonnetCtrl.text.trim(),
      opusModel: _opusCtrl.text.trim(),
    );

    try {
      final appState = p.Provider.of<AppState>(context, listen: false);
      if (_isEditing) {
        await appState.providerService.updateProvider(widget.provider!.id!, formData);
      } else {
        await appState.providerService.createProvider(formData);
      }
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _isEditing ? '编辑 ${widget.toolName} 供应商' : '添加 ${widget.toolName} 供应商',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 表单
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormField(label: '名称 *', controller: _nameCtrl, hint: '如：官方 Claude'),
                    _FormField(label: 'API Key *', controller: _apiKeyCtrl, hint: 'sk-xxx', obscure: true),
                    _FormField(label: 'API 端点', controller: _apiBaseCtrl, hint: '空=使用官方默认端点'),
                    _FormField(label: '主模型', controller: _modelCtrl, hint: '空=使用默认模型'),
                    if (widget.tool == 'claude_code') ...[
                      _FormField(label: 'Haiku 模型', controller: _haikuCtrl, hint: '空=默认'),
                      _FormField(label: 'Sonnet 模型', controller: _sonnetCtrl, hint: '空=默认'),
                      _FormField(label: 'Opus 模型', controller: _opusCtrl, hint: '空=默认'),
                    ],
                    _FormField(label: '额外环境变量 (JSON)', controller: _extraEnvCtrl, hint: '{}', maxLines: 3),
                    _FormField(label: '备注', controller: _notesCtrl, hint: '可选'),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _nameCtrl.text.trim().isEmpty || _apiKeyCtrl.text.trim().isEmpty
                        ? null
                        : _save,
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

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final int maxLines;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.obscure = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            obscureText: obscure,
            maxLines: obscure ? 1 : maxLines,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 预设选择对话框
class _PresetPickerDialog extends StatefulWidget {
  final String tool;
  final VoidCallback onSave;

  const _PresetPickerDialog({required this.tool, required this.onSave});

  @override
  State<_PresetPickerDialog> createState() => _PresetPickerDialogState();
}

class _PresetPickerDialogState extends State<_PresetPickerDialog> {
  ProviderPreset? _selectedPreset;
  final _apiKeyCtrl = TextEditingController();
  String? _errorMessage;

  List<ProviderPreset> get _filteredPresets {
    return ProviderPreset.presets.where((p) => p.tool == widget.tool).toList();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFromPreset() async {
    if (_selectedPreset == null) return;
    setState(() => _errorMessage = null);

    final formData = ProviderFormData(
      name: _selectedPreset!.name,
      tool: _selectedPreset!.tool,
      apiKey: _apiKeyCtrl.text.trim(),
      apiBase: _selectedPreset!.apiBase,
      model: _selectedPreset!.defaultModel,
      icon: _selectedPreset!.icon,
      iconColor: _selectedPreset!.iconColor,
      presetId: _selectedPreset!.id,
    );

    try {
      final appState = p.Provider.of<AppState>(context, listen: false);
      await appState.providerService.createProvider(formData);
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('从预设添加', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredPresets.length,
                itemBuilder: (context, i) {
                  final preset = _filteredPresets[i];
                  final isSelected = _selectedPreset?.id == preset.id;
                  return ListTile(
                    selected: isSelected,
                    title: Text(preset.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      preset.apiBase.isEmpty ? '官方默认端点' : preset.apiBase,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(preset.defaultModel, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check, color: Colors.green, size: 16),
                        ],
                      ],
                    ),
                    onTap: () => setState(() => _selectedPreset = preset),
                  );
                },
              ),
            ),
            if (_selectedPreset != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyCtrl,
                        obscureText: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: '输入 API Key',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _apiKeyCtrl.text.trim().isEmpty ? null : _addFromPreset,
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
