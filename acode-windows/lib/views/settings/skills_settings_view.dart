import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/skill.dart';
import '../../services/skills_service.dart';

/// 技能管理设置页
class SkillsSettingsView extends StatefulWidget {
  const SkillsSettingsView({super.key});

  @override
  State<SkillsSettingsView> createState() => _SkillsSettingsViewState();
}

class _SkillsSettingsViewState extends State<SkillsSettingsView> {
  List<Skill> _skills = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _skills = SkillsService.shared.listSkills());
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
              '已定义 (${_skills.length})',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const Spacer(),
            Text(
              '技能会同步写入各 CLI 的指令文件',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_skills.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Column(
                children: [
                  Text('暂无自定义技能', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('技能可以为 AI 添加自定义指令和上下文', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          )
        else
          ...List.generate(_skills.length, (i) {
            final skill = _skills[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SkillCard(
                skill: skill,
                onEdit: () => _showEditDialog(skill),
                onDelete: () => _showDeleteConfirm(skill),
                onToggleApp: (app, enabled) {
                  SkillsService.shared.toggleSkillApp(skill, app, enabled);
                  _refresh();
                },
              ),
            );
          }),

        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _showAddDialog(),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加技能'),
        ),
      ],
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SkillFormDialog(onSave: _refresh),
    );
  }

  void _showEditDialog(Skill skill) {
    showDialog(
      context: context,
      builder: (ctx) => _SkillFormDialog(skill: skill, onSave: _refresh),
    );
  }

  void _showDeleteConfirm(Skill skill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除技能 "${skill.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SkillsService.shared.deleteSkill(skill);
              _refresh();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 技能卡片
class _SkillCard extends StatelessWidget {
  final Skill skill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String app, bool enabled) onToggleApp;

  const _SkillCard({
    required this.skill,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleApp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(skill.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (skill.description.isNotEmpty)
                      Text(skill.description, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
          const SizedBox(height: 8),
          // 应用启用开关
          Row(
            children: [
              _AppToggle(
                label: 'Claude',
                enabled: skill.enabledApps.contains('claude'),
                color: const Color(0xFFD4915D),
                onChanged: (v) => onToggleApp('claude', v),
              ),
              const SizedBox(width: 8),
              _AppToggle(
                label: 'Codex',
                enabled: skill.enabledApps.contains('codex'),
                color: const Color(0xFF00A67E),
                onChanged: (v) => onToggleApp('codex', v),
              ),
              const SizedBox(width: 8),
              _AppToggle(
                label: 'Gemini',
                enabled: skill.enabledApps.contains('gemini'),
                color: const Color(0xFF4285F4),
                onChanged: (v) => onToggleApp('gemini', v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppToggle extends StatelessWidget {
  final String label;
  final bool enabled;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _AppToggle({
    required this.label,
    required this.enabled,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!enabled),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: enabled ? color : Colors.grey[400],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: enabled ? color : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 技能表单对话框
class _SkillFormDialog extends StatefulWidget {
  final Skill? skill;
  final VoidCallback onSave;

  const _SkillFormDialog({this.skill, required this.onSave});

  @override
  State<_SkillFormDialog> createState() => _SkillFormDialogState();
}

class _SkillFormDialogState extends State<_SkillFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _contentCtrl;

  bool get _isEditing => widget.skill != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.skill?.name ?? '');
    _descCtrl = TextEditingController(text: widget.skill?.description ?? '');
    _contentCtrl = TextEditingController(text: widget.skill?.content ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final skill = Skill(
      id: widget.skill?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      content: _contentCtrl.text,
      enabledApps: widget.skill?.enabledApps,
    );
    SkillsService.shared.saveSkill(skill);
    widget.onSave();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 550,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _isEditing ? '编辑技能' : '添加技能',
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
                  const Text('名称 *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '如：代码审查规范',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('描述', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _descCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '简短描述技能作用',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('指令内容 *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _contentCtrl,
                    maxLines: 10,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Cascadia Code, Consolas'),
                    decoration: const InputDecoration(
                      hintText: '在这里输入给 AI 的自定义指令...',
                      isDense: true,
                      contentPadding: EdgeInsets.all(10),
                      border: OutlineInputBorder(),
                    ),
                  ),
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
                    onPressed: _nameCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty
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
