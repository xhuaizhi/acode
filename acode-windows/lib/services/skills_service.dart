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

    final enabledSkills = skills.where((s) => s.enabledApps.contains('claude'));
    final content = enabledSkills.map((s) => '# ${s.name}\n${s.content}').join('\n\n');

    try {
      final file = File(p.join(home, '.claude', 'CLAUDE.md'));
      final dir = file.parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);

      // 读取现有内容，保留用户手动添加的部分
      String existingContent = '';
      if (file.existsSync()) {
        existingContent = file.readAsStringSync();
      }

      // 标记 ACode 管理的区域
      const startMarker = '<!-- ACode Skills Start -->';
      const endMarker = '<!-- ACode Skills End -->';

      final startIdx = existingContent.indexOf(startMarker);
      final endIdx = existingContent.indexOf(endMarker);

      String newContent;
      if (startIdx >= 0 && endIdx >= 0) {
        newContent = '${existingContent.substring(0, startIdx)}$startMarker\n$content\n$endMarker${existingContent.substring(endIdx + endMarker.length)}';
      } else {
        if (existingContent.isNotEmpty) {
          newContent = '$existingContent\n\n$startMarker\n$content\n$endMarker';
        } else {
          newContent = '$startMarker\n$content\n$endMarker';
        }
      }

      file.writeAsStringSync(newContent);
    } catch (_) {}
  }

  void _syncToCodex(List<Skill> skills) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    final enabledSkills = skills.where((s) => s.enabledApps.contains('codex'));
    final content = enabledSkills.map((s) => '# ${s.name}\n${s.content}').join('\n\n');

    try {
      final file = File(p.join(home, '.codex', 'instructions.md'));
      final dir = file.parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);

      String existingContent = '';
      if (file.existsSync()) {
        existingContent = file.readAsStringSync();
      }

      const startMarker = '<!-- ACode Skills Start -->';
      const endMarker = '<!-- ACode Skills End -->';

      final startIdx = existingContent.indexOf(startMarker);
      final endIdx = existingContent.indexOf(endMarker);

      String newContent;
      if (startIdx >= 0 && endIdx >= 0) {
        newContent = '${existingContent.substring(0, startIdx)}$startMarker\n$content\n$endMarker${existingContent.substring(endIdx + endMarker.length)}';
      } else {
        if (existingContent.isNotEmpty) {
          newContent = '$existingContent\n\n$startMarker\n$content\n$endMarker';
        } else {
          newContent = '$startMarker\n$content\n$endMarker';
        }
      }

      file.writeAsStringSync(newContent);
    } catch (_) {}
  }

  void _syncToGemini(List<Skill> skills) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;

    final enabledSkills = skills.where((s) => s.enabledApps.contains('gemini'));
    final content = enabledSkills.map((s) => '# ${s.name}\n${s.content}').join('\n\n');

    try {
      final file = File(p.join(home, '.gemini', 'GEMINI.md'));
      final dir = file.parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);

      String existingContent = '';
      if (file.existsSync()) {
        existingContent = file.readAsStringSync();
      }

      const startMarker = '<!-- ACode Skills Start -->';
      const endMarker = '<!-- ACode Skills End -->';

      final startIdx = existingContent.indexOf(startMarker);
      final endIdx = existingContent.indexOf(endMarker);

      String newContent;
      if (startIdx >= 0 && endIdx >= 0) {
        newContent = '${existingContent.substring(0, startIdx)}$startMarker\n$content\n$endMarker${existingContent.substring(endIdx + endMarker.length)}';
      } else {
        if (existingContent.isNotEmpty) {
          newContent = '$existingContent\n\n$startMarker\n$content\n$endMarker';
        } else {
          newContent = '$startMarker\n$content\n$endMarker';
        }
      }

      file.writeAsStringSync(newContent);
    } catch (_) {}
  }
}
