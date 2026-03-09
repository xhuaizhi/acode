import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 更新检查器 — 检查/下载/安装更新
class UpdateChecker extends ChangeNotifier {
  static const String _apiBase = 'https://acode.anna.tf';
  static const String _currentVersion = '1.0.0';

  bool isChecking = false;
  bool hasUpdate = false;
  bool isDownloading = false;
  bool isDownloaded = false;
  String? latestVersion;
  String? downloadUrl;
  String? releaseNotes;
  String? _downloadedFilePath;
  String? _expectedSha256;

  /// 检查更新
  Future<void> checkForUpdates() async {
    if (isChecking) return;
    isChecking = true;
    hasUpdate = false;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_apiBase/api/v1/update/check?version=$_currentVersion&platform=windows'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final hasUpdateFlag = data['has_update'] as bool? ?? false;
        if (hasUpdateFlag) {
          latestVersion = data['version'] as String?;
          downloadUrl = data['download_url'] as String?;
          releaseNotes = data['notes'] as String?;
          _expectedSha256 = data['sha256'] as String?;
          hasUpdate = true;
        }
      }
    } catch (_) {
      // 网络错误静默处理
    } finally {
      isChecking = false;
      notifyListeners();
    }
  }

  /// 下载更新
  Future<void> downloadUpdate() async {
    if (isDownloading || downloadUrl == null) return;
    isDownloading = true;
    isDownloaded = false;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(downloadUrl!))
          .timeout(const Duration(minutes: 10));

      if (response.statusCode == 200) {
        // SHA256 校验
        if (_expectedSha256 != null) {
          final digest = sha256.convert(response.bodyBytes);
          if (digest.toString() != _expectedSha256) {
            throw Exception('SHA256 校验失败');
          }
        }

        // 写入临时目录
        final tempDir = await getTemporaryDirectory();
        final fileName = p.basename(Uri.parse(downloadUrl!).path);
        final filePath = p.join(tempDir.path, fileName);
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        _downloadedFilePath = filePath;
        isDownloaded = true;
      }
    } catch (_) {
      // 下载失败
    } finally {
      isDownloading = false;
      notifyListeners();
    }
  }

  /// 安装并重启
  void installAndRestart() {
    if (_downloadedFilePath == null) return;
    try {
      // Windows: 启动安装程序并退出当前应用
      Process.start(_downloadedFilePath!, [], mode: ProcessStartMode.detached);
      exit(0);
    } catch (_) {}
  }

  /// 版本比较
  bool _isNewerVersion(String remote, String local) {
    final remoteParts = remote.split('.').map(int.tryParse).toList();
    final localParts = local.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final r = (i < remoteParts.length ? remoteParts[i] : 0) ?? 0;
      final l = (i < localParts.length ? localParts[i] : 0) ?? 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }
}
