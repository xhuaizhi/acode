import 'package:flutter/material.dart';

/// 简易语法高亮引擎 — 基于正则表达式的关键词着色
class SyntaxHighlighter {
  // ==================== Theme ====================

  static SyntaxTheme darkTheme = SyntaxTheme(
    keyword: const Color(0xFF569CD6),
    string: const Color(0xFFCE9178),
    number: const Color(0xFFB5CEA8),
    comment: const Color(0xFF6A9955),
    type: const Color(0xFF4EC9B0),
    function: const Color(0xFFDCDCAA),
    property: const Color(0xFF9CDCFE),
    plain: const Color(0xFFD4D4D4),
    background: const Color(0xFF1E1E1E),
  );

  static SyntaxTheme lightTheme = SyntaxTheme(
    keyword: const Color(0xFF0000FF),
    string: const Color(0xFFA31515),
    number: const Color(0xFF098658),
    comment: const Color(0xFF008000),
    type: const Color(0xFF267F99),
    function: const Color(0xFF795E26),
    property: const Color(0xFF001080),
    plain: const Color(0xFF000000),
    background: const Color(0xFFFFFFFF),
  );

  // ==================== Language Definitions ====================

  static const Map<String, _LanguageDef> _languages = {
    'dart': _LanguageDef(
      keywords: {'import', 'library', 'export', 'part', 'class', 'mixin', 'extension', 'enum',
        'typedef', 'abstract', 'sealed', 'base', 'interface', 'final', 'const', 'var', 'late',
        'required', 'static', 'dynamic', 'void', 'if', 'else', 'for', 'while', 'do', 'switch',
        'case', 'default', 'break', 'continue', 'return', 'throw', 'try', 'catch', 'finally',
        'on', 'rethrow', 'assert', 'new', 'this', 'super', 'is', 'as', 'in', 'true', 'false',
        'null', 'async', 'await', 'yield', 'sync', 'get', 'set', 'operator', 'factory',
        'covariant', 'external', 'with', 'implements', 'extends', 'show', 'hide'},
      types: {'String', 'int', 'double', 'num', 'bool', 'List', 'Map', 'Set', 'Future',
        'Stream', 'Iterable', 'Duration', 'DateTime', 'Uri', 'Type', 'Object', 'Function',
        'Widget', 'State', 'BuildContext', 'Key', 'Color', 'TextStyle', 'EdgeInsets'},
      singleLineComment: '//',
      multiLineCommentStart: '/*',
      multiLineCommentEnd: '*/',
    ),
    'swift': _LanguageDef(
      keywords: {'import', 'func', 'var', 'let', 'class', 'struct', 'enum', 'protocol',
        'extension', 'if', 'else', 'guard', 'switch', 'case', 'default', 'for', 'while',
        'repeat', 'return', 'break', 'continue', 'throw', 'throws', 'try', 'catch', 'do',
        'in', 'where', 'as', 'is', 'self', 'Self', 'super', 'init', 'deinit', 'nil', 'true',
        'false', 'static', 'private', 'public', 'internal', 'fileprivate', 'open', 'override',
        'mutating', 'weak', 'unowned', 'lazy', 'some', 'any', 'async', 'await', 'typealias'},
      types: {'String', 'Int', 'Double', 'Float', 'Bool', 'Array', 'Dictionary', 'Set',
        'Optional', 'URL', 'Data', 'Date', 'UUID', 'View', 'Color', 'Text', 'Image',
        'Button', 'VStack', 'HStack', 'ZStack', 'List', 'NavigationView', 'NSView',
        'NSColor', 'NSFont', 'CGFloat', 'CGPoint', 'CGSize'},
      singleLineComment: '//',
      multiLineCommentStart: '/*',
      multiLineCommentEnd: '*/',
    ),
    'javascript': _LanguageDef(
      keywords: {'const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while',
        'do', 'switch', 'case', 'default', 'break', 'continue', 'new', 'this', 'class',
        'extends', 'super', 'import', 'export', 'from', 'async', 'await', 'try', 'catch',
        'throw', 'typeof', 'instanceof', 'in', 'of', 'true', 'false', 'null', 'undefined',
        'yield', 'delete', 'void', 'static', 'get', 'set'},
      types: {'Array', 'Object', 'String', 'Number', 'Boolean', 'Promise', 'Map', 'Set',
        'WeakMap', 'WeakSet', 'Symbol', 'Date', 'RegExp', 'Error', 'JSON', 'Math',
        'console', 'window', 'document'},
      singleLineComment: '//',
      multiLineCommentStart: '/*',
      multiLineCommentEnd: '*/',
    ),
    'python': _LanguageDef(
      keywords: {'def', 'class', 'if', 'elif', 'else', 'for', 'while', 'return', 'import',
        'from', 'as', 'try', 'except', 'finally', 'raise', 'with', 'yield', 'lambda',
        'pass', 'break', 'continue', 'and', 'or', 'not', 'in', 'is', 'True', 'False',
        'None', 'self', 'global', 'nonlocal', 'assert', 'del', 'async', 'await'},
      types: {'int', 'float', 'str', 'bool', 'list', 'dict', 'tuple', 'set', 'type',
        'object', 'Exception', 'print', 'len', 'range', 'enumerate', 'zip', 'map',
        'filter', 'sorted', 'super', 'property', 'staticmethod', 'classmethod'},
      singleLineComment: '#',
    ),
    'rust': _LanguageDef(
      keywords: {'fn', 'let', 'mut', 'const', 'if', 'else', 'match', 'for', 'while', 'loop',
        'return', 'break', 'continue', 'struct', 'enum', 'impl', 'trait', 'type', 'use',
        'mod', 'pub', 'crate', 'self', 'super', 'where', 'as', 'in', 'ref', 'move',
        'async', 'await', 'unsafe', 'extern', 'dyn', 'true', 'false'},
      types: {'String', 'Vec', 'Option', 'Result', 'Box', 'Rc', 'Arc', 'HashMap', 'HashSet',
        'i8', 'i16', 'i32', 'i64', 'i128', 'u8', 'u16', 'u32', 'u64', 'u128', 'f32',
        'f64', 'bool', 'char', 'usize', 'isize', 'Self'},
      singleLineComment: '//',
      multiLineCommentStart: '/*',
      multiLineCommentEnd: '*/',
    ),
    'html': _LanguageDef(
      keywords: {'html', 'head', 'body', 'div', 'span', 'a', 'p', 'h1', 'h2', 'h3', 'h4',
        'h5', 'h6', 'img', 'ul', 'ol', 'li', 'table', 'tr', 'td', 'th', 'form', 'input',
        'button', 'select', 'option', 'textarea', 'label', 'script', 'style', 'link',
        'meta', 'title', 'section', 'article', 'nav', 'header', 'footer', 'main', 'aside'},
      types: {'class', 'id', 'href', 'src', 'alt', 'type', 'name', 'value', 'placeholder',
        'action', 'method', 'target', 'rel', 'content'},
      multiLineCommentStart: '<!--',
      multiLineCommentEnd: '-->',
    ),
    'css': _LanguageDef(
      keywords: {'@import', '@media', '@keyframes', '@font-face', '@supports', '!important',
        'inherit', 'initial', 'unset', 'none', 'auto', 'block', 'inline', 'flex', 'grid',
        'absolute', 'relative', 'fixed', 'sticky', 'hidden', 'visible', 'solid', 'dashed'},
      types: {'color', 'background', 'margin', 'padding', 'border', 'font-size',
        'font-weight', 'display', 'position', 'width', 'height', 'top', 'left', 'right',
        'bottom', 'z-index', 'overflow', 'opacity', 'transform', 'transition', 'animation'},
      singleLineComment: '//',
      multiLineCommentStart: '/*',
      multiLineCommentEnd: '*/',
    ),
    'generic': _LanguageDef(
      keywords: {'if', 'else', 'for', 'while', 'return', 'function', 'class', 'import',
        'export', 'true', 'false', 'null', 'nil', 'void', 'var', 'let', 'const', 'new',
        'this', 'self'},
      types: {'String', 'Int', 'Bool', 'Array', 'Object', 'Error'},
      singleLineComment: '//',
      multiLineCommentStart: '/*',
      multiLineCommentEnd: '*/',
    ),
  };

  // ==================== Public API ====================

  /// 根据文件扩展名推断语言
  static String languageForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'dart': return 'dart';
      case 'swift': return 'swift';
      case 'js': case 'jsx': case 'mjs': return 'javascript';
      case 'ts': case 'tsx': return 'javascript';
      case 'py': return 'python';
      case 'rs': return 'rust';
      case 'html': case 'htm': return 'html';
      case 'css': case 'scss': case 'less': return 'css';
      case 'json': return 'javascript';
      case 'go': case 'c': case 'h': case 'cpp': case 'hpp': case 'm': case 'mm':
        return 'javascript';
      case 'java': case 'kt': return 'javascript';
      case 'rb': case 'sh': case 'bash': case 'zsh': return 'generic';
      case 'xml': case 'plist': case 'svg': return 'html';
      default: return 'generic';
    }
  }

  /// 生成高亮的 TextSpan 列表
  static List<TextSpan> highlight(String text, {required String language, required SyntaxTheme theme, double fontSize = 13}) {
    if (text.isEmpty) return [];

    final langDef = _languages[language] ?? _languages['generic']!;
    final spans = <TextSpan>[];

    // 简化实现：逐行解析
    final lines = text.split('\n');
    bool inMultiLineComment = false;

    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      if (lineIdx > 0) {
        spans.add(const TextSpan(text: '\n'));
      }

      String line = lines[lineIdx];

      // 多行注释内
      if (inMultiLineComment) {
        final endIdx = langDef.multiLineCommentEnd != null
            ? line.indexOf(langDef.multiLineCommentEnd!)
            : -1;
        if (endIdx >= 0) {
          final end = endIdx + langDef.multiLineCommentEnd!.length;
          spans.add(TextSpan(text: line.substring(0, end), style: TextStyle(color: theme.comment)));
          line = line.substring(end);
          inMultiLineComment = false;
        } else {
          spans.add(TextSpan(text: line, style: TextStyle(color: theme.comment)));
          continue;
        }
      }

      // 处理行内的 tokens
      _tokenizeLine(line, langDef, theme, spans, () => inMultiLineComment = true);
    }

    return spans;
  }

  static void _tokenizeLine(String line, _LanguageDef langDef, SyntaxTheme theme,
      List<TextSpan> spans, VoidCallback onMultiLineCommentStart) {
    int pos = 0;
    final len = line.length;

    while (pos < len) {
      // 1. 多行注释开始
      if (langDef.multiLineCommentStart != null &&
          line.startsWith(langDef.multiLineCommentStart!, pos)) {
        final endIdx = line.indexOf(langDef.multiLineCommentEnd!, pos + langDef.multiLineCommentStart!.length);
        if (endIdx >= 0) {
          final end = endIdx + langDef.multiLineCommentEnd!.length;
          spans.add(TextSpan(text: line.substring(pos, end), style: TextStyle(color: theme.comment)));
          pos = end;
          continue;
        } else {
          spans.add(TextSpan(text: line.substring(pos), style: TextStyle(color: theme.comment)));
          onMultiLineCommentStart();
          return;
        }
      }

      // 2. 单行注释
      if (langDef.singleLineComment != null &&
          line.startsWith(langDef.singleLineComment!, pos)) {
        spans.add(TextSpan(text: line.substring(pos), style: TextStyle(color: theme.comment)));
        return;
      }

      // 3. 字符串（双引号、单引号、反引号）
      if (line[pos] == '"' || line[pos] == "'" || line[pos] == '`') {
        final quote = line[pos];
        int end = pos + 1;
        while (end < len) {
          if (line[end] == '\\') {
            end += 2;
            continue;
          }
          if (line[end] == quote) {
            end++;
            break;
          }
          end++;
        }
        spans.add(TextSpan(text: line.substring(pos, end.clamp(pos, len)), style: TextStyle(color: theme.string)));
        pos = end.clamp(pos, len);
        continue;
      }

      // 4. 数字
      if (_isDigit(line[pos]) || (line[pos] == '.' && pos + 1 < len && _isDigit(line[pos + 1]))) {
        int end = pos;
        while (end < len && (_isDigit(line[end]) || line[end] == '.' || line[end] == 'x' || line[end] == 'X')) {
          end++;
        }
        spans.add(TextSpan(text: line.substring(pos, end), style: TextStyle(color: theme.number)));
        pos = end;
        continue;
      }

      // 5. 标识符（关键词/类型/函数/普通标识符）
      if (_isIdentStart(line[pos])) {
        int end = pos;
        while (end < len && _isIdentPart(line[end])) {
          end++;
        }
        final word = line.substring(pos, end);

        // 检查是否是函数调用 (word followed by '(')
        int nextNonSpace = end;
        while (nextNonSpace < len && line[nextNonSpace] == ' ') {
          nextNonSpace++;
        }

        Color color;
        if (langDef.keywords.contains(word)) {
          color = theme.keyword;
        } else if (langDef.types.contains(word)) {
          color = theme.type;
        } else if (nextNonSpace < len && line[nextNonSpace] == '(') {
          color = theme.function;
        } else {
          color = theme.plain;
        }

        spans.add(TextSpan(text: word, style: TextStyle(color: color)));
        pos = end;
        continue;
      }

      // 6. @ 开头的注解
      if (line[pos] == '@' && pos + 1 < len && _isIdentStart(line[pos + 1])) {
        int end = pos + 1;
        while (end < len && _isIdentPart(line[end])) {
          end++;
        }
        spans.add(TextSpan(text: line.substring(pos, end), style: TextStyle(color: theme.keyword)));
        pos = end;
        continue;
      }

      // 7. 其他字符
      int end = pos + 1;
      while (end < len &&
          !_isIdentStart(line[end]) &&
          !_isDigit(line[end]) &&
          line[end] != '"' && line[end] != "'" && line[end] != '`' &&
          line[end] != '@' &&
          !(langDef.singleLineComment != null && line.startsWith(langDef.singleLineComment!, end)) &&
          !(langDef.multiLineCommentStart != null && line.startsWith(langDef.multiLineCommentStart!, end))) {
        end++;
      }
      spans.add(TextSpan(text: line.substring(pos, end), style: TextStyle(color: theme.plain)));
      pos = end;
    }
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  static bool _isIdentStart(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95;
  }
  static bool _isIdentPart(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57) || code == 95;
  }
}

/// 语法高亮主题
class SyntaxTheme {
  final Color keyword;
  final Color string;
  final Color number;
  final Color comment;
  final Color type;
  final Color function;
  final Color property;
  final Color plain;
  final Color background;

  const SyntaxTheme({
    required this.keyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.type,
    required this.function,
    required this.property,
    required this.plain,
    required this.background,
  });
}

/// 语言定义
class _LanguageDef {
  final Set<String> keywords;
  final Set<String> types;
  final String? singleLineComment;
  final String? multiLineCommentStart;
  final String? multiLineCommentEnd;

  const _LanguageDef({
    this.keywords = const {},
    this.types = const {},
    this.singleLineComment,
    this.multiLineCommentStart,
    this.multiLineCommentEnd,
  });
}
