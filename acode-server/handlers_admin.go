package main

import (
	"fmt"
	"html/template"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"
)

// AdminServer 管理后台处理器
type AdminServer struct {
	cfg       *Config
	templates *template.Template
}

// NewAdminServer 创建管理后台
func NewAdminServer(cfg *Config) *AdminServer {
	funcMap := template.FuncMap{
		"formatSize": func(size int64) string {
			if size >= 1024*1024*1024 {
				return fmt.Sprintf("%.1f GB", float64(size)/1024/1024/1024)
			}
			if size >= 1024*1024 {
				return fmt.Sprintf("%.1f MB", float64(size)/1024/1024)
			}
			if size >= 1024 {
				return fmt.Sprintf("%.1f KB", float64(size)/1024)
			}
			return fmt.Sprintf("%d B", size)
		},
		"truncate": func(s string, n int) string {
			if len(s) <= n {
				return s
			}
			return s[:n] + "..."
		},
	}

	tmpl := template.Must(template.New("").Funcs(funcMap).ParseGlob(
		filepath.Join("templates", "*.html"),
	))

	return &AdminServer{cfg: cfg, templates: tmpl}
}

// RegisterRoutes 注册管理后台路由
func (a *AdminServer) RegisterRoutes(mux *http.ServeMux) {
	p := a.cfg.AdminPath

	// 登录
	mux.HandleFunc(p+"/login", a.handleLogin)
	mux.HandleFunc(p+"/logout", a.handleLogout)

	// 版本管理 (需要认证)
	mux.HandleFunc(p+"/", requireAuth(a.cfg, a.handleDashboard))
	mux.HandleFunc(p+"/versions/new", requireAuth(a.cfg, a.handleVersionNew))
	mux.HandleFunc(p+"/versions/create", requireAuth(a.cfg, a.handleVersionCreate))
	mux.HandleFunc(p+"/versions/edit/", requireAuth(a.cfg, a.handleVersionEdit))
	mux.HandleFunc(p+"/versions/update/", requireAuth(a.cfg, a.handleVersionUpdate))
	mux.HandleFunc(p+"/versions/delete/", requireAuth(a.cfg, a.handleVersionDelete))
	mux.HandleFunc(p+"/versions/toggle/", requireAuth(a.cfg, a.handleVersionToggle))
	mux.HandleFunc(p+"/password", requireAuth(a.cfg, a.handleChangePassword))
}

// ---- 登录/登出 ----

func (a *AdminServer) handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		a.render(w, "login.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
		})
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	user := strings.TrimSpace(r.FormValue("username"))
	pass := r.FormValue("password")

	if user != a.cfg.AdminUser || !CheckPassword(a.cfg.AdminHash, pass) {
		a.render(w, "login.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
			"Error":     "用户名或密码错误",
		})
		return
	}

	setSessionCookie(w, a.cfg, user)
	http.Redirect(w, r, a.cfg.AdminPath+"/", http.StatusFound)
}

func (a *AdminServer) handleLogout(w http.ResponseWriter, r *http.Request) {
	clearSessionCookie(w, a.cfg)
	http.Redirect(w, r, a.cfg.AdminPath+"/login", http.StatusFound)
}

// ---- 仪表盘 ----

func (a *AdminServer) handleDashboard(w http.ResponseWriter, r *http.Request) {
	// 只处理精确路径
	if r.URL.Path != a.cfg.AdminPath+"/" {
		http.NotFound(w, r)
		return
	}

	versions, err := DBListVersions()
	if err != nil {
		http.Error(w, "数据库错误", http.StatusInternalServerError)
		return
	}

	a.render(w, "admin.html", map[string]any{
		"AdminPath": a.cfg.AdminPath,
		"Versions":  versions,
		"Domain":    a.cfg.Domain,
	})
}

// ---- 版本 CRUD ----

func (a *AdminServer) handleVersionNew(w http.ResponseWriter, r *http.Request) {
	a.render(w, "admin_version.html", map[string]any{
		"AdminPath": a.cfg.AdminPath,
		"IsEdit":    false,
		"Version":   &Version{Platform: "both", Channel: "stable"},
	})
}

func (a *AdminServer) handleVersionCreate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	v := a.parseVersionForm(r)
	_, err := DBCreateVersion(v)
	if err != nil {
		a.render(w, "admin_version.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
			"IsEdit":    false,
			"Version":   v,
			"Error":     "创建失败: " + err.Error(),
		})
		return
	}

	http.Redirect(w, r, a.cfg.AdminPath+"/", http.StatusFound)
}

func (a *AdminServer) handleVersionEdit(w http.ResponseWriter, r *http.Request) {
	id := extractID(r.URL.Path)
	if id == 0 {
		http.NotFound(w, r)
		return
	}

	v, err := DBGetVersion(id)
	if err != nil || v == nil {
		http.NotFound(w, r)
		return
	}

	a.render(w, "admin_version.html", map[string]any{
		"AdminPath": a.cfg.AdminPath,
		"IsEdit":    true,
		"Version":   v,
	})
}

func (a *AdminServer) handleVersionUpdate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	id := extractID(r.URL.Path)
	if id == 0 {
		http.NotFound(w, r)
		return
	}

	v := a.parseVersionForm(r)
	v.ID = id

	if err := DBUpdateVersion(v); err != nil {
		a.render(w, "admin_version.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
			"IsEdit":    true,
			"Version":   v,
			"Error":     "更新失败: " + err.Error(),
		})
		return
	}

	http.Redirect(w, r, a.cfg.AdminPath+"/", http.StatusFound)
}

func (a *AdminServer) handleVersionDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	id := extractID(r.URL.Path)
	if id == 0 {
		http.NotFound(w, r)
		return
	}

	DBDeleteVersion(id)
	http.Redirect(w, r, a.cfg.AdminPath+"/", http.StatusFound)
}

func (a *AdminServer) handleVersionToggle(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	id := extractID(r.URL.Path)
	if id == 0 {
		http.NotFound(w, r)
		return
	}

	v, err := DBGetVersion(id)
	if err != nil || v == nil {
		http.NotFound(w, r)
		return
	}

	v.IsPublished = !v.IsPublished
	DBUpdateVersion(v)
	http.Redirect(w, r, a.cfg.AdminPath+"/", http.StatusFound)
}

// ---- 修改密码 ----

func (a *AdminServer) handleChangePassword(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		a.render(w, "admin_password.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
		})
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	oldPass := r.FormValue("old_password")
	newPass := r.FormValue("new_password")
	confirmPass := r.FormValue("confirm_password")

	if !CheckPassword(a.cfg.AdminHash, oldPass) {
		a.render(w, "admin_password.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
			"Error":     "原密码错误",
		})
		return
	}

	if len(newPass) < 6 {
		a.render(w, "admin_password.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
			"Error":     "新密码至少6位",
		})
		return
	}

	if newPass != confirmPass {
		a.render(w, "admin_password.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
			"Error":     "两次密码不一致",
		})
		return
	}

	hash, err := HashPassword(newPass)
	if err != nil {
		a.render(w, "admin_password.html", map[string]any{
			"AdminPath": a.cfg.AdminPath,
			"Error":     "密码加密失败",
		})
		return
	}

	a.cfg.AdminHash = hash
	// 获取可执行文件所在目录来保存配置
	SaveConfig(".", a.cfg)

	a.render(w, "admin_password.html", map[string]any{
		"AdminPath": a.cfg.AdminPath,
		"Success":   "密码修改成功",
	})
}

// ---- helpers ----

func (a *AdminServer) render(w http.ResponseWriter, name string, data any) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := a.templates.ExecuteTemplate(w, name, data); err != nil {
		http.Error(w, "模板渲染失败: "+err.Error(), http.StatusInternalServerError)
	}
}

func (a *AdminServer) parseVersionForm(r *http.Request) *Version {
	fileSize, _ := strconv.ParseInt(r.FormValue("file_size"), 10, 64)
	return &Version{
		Version:     strings.TrimSpace(r.FormValue("version")),
		Build:       strings.TrimSpace(r.FormValue("build")),
		Platform:    r.FormValue("platform"),
		Channel:     r.FormValue("channel"),
		Title:       strings.TrimSpace(r.FormValue("title")),
		Notes:       r.FormValue("notes"),
		DownloadURL: strings.TrimSpace(r.FormValue("download_url")),
		FileSize:    fileSize,
		SHA256:      strings.TrimSpace(r.FormValue("sha256")),
		IsForced:    r.FormValue("is_forced") == "on",
		IsPublished: r.FormValue("is_published") == "on",
	}
}

func extractID(path string) int64 {
	parts := strings.Split(strings.TrimRight(path, "/"), "/")
	if len(parts) == 0 {
		return 0
	}
	id, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)
	return id
}
