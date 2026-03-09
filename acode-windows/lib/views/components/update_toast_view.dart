import 'package:flutter/material.dart';

/// 底部更新通知 Toast
class UpdateToastView extends StatelessWidget {
  final String version;
  final String? notes;
  final bool isDownloaded;
  final bool isDownloading;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  const UpdateToastView({
    super.key,
    required this.version,
    this.notes,
    this.isDownloaded = false,
    this.isDownloading = false,
    required this.onUpdate,
    required this.onDismiss,
  });

  String get _titleText {
    if (isDownloaded) return 'v$version 更新已就绪';
    if (isDownloading) return '正在下载 v$version...';
    return '新版本 v$version 可用';
  }

  String get _buttonText => isDownloaded ? '重启更新' : '查看更新';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D2D2D).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? const Color(0xFF3C3C3C).withValues(alpha: 0.3)
              : const Color(0xFFE0E0E0).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // 图标
          if (isDownloading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isDownloaded ? Icons.check_circle : Icons.arrow_circle_down,
              size: 20,
              color: Colors.green,
            ),
          const SizedBox(width: 12),

          // 文本
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _titleText,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (notes != null && notes!.isNotEmpty)
                  Text(
                    notes!.length > 80 ? '${notes!.substring(0, 80)}...' : notes!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 按钮
          ElevatedButton(
            onPressed: isDownloading ? null : onUpdate,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(_buttonText),
          ),
          const SizedBox(width: 8),

          // 关闭
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(10),
            child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
