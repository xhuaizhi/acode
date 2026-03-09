# ACode Windows

Windows 版本 — Flutter 桌面应用

## 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | Flutter 3.38+ (Windows Desktop) |
| 语言 | Dart 3.10+ |
| UI | Material 3 |
| 状态管理 | Provider |
| 终端 | xterm + flutter_pty (ConPTY) |
| 数据库 | SQLite (sqflite_common_ffi) |
| 窗口管理 | window_manager |

## 功能概览

- **多终端管理** — 新建、水平/垂直分屏、关闭，支持状态持久化
- **AI Provider 管理** — Claude Code / OpenAI Codex / Gemini CLI 的 CRUD、切换、预设快速添加
- **环境变量注入** — 激活的 Provider API Key 自动注入终端环境
- **配置文件同步** — 自动写入 ~/.claude/settings.json、~/.codex/config.json 等
- **MCP 服务器管理** — 手动/预设添加，同步写入 Claude 和 Codex 配置
- **自定义技能** — 创建自定义 AI 指令，同步到各 CLI 工具的指令文件
- **文件浏览器** — 树形目录、文件图标、上下文操作
- **代码编辑器** — 文本编辑、图片预览、不支持类型提示
- **更新检查器** — 自动检查/下载/安装更新 (SHA256 校验)
- **Token 用量统计** — 实时统计输入/输出 Token 和预估费用

## 构建

### 前提条件

- Flutter 3.38+ (stable)
- Visual Studio 2022 + C++ 桌面开发工作负载

### 开发运行

```powershell
flutter pub get
flutter run -d windows
```

### 生产构建

```powershell
flutter build windows --release
```

构建产物位于 `build/windows/x64/runner/Release/`

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| Ctrl+T | 新建终端 |
| Ctrl+O | 打开文件夹 |
| Ctrl+D | 垂直分屏 |
| Ctrl+Shift+D | 水平分屏 |
| Ctrl+S | 保存文件 |
| Ctrl+, | 打开/关闭设置 |
| Esc | 关闭设置 |

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── app/
│   └── app_state.dart           # 全局状态 (ChangeNotifier)
├── models/
│   ├── provider.dart            # AI Provider 模型 + 预设
│   ├── mcp_server.dart          # MCP 服务器模型 + 预设
│   ├── skill.dart               # 自定义技能模型
│   ├── split_node.dart          # 分屏树 + 终端标签
│   ├── file_node.dart           # 文件树节点
│   └── usage_tracker.dart       # Token 用量追踪
├── database/
│   └── database_manager.dart    # SQLite 数据库 CRUD
├── services/
│   ├── provider_service.dart    # Provider 业务逻辑
│   ├── provider_config_writer.dart  # 配置文件写入
│   ├── provider_env_generator.dart  # 环境变量生成
│   ├── mcp_service.dart         # MCP 服务器管理
│   ├── skills_service.dart      # 技能管理
│   └── update_checker.dart      # 更新检查器
├── views/
│   ├── main/
│   │   └── main_view.dart       # 主窗口 (工具栏+分屏+编辑器)
│   ├── terminal/
│   │   ├── terminal_panel_view.dart  # 终端面板 (xterm+pty)
│   │   └── split_node_view.dart     # 分屏树递归渲染
│   ├── settings/
│   │   ├── inline_settings_view.dart    # 内嵌设置覆盖层
│   │   ├── general_settings_view.dart   # 常规设置
│   │   ├── provider_settings_view.dart  # Provider 管理
│   │   ├── mcp_settings_view.dart       # MCP 管理
│   │   ├── skills_settings_view.dart    # 技能管理
│   │   ├── usage_settings_view.dart     # 用量统计
│   │   └── about_settings_view.dart     # 关于页
│   ├── file_explorer/
│   │   ├── file_explorer_view.dart  # 文件浏览器
│   │   ├── editor_tab_bar.dart      # 编辑器标签栏
│   │   └── file_editor_view.dart    # 文件编辑器
│   └── components/
│       ├── status_bar_view.dart     # 底部状态栏
│       └── update_toast_view.dart   # 更新通知 Toast
└── utils/
    └── provider_icon_inference.dart # Provider 图标推断
```
