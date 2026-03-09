import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../utils/syntax_highlighter.dart';

/// 文件编辑器 — 支持文本编辑、图片预览、二进制文件提示
class FileEditorView extends StatefulWidget {
  final String filePath;

  const FileEditorView({super.key, required this.filePath});

  @override
  State<FileEditorView> createState() => _FileEditorViewState();
}

class _FileEditorViewState extends State<FileEditorView> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _isModified = false;
  _FileContentType _fileType = _FileContentType.text;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _loadFile();
  }

  @override
  void didUpdateWidget(FileEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadFile();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static const _imageExtensions = {
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff', 'tif', 'webp', 'svg', 'ico', 'heic', 'heif',
  };

  static const _textExtensions = {
    'swift', 'js', 'ts', 'jsx', 'tsx', 'json', 'md', 'txt', 'py',
    'html', 'css', 'scss', 'less', 'xml', 'yaml', 'yml', 'toml',
    'sh', 'bash', 'zsh', 'fish', 'rs', 'go', 'c', 'h', 'cpp', 'm',
    'java', 'kt', 'rb', 'php', 'sql', 'r', 'lua', 'vim', 'conf',
    'ini', 'cfg', 'env', 'gitignore', 'dockerignore', 'makefile',
    'dockerfile', 'readme', 'license', 'changelog', 'editorconfig',
    'lock', 'log', 'csv', 'tsv', 'dart', 'gradle', 'properties',
    '',
  };

  void _loadFile() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isModified = false;
    });

    final ext = p.extension(widget.filePath).toLowerCase().replaceFirst('.', '');
    final fileName = p.basename(widget.filePath).toLowerCase();

    // 特殊文件名识别（Makefile, Dockerfile 等无后缀文件）
    const specialTextFiles = {
      'makefile', 'dockerfile', 'vagrantfile', 'gemfile', 'rakefile',
      'procfile', 'brewfile', 'justfile', 'cmakelists.txt',
      'readme', 'license', 'changelog', 'podfile',
      '.gitignore', '.gitattributes', '.editorconfig', '.env',
    };

    // 图片
    if (_imageExtensions.contains(ext)) {
      setState(() {
        _fileType = _FileContentType.image;
        _isLoading = false;
      });
      return;
    }

    // 异步读取
    Future(() async {
      try {
        final file = File(widget.filePath);
        final data = await file.readAsBytes();

        if (data.length > 10 * 1024 * 1024) {
          throw Exception('文件过大（${data.length ~/ 1024 ~/ 1024}MB），超过 10MB 限制');
        }

        final isText = _textExtensions.contains(ext) || specialTextFiles.contains(fileName);
        String? text;
        try {
          text = String.fromCharCodes(data);
        } catch (_) {
          if (!isText) {
            if (mounted) {
              setState(() {
                _fileType = _FileContentType.unsupported;
                _isLoading = false;
              });
            }
            return;
          }
          rethrow;
        }

        if (mounted) {
          setState(() {
            _controller.text = text!;
            _fileType = _FileContentType.text;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _saveFile() async {
    try {
      await File(widget.filePath).writeAsString(_controller.text);
      setState(() => _isModified = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 24, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    switch (_fileType) {
      case _FileContentType.text:
        return _buildTextEditor();
      case _FileContentType.image:
        return _buildImagePreview();
      case _FileContentType.unsupported:
        return _buildUnsupported();
    }
  }

  Widget _buildTextEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final theme = isDark ? SyntaxHighlighter.darkTheme : SyntaxHighlighter.lightTheme;
    final ext = p.extension(widget.filePath).toLowerCase().replaceFirst('.', '');
    final language = SyntaxHighlighter.languageForExtension(ext);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveFile,
      },
      child: Container(
        color: bgColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行号栏
            _LineNumberGutter(
              text: _controller.text,
              isDark: isDark,
            ),
            // 编辑器区域（原始 TextField 叠加语法高亮层）
            Expanded(
              child: Stack(
                children: [
                  // 语法高亮层（只读，显示在底层）
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 12, left: 4, right: 16, bottom: 16),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Cascadia Code, Consolas, Courier New, monospace',
                          height: 1.5,
                          color: theme.plain,
                        ),
                        children: SyntaxHighlighter.highlight(
                          _controller.text,
                          language: language,
                          theme: theme,
                        ),
                      ),
                    ),
                  ),
                  // 透明 TextField（接收输入，光标和选区可见）
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Cascadia Code, Consolas, Courier New, monospace',
                      color: Colors.transparent,
                      height: 1.5,
                    ),
                    cursorColor: isDark ? Colors.white70 : Colors.black87,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(top: 12, left: 4, right: 16, bottom: 16),
                    ),
                    onChanged: (text) {
                      if (!_isModified) {
                        setState(() => _isModified = true);
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return _ImagePreviewWidget(filePath: widget.filePath);
  }

  Widget _buildUnsupported() {
    final ext = p.extension(widget.filePath);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_outline, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('无法预览此文件类型', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(ext, style: TextStyle(fontSize: 11, fontFamily: 'Consolas', color: Colors.grey[400])),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              if (Platform.isWindows) {
                Process.run('explorer', [widget.filePath]);
              } else if (Platform.isMacOS) {
                Process.run('open', [widget.filePath]);
              }
            },
            child: const Text('用系统默认应用打开', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

enum _FileContentType { text, image, unsupported }

/// 行号栏 — 对标 Mac 版 LineNumberRulerView
class _LineNumberGutter extends StatelessWidget {
  final String text;
  final bool isDark;

  const _LineNumberGutter({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lineCount = text.isEmpty ? 1 : text.split('\n').length;
    final digits = lineCount.toString().length.clamp(3, 8);
    final gutterWidth = digits * 9.0 + 24.0;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8);
    final numColor = isDark ? const Color(0xFF858585) : const Color(0xFF999999);

    return Container(
      width: gutterWidth,
      color: bgColor,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(lineCount, (i) {
          return SizedBox(
            height: 19.5, // fontSize 13 * lineHeight 1.5
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${i + 1}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Cascadia Code, Consolas, Courier New, monospace',
                  color: numColor,
                  height: 1.5,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 图片预览组件（含缩放控制）
class _ImagePreviewWidget extends StatefulWidget {
  final String filePath;
  const _ImagePreviewWidget({required this.filePath});

  @override
  State<_ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends State<_ImagePreviewWidget> {
  double _scale = 1.0;
  static const double _minScale = 0.1;
  static const double _maxScale = 10.0;

  void _zoomIn() => setState(() => _scale = (_scale * 1.25).clamp(_minScale, _maxScale));
  void _zoomOut() => setState(() => _scale = (_scale / 1.25).clamp(_minScale, _maxScale));
  void _resetFit() => setState(() => _scale = 1.0);
  void _resetActual(double fitScale) => setState(() => _scale = fitScale > 0 ? (1.0 / fitScale) : 1.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      color: bgColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final file = File(widget.filePath);
          if (!file.existsSync()) {
            return _buildError();
          }

          return Stack(
            children: [
              // 可滚动的图片区域
              Center(
                child: InteractiveViewer(
                  minScale: _minScale,
                  maxScale: _maxScale,
                  child: Image.file(
                    file,
                    scale: 1.0 / _scale,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _buildError(),
                  ),
                ),
              ),

              // 缩放控制栏
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF0F0F0)).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _zoomOut,
                        child: Icon(Icons.zoom_out, size: 16, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_scale * 100).toInt()}%',
                        style: TextStyle(fontSize: 10, fontFamily: 'Consolas', color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _zoomIn,
                        child: Icon(Icons.zoom_in, size: 16, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _resetFit,
                        child: Text('适应', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _resetActual(1.0),
                        child: Text('100%', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image, size: 36, color: Colors.grey[500]),
        const SizedBox(height: 8),
        Text('无法加载图片', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}
