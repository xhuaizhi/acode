package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
)

func main() {
	// 获取可执行文件所在目录作为工作目录
	execPath, err := os.Executable()
	if err != nil {
		log.Fatal("获取可执行路径失败:", err)
	}
	workDir := filepath.Dir(execPath)

	// 开发模式：如果当前目录有 config.json 或 templates/，使用当前目录
	if _, err := os.Stat("templates"); err == nil {
		workDir = "."
	}

	// 加载配置
	cfg, err := LoadConfig(workDir)
	if err != nil {
		log.Fatal("加载配置失败:", err)
	}

	// 初始化数据库
	dataDir := cfg.DataDir
	if !filepath.IsAbs(dataDir) {
		dataDir = filepath.Join(workDir, dataDir)
	}
	if err := InitDB(dataDir); err != nil {
		log.Fatal("初始化数据库失败:", err)
	}
	defer CloseDB()

	// 确保上传目录存在
	uploadDir := filepath.Join(dataDir, cfg.UploadDir)
	os.MkdirAll(uploadDir, 0755)

	// 路由
	mux := http.NewServeMux()

	// 公共 API
	mux.HandleFunc("/api/v1/update/check", handleUpdateCheck)
	mux.HandleFunc("/api/v1/latest", handleLatestVersion)

	// 静态文件 (下载)
	mux.Handle("/releases/", http.StripPrefix("/releases/",
		http.FileServer(http.Dir(uploadDir))))

	// 管理后台
	admin := NewAdminServer(cfg)
	admin.RegisterRoutes(mux)

	// 公共页面
	pages := NewPagesServer(cfg)
	pages.RegisterRoutes(mux)

	// 启动
	server := &http.Server{
		Addr:    cfg.Listen,
		Handler: logMiddleware(mux),
	}

	// 优雅关闭
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		fmt.Println("\n正在关闭服务器...")
		server.Close()
	}()

	fmt.Println("========================================")
	fmt.Printf("ACode Server 启动\n")
	fmt.Printf("  监听地址: %s\n", cfg.Listen)
	fmt.Printf("  域名:     %s\n", cfg.Domain)
	fmt.Printf("  管理后台: %s/\n", cfg.AdminPath)
	fmt.Printf("  数据目录: %s\n", dataDir)
	fmt.Printf("  公共API:  /api/v1/update/check\n")
	fmt.Printf("  版本页面: /versions\n")
	fmt.Println("========================================")

	if err := server.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatal("服务器错误:", err)
	}
	fmt.Println("服务器已关闭")
}

// logMiddleware 简单请求日志
func logMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s", r.Method, r.URL.Path, r.RemoteAddr)
		next.ServeHTTP(w, r)
	})
}
