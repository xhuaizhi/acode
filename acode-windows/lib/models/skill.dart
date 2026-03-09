/// 技能数据模型 — 自定义指令
class Skill {
  final String id;
  final String name;
  final String description;
  final String content;
  final Set<String> enabledApps; // claude, codex, gemini

  Skill({
    required this.id,
    required this.name,
    this.description = '',
    this.content = '',
    Set<String>? enabledApps,
  }) : enabledApps = enabledApps ?? {'claude', 'codex', 'gemini'};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'content': content,
      'enabledApps': enabledApps.toList(),
    };
  }

  factory Skill.fromMap(Map<String, dynamic> map) {
    return Skill(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      content: map['content'] as String? ?? '',
      enabledApps: (map['enabledApps'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          {'claude', 'codex', 'gemini'},
    );
  }

  Skill copyWith({
    String? name,
    String? description,
    String? content,
    Set<String>? enabledApps,
  }) {
    return Skill(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      content: content ?? this.content,
      enabledApps: enabledApps ?? this.enabledApps,
    );
  }
}
