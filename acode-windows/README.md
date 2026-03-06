# ACode Windows

Windows 原生版本 — 纯 C + Win32 API

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | C (C17) |
| UI | Win32 API + DWM (Mica / 暗色模式) |
| 终端 | ConPTY (Windows Pseudo Console) |
| 文本渲染 | GDI (ClearType) |
| 数据库 | SQLite3 (amalgamation) |
| JSON | cJSON |
| 构建 | CMake 3.20+ |

## 预估内存占用

10-20MB（对比 Mac 版 59MB）

## 依赖准备

### SQLite3

```powershell
cd deps/sqlite3
Invoke-WebRequest -Uri "https://www.sqlite.org/2024/sqlite-amalgamation-3450100.zip" -OutFile sqlite.zip
Expand-Archive sqlite.zip -DestinationPath .
Move-Item sqlite-amalgamation-*\sqlite3.c .
Move-Item sqlite-amalgamation-*\sqlite3.h .
Remove-Item -Recurse sqlite-amalgamation-*, sqlite.zip
```

cJSON 已包含在仓库中。

## 构建 (Windows)

### Visual Studio

```powershell
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

### MSVC 命令行

```powershell
mkdir build
cd build
cmake .. -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release
nmake
```

### MinGW

```bash
mkdir build && cd build
cmake .. -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
mingw32-make
```

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| Ctrl+T | 新建终端 |
| Ctrl+O | 打开文件夹 |
| Ctrl+D | 垂直分屏 |
| Ctrl+Shift+D | 水平分屏 |
| Ctrl+S | 保存文件 |
| Ctrl+Z | 撤销 |
| Ctrl+Y | 重做 |
| Ctrl+, | 打开/关闭设置 |
| Esc | 关闭设置 |

## 项目结构

```
src/
├── main.c              # WinMain 入口
├── app.h/c             # 全局状态
├── window/             # 窗口管理 (主窗口、分割面板、状态栏)
├── terminal/           # ConPTY 终端
├── editor/             # 代码编辑器 (gap buffer + 语法高亮)
├── explorer/           # 文件浏览器 (TreeView)
├── settings/           # 设置面板
├── provider/           # AI Provider 管理
├── database/           # SQLite 数据库
├── services/           # 更新检查、用量统计
└── utils/              # 主题、路径、字符串工具
```
