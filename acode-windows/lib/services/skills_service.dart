import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/skill.dart';

/// 技能管理服务 — 持久化 JSON + 写入 CLI 指令文件
class SkillsService {
  static final SkillsService shared = SkillsService._();
  SkillsService._();

  String get _skillsFilePath {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    return p.join(home, '.acode', 'skills.json');
  }

  /// 获取所有技能
  List<Skill> listSkills() {
    try {
      final file = File(_skillsFilePath);
      if (!file.existsSync()) return [];
      final json = jsonDecode(file.readAsStringSync());
      if (json is List) {
        return json.map((e) => Skill.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 保存技能
  void saveSkill(Skill skill) {
    final skills = listSkills();
    final idx = skills.indexWhere((s) => s.id == skill.id);
    if (idx >= 0) {
      skills[idx] = skill;
    } else {
      skills.add(skill);
    }
    _persistSkills(skills);
    _syncToTools(skills);
  }

  /// 删除技能
  void deleteSkill(Skill skill) {
    final skills = listSkills();
    skills.removeWhere((s) => s.id == skill.id);
    _persistSkills(skills);
    _syncToTools(skills);
  }

  /// 切换技能对某个应用的启用状态
  void toggleSkillApp(Skill skill, String app, bool enabled) {
    final newApps = Set<String>.from(skill.enabledApps);
    if (enabled) {
      newApps.add(app);
    } else {
      newApps.remove(app);
    }
    saveSkill(skill.copyWith(enabledApps: newApps));
  }

  /// 持久化技能列表到 JSON 文件
  void _persistSkills(List<Skill> skills) {
    try {
      final file = File(_skillsFilePath);
      final dir = file.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(
          skills.map((s) => s.toMap()).toList(),
        ),
      );
    } catch (_) {}
  }

  /// 同步技能到各 CLI 工具的指令文件
  void _syncToTools(List<Skill> skills) {
    _syncToClaude(skills);
    _syncToCodex(skills);
    _syncToGemini(skills);
  }

  void _syncToClaude(List<Skill> skills) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    _syncInstructionFile(
      p.join(home, '.claude', 'CLAUDE.md'),
      skills.where((s) => s.enabledApps.contains('claude')).toList(),
    );
  }

  void _syncToCodex(List<Skill> skills) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    _syncInstructionFile(
      p.join(home, '.codex', 'instructions.md'),
      skills.where((s) => s.enabledApps.contains('codex')).toList(),
    );
  }

  void _syncToGemini(List<Skill> skills) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    _syncInstructionFile(
      p.join(home, '.gemini', 'GEMINI.md'),
      skills.where((s) => s.enabledApps.contains('gemini')).toList(),
    );
  }

  /// 在指令文件中替换 ACode Skills 区块（与 Mac 版对齐）
  void _syncInstructionFile(String filePath, List<Skill> skills) {
    const marker = '<!-- ACode Skills -->';
    const endMarker = '<!-- /ACode Skills -->';

    try {
      final file = File(filePath);
      final dir = file.parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);

      var existing = file.existsSync() ? file.readAsStringSync() : '';

      // 移除旧的 ACode Skills 区块（兼容旧格式 Start/End）
      existing = _removeSkillBlock(existing, marker, endMarker);
      existing = _removeSkillBlock(existing, '<!-- ACode Skills Start -->', '<!-- ACode Skills End -->');
      existing = existing.trim();

      // 如果没有技能需要写入，只保留清理后的内容
      if (skills.isEmpty) {
        if (existing.isNotEmpty) file.writeAsStringSync(existing);
        return;
      }

      // 构建新的技能区块
      final buffer = StringBuffer('\n\n$marker\n');
      for (final skill in skills) {
        buffer.writeln('## ${skill.name}');
        if (skill.description.isNotEmpty) {
          buffer.writeln('> ${skill.description}');
        }
        buffer.writeln();
        buffer.writeln(skill.content);
        buffer.writeln();
      }
      buffer.write(endMarker);

      existing += buffer.toString();
      file.writeAsStringSync(existing);
    } catch (_) {}
  }

  String _removeSkillBlock(String content, String startMarker, String endMarker) {
    final startIdx = content.indexOf(startMarker);
    final endIdx = content.indexOf(endMarker);
    if (startIdx >= 0 && endIdx >= 0) {
      return content.substring(0, startIdx) + content.substring(endIdx + endMarker.length);
    }
    return content;
  }
}
