# ACode Client

跨平台终端客户端 — 多终端分屏 + AI CLI Provider 管理

## 项目结构

```
acode-client/
├── acode-mac/          # macOS 原生版本 (Swift + SwiftUI)
│   └── ACode/
│       ├── Package.swift
│       └── Sources/
│           ├── App/          # 应用入口 + 全局状态
│           ├── Models/       # 数据模型
│           ├── Database/     # SQLite 数据库层
│           ├── Services/     # 业务逻辑服务
│           ├── Views/        # UI 视图
│           │   ├── Main/     # 主窗口 + 标签栏 + 状态栏
│           │   ├── Settings/ # 设置页面
│           │   └── Terminal/ # 终端模块
│           └── Utils/        # 工具类
│
└── acode-windows/      # Windows 版本 (WinUI 3 + C#) [待开发]
```

## macOS 版本

### 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | SwiftUI + AppKit (macOS 14+) |
| 终端 | SwiftTerm (LocalProcessTerminalView) |
| 数据库 | SQLite.swift |
| 自动更新 | Sparkle |

### 核心功能

- **多终端标签页**：支持多个终端同时运行
- **Provider 管理**：多渠道 API 供应商添加/切换/删除
  - Claude Code (Anthropic API)
  - OpenAI Codex
  - Gemini CLI
- **配置文件自动写入**：切换 Provider 后自动更新 CLI 配置
- **环境变量注入**：每个终端独立持有 Provider 环境变量
- **预设供应商**：一键添加常用供应商（官方/DeepSeek/OpenRouter）

### 构建

```bash
cd acode-mac/ACode
swift build
```

### 运行

```bash
swift run ACode
```

### 生成 Xcode 项目

```bash
cd acode-mac/ACode
swift package generate-xcodeproj
# 或直接用 Xcode 打开 Package.swift
open Package.swift
```

## Windows 版本 [待开发]

技术栈：WinUI 3 (Windows App SDK) + C#
