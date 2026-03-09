import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于页
class AboutSettingsView extends StatelessWidget {
  const AboutSettingsView({super.key});

  static const String _version = '1.0.0';
  static const String _build = '1';
  static const String _qqGroup = '1076321843';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo + 版本
        Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ACode',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '一站式 AI 编程终端',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              Text(
                '版本 $_version ($_build)',
                style: TextStyle(fontSize: 12, fontFamily: 'Consolas', color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '集成多家大模型，让你在一个窗口内完成代码编写、调试与部署',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // 信息
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              _InfoRow(label: '平台', value: 'Windows (Flutter)'),
              const Divider(height: 16),
              _InfoRow(label: '版本号', value: 'v$_version'),
              const Divider(height: 16),
              _InfoRow(label: 'Build', value: _build),
              const Divider(height: 16),
              Row(
                children: [
                  const Text('QQ 群', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: _qqGroup));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('群号已复制'), duration: Duration(seconds: 1)),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _qqGroup,
                          style: TextStyle(fontSize: 13, fontFamily: 'Consolas', color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy, size: 12, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 链接
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              _LinkRow(
                icon: Icons.language,
                label: '官网',
                url: 'https://acode.anna.tf',
              ),
              const Divider(height: 16),
              _LinkRow(
                icon: Icons.code,
                label: 'GitHub',
                url: 'https://github.com/ACode-Project/acode',
              ),
              const Divider(height: 16),
              _LinkRow(
                icon: Icons.bug_report,
                label: '反馈问题',
                url: 'https://github.com/ACode-Project/acode/issues',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 版权
        Center(
          child: Text(
            '© 2025 ACode Project. All rights reserved.',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontFamily: 'Consolas', color: Colors.grey[500]),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _LinkRow({required this.icon, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Icon(Icons.open_in_new, size: 14, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
