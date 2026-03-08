package main

import (
	"html/template"
	"net/http"
	"path/filepath"
)

// PagesServer 公共页面处理器
type PagesServer struct {
	templates *template.Template
	cfg       *Config
}

// NewPagesServer 创建公共页面处理器
func NewPagesServer(cfg *Config) *PagesServer {
	funcMap := template.FuncMap{
		"formatSize": func(size int64) string {
			if size >= 1024*1024*1024 {
				return formatFloat(float64(size)/1024/1024/1024) + " GB"
			}
			if size >= 1024*1024 {
				return formatFloat(float64(size)/1024/1024) + " MB"
			}
			if size >= 1024 {
				return formatFloat(float64(size)/1024) + " KB"
			}
			return formatInt(size) + " B"
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

	return &PagesServer{templates: tmpl, cfg: cfg}
}

// RegisterRoutes 注册公共页面路由
func (p *PagesServer) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/versions", p.handleVersions)
	mux.HandleFunc("/", p.handleIndex)
}

// handleVersions 版本历史页面
func (p *PagesServer) handleVersions(w http.ResponseWriter, r *http.Request) {
	versions, err := DBListPublishedVersions()
	if err != nil {
		http.Error(w, "服务器错误", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	p.templates.ExecuteTemplate(w, "versions.html", map[string]any{
		"Versions": versions,
		"Domain":   p.cfg.Domain,
	})
}

// handleIndex 首页 → 重定向到版本页
func (p *PagesServer) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/versions", http.StatusFound)
}

// ---- helpers ----

func formatFloat(f float64) string {
	s := make([]byte, 0, 8)
	s = append(s, []byte(floatToStr(f))...)
	return string(s)
}

func floatToStr(f float64) string {
	i := int64(f * 10)
	whole := i / 10
	frac := i % 10
	if frac < 0 {
		frac = -frac
	}
	return formatInt(whole) + "." + string(rune('0'+frac))
}

func formatInt(n int64) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	buf := make([]byte, 0, 20)
	for n > 0 {
		buf = append(buf, byte('0'+n%10))
		n /= 10
	}
	if neg {
		buf = append(buf, '-')
	}
	// reverse
	for i, j := 0, len(buf)-1; i < j; i, j = i+1, j-1 {
		buf[i], buf[j] = buf[j], buf[i]
	}
	return string(buf)
}
