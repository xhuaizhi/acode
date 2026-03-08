package main

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

// DB 全局数据库实例
var db *sql.DB

// InitDB 初始化 SQLite 数据库
func InitDB(dataDir string) error {
	os.MkdirAll(dataDir, 0755)
	dbPath := filepath.Join(dataDir, "acode.db")

	var err error
	db, err = sql.Open("sqlite", dbPath+"?_journal_mode=WAL&_busy_timeout=5000")
	if err != nil {
		return fmt.Errorf("打开数据库失败: %w", err)
	}

	db.SetMaxOpenConns(1) // SQLite 单写
	db.SetMaxIdleConns(1)

	return migrate()
}

func migrate() error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS versions (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			version     TEXT    NOT NULL,
			build       TEXT    NOT NULL DEFAULT '',
			platform    TEXT    NOT NULL DEFAULT 'both',
			channel     TEXT    NOT NULL DEFAULT 'stable',
			title       TEXT    NOT NULL DEFAULT '',
			notes       TEXT    NOT NULL DEFAULT '',
			download_url TEXT   NOT NULL DEFAULT '',
			file_size   INTEGER NOT NULL DEFAULT 0,
			sha256      TEXT    NOT NULL DEFAULT '',
			is_forced   INTEGER NOT NULL DEFAULT 0,
			is_published INTEGER NOT NULL DEFAULT 0,
			created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		);

		CREATE INDEX IF NOT EXISTS idx_versions_published
			ON versions(is_published, platform, channel);
		CREATE INDEX IF NOT EXISTS idx_versions_version
			ON versions(version);
	`)
	return err
}

// CloseDB 关闭数据库
func CloseDB() {
	if db != nil {
		db.Close()
	}
}

// ---- CRUD ----

// DBCreateVersion 创建版本
func DBCreateVersion(v *Version) (int64, error) {
	now := time.Now().UTC()
	res, err := db.Exec(`
		INSERT INTO versions (version, build, platform, channel, title, notes,
			download_url, file_size, sha256, is_forced, is_published, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		v.Version, v.Build, v.Platform, v.Channel, v.Title, v.Notes,
		v.DownloadURL, v.FileSize, v.SHA256,
		boolToInt(v.IsForced), boolToInt(v.IsPublished), now, now,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// DBUpdateVersion 更新版本
func DBUpdateVersion(v *Version) error {
	_, err := db.Exec(`
		UPDATE versions SET
			version=?, build=?, platform=?, channel=?, title=?, notes=?,
			download_url=?, file_size=?, sha256=?, is_forced=?, is_published=?,
			updated_at=?
		WHERE id=?`,
		v.Version, v.Build, v.Platform, v.Channel, v.Title, v.Notes,
		v.DownloadURL, v.FileSize, v.SHA256,
		boolToInt(v.IsForced), boolToInt(v.IsPublished),
		time.Now().UTC(), v.ID,
	)
	return err
}

// DBDeleteVersion 删除版本
func DBDeleteVersion(id int64) error {
	_, err := db.Exec("DELETE FROM versions WHERE id=?", id)
	return err
}

// DBGetVersion 获取单个版本
func DBGetVersion(id int64) (*Version, error) {
	row := db.QueryRow("SELECT * FROM versions WHERE id=?", id)
	return scanVersion(row)
}

// DBListVersions 列出所有版本 (管理后台用，按创建时间倒序)
func DBListVersions() ([]Version, error) {
	rows, err := db.Query("SELECT * FROM versions ORDER BY created_at DESC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanVersions(rows)
}

// DBListPublishedVersions 列出已发布版本 (公共页面用)
func DBListPublishedVersions() ([]Version, error) {
	rows, err := db.Query(`
		SELECT * FROM versions
		WHERE is_published=1
		ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanVersions(rows)
}

// DBGetLatestVersion 获取指定平台最新已发布版本
func DBGetLatestVersion(platform string) (*Version, error) {
	row := db.QueryRow(`
		SELECT * FROM versions
		WHERE is_published=1 AND (platform=? OR platform='both')
		ORDER BY created_at DESC
		LIMIT 1`, platform)
	return scanVersion(row)
}

// ---- helpers ----

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func scanVersion(scanner interface{ Scan(...any) error }) (*Version, error) {
	var v Version
	var forced, published int
	err := scanner.Scan(
		&v.ID, &v.Version, &v.Build, &v.Platform, &v.Channel,
		&v.Title, &v.Notes, &v.DownloadURL, &v.FileSize, &v.SHA256,
		&forced, &published, &v.CreatedAt, &v.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	v.IsForced = forced == 1
	v.IsPublished = published == 1
	return &v, nil
}

func scanVersions(rows *sql.Rows) ([]Version, error) {
	var list []Version
	for rows.Next() {
		var v Version
		var forced, published int
		err := rows.Scan(
			&v.ID, &v.Version, &v.Build, &v.Platform, &v.Channel,
			&v.Title, &v.Notes, &v.DownloadURL, &v.FileSize, &v.SHA256,
			&forced, &published, &v.CreatedAt, &v.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		v.IsForced = forced == 1
		v.IsPublished = published == 1
		list = append(list, v)
	}
	return list, rows.Err()
}
