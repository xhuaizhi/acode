#ifndef ACODE_IMAGE_VIEW_H
#define ACODE_IMAGE_VIEW_H

#include <windows.h>
#include <stdbool.h>

/* Register the image preview window class */
void image_view_register(HINSTANCE hInstance);

/* Create an image preview window */
HWND image_view_create(HWND parent, HINSTANCE hInstance);

/* Load and display an image file */
bool image_view_load(HWND hwnd, const wchar_t *path);

/* Check if a file extension is a supported image format */
bool image_view_is_image_file(const wchar_t *path);

#endif /* ACODE_IMAGE_VIEW_H */
