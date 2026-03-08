#ifndef ACODE_MCP_UI_H
#define ACODE_MCP_UI_H

#include <windows.h>

/* Create MCP management panel as child window */
HWND mcp_ui_create(HWND parent, HINSTANCE hInst, int x, int y, int w, int h);

/* Show MCP add/edit dialog. existing=NULL for new. Returns TRUE if saved. */
BOOL mcp_form_show(HWND parent, const char *existingId);

/* Show MCP preset selection dialog. Returns TRUE if installed. */
BOOL mcp_preset_show(HWND parent);

#endif /* ACODE_MCP_UI_H */
