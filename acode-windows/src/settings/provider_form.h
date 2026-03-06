#ifndef ACODE_PROVIDER_FORM_H
#define ACODE_PROVIDER_FORM_H

#include <windows.h>
#include "../provider/provider.h"

/* 显示添加/编辑 Provider 对话框
 * tool: "claude_code" / "openai" / "gemini"
 * existing: NULL = 新建模式，非NULL = 编辑模式
 * 返回 TRUE 表示用户点击了保存 */
BOOL provider_form_show(HWND parent, const char *tool, const Provider *existing);

/* 显示预设选择对话框，返回 TRUE 表示用户完成添加 */
BOOL provider_preset_show(HWND parent, const char *tool);

#endif /* ACODE_PROVIDER_FORM_H */
