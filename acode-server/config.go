package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"golang.org/x/crypto/bcrypt"
)

// Config 服务器配置
type Config struct {
	// 服务监听地址
	Listen string `json:"listen"`
	// 域名 (用于生成下载链接等)
	Domain string `json:"domain"`
	// 管理后台隐藏路径 (如 /mgt-a7x9k2)
	AdminPath string `json:"admin_path"`
	// 管理员用户名
	AdminUser string `json:"admin_user"`
	// 管理员密码 bcrypt hash
	AdminHash string `json:"admin_hash"`
	// Session 密钥 (hex编码)
	SessionSecret string `json:"session_secret"`
	// 数据目录 (存放 DB 和上传文件)
	DataDir string `json:"data_dir"`
	// 下载文件存储目录 (相对于 DataDir)
	UploadDir string `json:"upload_dir"`
}

const configFileName = "config.json"

// DefaultConfig 返回默认配置
func DefaultConfig() *Config {
	secret := make([]byte, 32)
	rand.Read(secret)

	// 生成随机管理路径
	pathBytes := make([]byte, 6)
	rand.Read(pathBytes)
	adminPath := "/mgt-" + hex.EncodeToString(pathBytes)

	return &Config{
		Listen:        ":8080",
		Domain:        "acode.anna.tf",
		AdminPath:     adminPath,
		AdminUser:     "admin",
		AdminHash:     "", // 首次运行时设置
		SessionSecret: hex.EncodeToString(secret),
		DataDir:       "./data",
		UploadDir:     "releases",
	}
}

// LoadConfig 从文件加载配置，不存在则创建默认配置
func LoadConfig(dir string) (*Config, error) {
	path := filepath.Join(dir, configFileName)

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return initConfig(path)
		}
		return nil, fmt.Errorf("读取配置失败: %w", err)
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("解析配置失败: %w", err)
	}
	return &cfg, nil
}

// SaveConfig 保存配置到文件
func SaveConfig(dir string, cfg *Config) error {
	path := filepath.Join(dir, configFileName)
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0600)
}

func initConfig(path string) (*Config, error) {
	cfg := DefaultConfig()

	// 生成默认密码并 hash
	defaultPass := "acode2025"
	hash, err := bcrypt.GenerateFromPassword([]byte(defaultPass), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	cfg.AdminHash = string(hash)

	// 确保目录存在
	os.MkdirAll(filepath.Dir(path), 0755)

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := os.WriteFile(path, data, 0600); err != nil {
		return nil, err
	}

	fmt.Println("========================================")
	fmt.Println("首次运行，已生成默认配置:")
	fmt.Printf("  配置文件: %s\n", path)
	fmt.Printf("  管理路径: %s\n", cfg.AdminPath)
	fmt.Printf("  管理用户: %s\n", cfg.AdminUser)
	fmt.Printf("  管理密码: %s\n", defaultPass)
	fmt.Println("  ⚠️  请立即修改默认密码!")
	fmt.Println("========================================")

	return cfg, nil
}

// HashPassword 生成 bcrypt hash
func HashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(hash), err
}

// CheckPassword 验证密码
func CheckPassword(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}
