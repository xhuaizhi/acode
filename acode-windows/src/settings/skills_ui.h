#ifndef ACODE_SKILLS_UI_H
#define ACODE_SKILLS_UI_H

#include <windows.h>

/* Create Skills management panel as child window */
HWND skills_ui_create(HWND parent, HINSTANCE hInst, int x, int y, int w, int h);

/* Show Skills add/edit dialog. existingId=NULL for new. Returns TRUE if saved. */
BOOL skills_form_show(HWND parent, const char *existingId);

#endif /* ACODE_SKILLS_UI_H */
