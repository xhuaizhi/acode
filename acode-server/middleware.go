package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const (
	sessionCookieName = "_acode_sid"
	sessionMaxAge     = 24 * time.Hour
)

// SessionData 会话数据
type SessionData struct {
	User      string
	ExpiresAt time.Time
}

// signSession 签名会话令牌
func signSession(user string, secret string, expiresAt time.Time) string {
	payload := fmt.Sprintf("%s|%d", user, expiresAt.Unix())
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	sig := hex.EncodeToString(mac.Sum(nil))
	token := base64.URLEncoding.EncodeToString([]byte(payload)) + "." + sig
	return token
}

// verifySession 验证会话令牌
func verifySession(token string, secret string) *SessionData {
	parts := strings.SplitN(token, ".", 2)
	if len(parts) != 2 {
		return nil
	}

	payload, err := base64.URLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil
	}

	// 验证签名
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expectedSig := hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(parts[1]), []byte(expectedSig)) {
		return nil
	}

	// 解析
	fields := strings.SplitN(string(payload), "|", 2)
	if len(fields) != 2 {
		return nil
	}

	var ts int64
	fmt.Sscanf(fields[1], "%d", &ts)
	expiresAt := time.Unix(ts, 0)

	if time.Now().After(expiresAt) {
		return nil
	}

	return &SessionData{
		User:      fields[0],
		ExpiresAt: expiresAt,
	}
}

// setSessionCookie 设置会话 cookie
func setSessionCookie(w http.ResponseWriter, cfg *Config, user string) {
	expiresAt := time.Now().Add(sessionMaxAge)
	token := signSession(user, cfg.SessionSecret, expiresAt)

	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    token,
		Path:     cfg.AdminPath,
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteStrictMode,
		MaxAge:   int(sessionMaxAge.Seconds()),
	})
}

// clearSessionCookie 清除会话 cookie
func clearSessionCookie(w http.ResponseWriter, cfg *Config) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    "",
		Path:     cfg.AdminPath,
		HttpOnly: true,
		Secure:   true,
		MaxAge:   -1,
	})
}

// requireAuth 认证中间件
func requireAuth(cfg *Config, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie(sessionCookieName)
		if err != nil || cookie.Value == "" {
			http.Redirect(w, r, cfg.AdminPath+"/login", http.StatusFound)
			return
		}

		session := verifySession(cookie.Value, cfg.SessionSecret)
		if session == nil {
			clearSessionCookie(w, cfg)
			http.Redirect(w, r, cfg.AdminPath+"/login", http.StatusFound)
			return
		}

		next(w, r)
	}
}
