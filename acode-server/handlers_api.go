package main

import (
	"encoding/json"
	"net/http"
	"strings"
)

// handleUpdateCheck 客户端检查更新 API
// GET /api/v1/update/check?version=1.0.0&platform=windows
func handleUpdateCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	clientVersion := r.URL.Query().Get("version")
	platform := r.URL.Query().Get("platform")
	if platform == "" {
		platform = "windows"
	}

	resp := UpdateCheckResponse{HasUpdate: false}

	latest, err := DBGetLatestVersion(platform)
	if err != nil {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "服务器内部错误"})
		return
	}

	if latest != nil && latest.Version != clientVersion && compareVersion(latest.Version, clientVersion) > 0 {
		resp.HasUpdate = true
		resp.Version = latest.Version
		resp.Build = latest.Build
		resp.Title = latest.Title
		resp.Notes = latest.Notes
		resp.DownloadURL = latest.DownloadURL
		resp.FileSize = latest.FileSize
		resp.SHA256 = latest.SHA256
		resp.IsForced = latest.IsForced
	}

	jsonResponse(w, http.StatusOK, resp)
}

// handleLatestVersion 获取最新版本信息
// GET /api/v1/latest?platform=windows
func handleLatestVersion(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	platform := r.URL.Query().Get("platform")
	if platform == "" {
		platform = "windows"
	}

	latest, err := DBGetLatestVersion(platform)
	if err != nil {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "服务器内部错误"})
		return
	}

	if latest == nil {
		jsonResponse(w, http.StatusOK, map[string]string{"message": "暂无版本"})
		return
	}

	jsonResponse(w, http.StatusOK, latest)
}

// ---- helpers ----

func jsonResponse(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// compareVersion 比较语义版本号 a > b 返回正数
func compareVersion(a, b string) int {
	ap := parseVersionParts(a)
	bp := parseVersionParts(b)

	for i := 0; i < 3; i++ {
		av, bv := 0, 0
		if i < len(ap) {
			av = ap[i]
		}
		if i < len(bp) {
			bv = bp[i]
		}
		if av != bv {
			return av - bv
		}
	}
	return 0
}

func parseVersionParts(v string) []int {
	v = strings.TrimPrefix(v, "v")
	parts := strings.Split(v, ".")
	nums := make([]int, 0, 3)
	for _, p := range parts {
		n := 0
		for _, c := range p {
			if c >= '0' && c <= '9' {
				n = n*10 + int(c-'0')
			} else {
				break
			}
		}
		nums = append(nums, n)
	}
	return nums
}
