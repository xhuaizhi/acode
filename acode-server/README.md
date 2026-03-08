# ACode Server

ACode 自建后端服务，用于版本更新管理、客户端自动更新。

## 技术栈

- **Go** - 纯 Go 实现，编译即用
- **SQLite** - 嵌入式数据库 (modernc.org/sqlite，无 CGo 依赖)
- **标准库** - net/http 路由，html/template 模板渲染

## 快速开始

```bash
# 编译
go build -o acode-server .

# 运行 (首次运行自动生成配置)
./acode-server
```

首次运行会自动生成 `config.json`，包含：
- 随机管理路径 (如 `/mgt-a3b5c7d9e1f2`)
- 默认管理员: `admin` / `acode2025`
- **⚠️ 请立即登录后台修改默认密码**

## 目录结构

```
acode-server/
├── main.go              # 入口，路由注册
├── config.go            # 配置管理
├── db.go                # SQLite 数据库层
├── models.go            # 数据模型
├── middleware.go         # 认证中间件
├── handlers_api.go      # 公共 API
├── handlers_admin.go    # 管理后台
├── handlers_pages.go    # 公共页面
├── templates/           # HTML 模板
│   ├── login.html
│   ├── admin.html
│   ├── admin_version.html
│   ├── admin_password.html
│   └── versions.html
└── data/                # 运行时数据 (自动创建)
    ├── acode.db         # SQLite 数据库
    └── releases/        # 上传的安装包
```

## API 接口

### 检查更新
```
GET /api/v1/update/check?version=1.0.0&platform=windows
```
响应：
```json
{
  "has_update": true,
  "version": "1.0.1",
  "build": "2",
  "title": "Bug 修复",
  "notes": "- 修复 XXX 问题",
  "download_url": "https://acode.anna.tf/releases/ACode-1.0.1-Setup.exe",
  "file_size": 52428800,
  "sha256": "...",
  "is_forced": false
}
```

### 获取最新版本
```
GET /api/v1/latest?platform=windows
```

## 页面

| 路径 | 说明 |
|------|------|
| `/versions` | 公共版本历史页 |
| `/{admin_path}/` | 管理后台仪表盘 |
| `/{admin_path}/login` | 管理登录 |
| `/{admin_path}/password` | 修改密码 |

## 配置 (config.json)

```json
{
  "listen": ":8080",
  "domain": "acode.anna.tf",
  "admin_path": "/mgt-随机路径",
  "admin_user": "admin",
  "admin_hash": "bcrypt hash",
  "session_secret": "hex secret",
  "data_dir": "./data",
  "upload_dir": "releases"
}
```

## 安全特性

- 管理路径随机生成，不可猜测
- 密码使用 bcrypt 加密存储
- Session 使用 HMAC-SHA256 签名
- Cookie 设置 HttpOnly + Secure + SameSite=Strict
- 配置文件权限 0600

## 部署

```bash
# 编译 Linux 版本
GOOS=linux GOARCH=amd64 go build -o acode-server .

# 上传到服务器并运行
scp acode-server templates/ user@server:/opt/acode/
ssh user@server 'cd /opt/acode && ./acode-server'
```

建议配合 systemd 或 supervisor 管理进程，并使用 nginx 反向代理 + SSL。
