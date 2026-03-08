package main

import "time"

// Version 版本信息
type Version struct {
	ID          int64     `json:"id"`
	Version     string    `json:"version"`      // 语义版本号 如 1.0.1
	Build       string    `json:"build"`        // 构建号
	Platform    string    `json:"platform"`     // windows / mac / both
	Channel     string    `json:"channel"`      // stable / beta
	Title       string    `json:"title"`        // 更新标题
	Notes       string    `json:"notes"`        // 更新日志 (Markdown)
	DownloadURL string    `json:"download_url"` // 下载链接 (外部URL或本地文件)
	FileSize    int64     `json:"file_size"`    // 文件大小 (bytes)
	SHA256      string    `json:"sha256"`       // 文件校验
	IsForced    bool      `json:"is_forced"`    // 是否强制更新
	IsPublished bool      `json:"is_published"` // 是否已发布
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// UpdateCheckResponse 客户端检查更新的响应
type UpdateCheckResponse struct {
	HasUpdate   bool   `json:"has_update"`
	Version     string `json:"version,omitempty"`
	Build       string `json:"build,omitempty"`
	Title       string `json:"title,omitempty"`
	Notes       string `json:"notes,omitempty"`
	DownloadURL string `json:"download_url,omitempty"`
	FileSize    int64  `json:"file_size,omitempty"`
	SHA256      string `json:"sha256,omitempty"`
	IsForced    bool   `json:"is_forced,omitempty"`
}
