import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_state.dart';

/// 关于页
class AboutSettingsView extends StatefulWidget {
  const AboutSettingsView({super.key});

  @override
  State<AboutSettingsView> createState() => _AboutSettingsViewState();
}

class _AboutSettingsViewState extends State<AboutSettingsView> {
  static const String _version = '1.0.0';
  static const String _build = '1';
  static const String _qqGroup = '1076321843';

  @override
  void initState() {
    super.initState();
    // 进入关于页时自动检查更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.updateChecker.checkForUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);

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
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ACode',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '版本 $_version ($_build)',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '一站式 AI 编程终端，集成多家大模型，让你在一个窗口内完成代码编写、调试与部署',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // 信息
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 0.5),
          ),
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
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 0.5),
          ),
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

        // 版本更新
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 0.5),
          ),
          child: _buildUpdateSection(appState),
        ),

        const SizedBox(height: 24),

        // 版权
        Center(
          child: Text(
            'Copyright \u00A9 2025 ACode. All rights reserved.',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateSection(AppState appState) {
    final checker = appState.updateChecker;

    if (checker.isChecking) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('正在检查更新...', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      );
    }

    if (checker.hasUpdate && checker.latestVersion != null) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_downward, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                '新版本 v${checker.latestVersion} 可用',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (checker.releaseNotes != null && checker.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              checker.releaseNotes!,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (checker.isDownloading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (checker.isDownloaded)
                ElevatedButton.icon(
                  onPressed: () => checker.installAndRestart(),
                  icon: const Icon(Icons.install_desktop, size: 16),
                  label: const Text('安装更新'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => checker.downloadUpdate(),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('下载更新'),
                ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => checker.checkForUpdates(),
                child: const Text('重新检查'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 16, color: Colors.green),
            const SizedBox(width: 6),
            Text('已是最新版本', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => checker.checkForUpdates(),
          child: const Text('检查更新'),
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
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Icon(Icons.open_in_new, size: 14, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
