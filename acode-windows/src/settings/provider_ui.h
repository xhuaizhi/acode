#ifndef ACODE_PROVIDER_UI_H
#define ACODE_PROVIDER_UI_H

#include <windows.h>
#include <stdbool.h>
#include "../utils/theme.h"
#include "../app.h"

/* 创建 Provider 面板子窗口（含列表+增删改查按鈕） */
HWND provider_ui_create(HWND parent, HINSTANCE hInst, SettingsTab tab, int x, int y, int w, int h);

/* 历史兼容，保留旧实现接口（no-op stub） */
void provider_ui_paint(HDC hdc, RECT *rc, const ThemeColors *colors, SettingsTab tab);

#endif /* ACODE_PROVIDER_UI_H */
