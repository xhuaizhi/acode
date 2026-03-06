#ifndef ACODE_STATUS_BAR_H
#define ACODE_STATUS_BAR_H

#include <windows.h>

HWND status_bar_create(HWND parent, HINSTANCE hInstance);
void status_bar_update(void);

#endif /* ACODE_STATUS_BAR_H */
