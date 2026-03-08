#include "image_view.h"
#include "../app.h"
#include "../utils/theme.h"
#include <shlwapi.h>
#include <windowsx.h>
#include <ole2.h>
#include <olectl.h>
#include <stdio.h>
#include <math.h>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")

#define IMAGE_VIEW_CLASS L"ACodeImageView"

/* Cached GDI fonts for image view painting */
static HFONT s_ivZoomFont = NULL;
static HFONT s_ivPlaceholderFont = NULL;

static void ensure_iv_fonts(void) {
    if (!s_ivZoomFont)
        s_ivZoomFont = CreateFontW(12, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_ivPlaceholderFont)
        s_ivPlaceholderFont = CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
}

/* Supported image extensions (matches Mac ImagePreviewView) */
static const wchar_t *s_imageExts[] = {
    L"png", L"jpg", L"jpeg", L"gif", L"bmp",
    L"tiff", L"tif", L"ico", L"webp", NULL
};

/* Per-instance data stored via GWLP_USERDATA */
typedef struct {
    wchar_t    path[MAX_PATH];
    HBITMAP    hBitmap;
    int        imgWidth;
    int        imgHeight;
    double     scale;
    double     fitScale;
    int        scrollX;
    int        scrollY;
    bool       dragging;
    POINT      dragStart;
    int        dragScrollX;
    int        dragScrollY;
} ImageViewData;

static ImageViewData *get_data(HWND hwnd) {
    return (ImageViewData *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
}

/* Load image using GDI (BMP/ICO natively, others via OleLoadPicture) */
static HBITMAP load_image_file(const wchar_t *path, int *outW, int *outH) {
    /* Try OleLoadPicture for broad format support */
    HANDLE hFile = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) return NULL;

    DWORD fileSize = GetFileSize(hFile, NULL);
    if (fileSize == 0 || fileSize == INVALID_FILE_SIZE) {
        CloseHandle(hFile);
        return NULL;
    }

    HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE, fileSize);
    if (!hGlobal) { CloseHandle(hFile); return NULL; }

    void *pData = GlobalLock(hGlobal);
    DWORD bytesRead = 0;
    ReadFile(hFile, pData, fileSize, &bytesRead, NULL);
    GlobalUnlock(hGlobal);
    CloseHandle(hFile);

    IStream *pStream = NULL;
    if (FAILED(CreateStreamOnHGlobal(hGlobal, TRUE, &pStream))) {
        GlobalFree(hGlobal);
        return NULL;
    }

    IPicture *pPicture = NULL;
    HRESULT hr = OleLoadPicture(pStream, fileSize, FALSE, &IID_IPicture, (void **)&pPicture);
    pStream->lpVtbl->Release(pStream);

    if (FAILED(hr) || !pPicture) return NULL;

    /* Get dimensions */
    OLE_XSIZE_HIMETRIC hmWidth;
    OLE_YSIZE_HIMETRIC hmHeight;
    pPicture->lpVtbl->get_Width(pPicture, &hmWidth);
    pPicture->lpVtbl->get_Height(pPicture, &hmHeight);

    /* Convert HIMETRIC to pixels */
    HDC hdcScreen = GetDC(NULL);
    int pixW = MulDiv(hmWidth, GetDeviceCaps(hdcScreen, LOGPIXELSX), 2540);
    int pixH = MulDiv(hmHeight, GetDeviceCaps(hdcScreen, LOGPIXELSY), 2540);

    /* Render to HBITMAP */
    HDC hdcMem = CreateCompatibleDC(hdcScreen);
    HBITMAP hBmp = CreateCompatibleBitmap(hdcScreen, pixW, pixH);
    HBITMAP hOld = SelectObject(hdcMem, hBmp);

    RECT fillRect = { 0, 0, pixW, pixH };
    /* Checkerboard pattern background for transparency indication */
    HBRUSH bgBrush = CreateSolidBrush(RGB(200, 200, 200));
    FillRect(hdcMem, &fillRect, bgBrush);
    DeleteObject(bgBrush);

    pPicture->lpVtbl->Render(pPicture, hdcMem, 0, 0, pixW, pixH,
        0, hmHeight, hmWidth, -hmHeight, NULL);

    SelectObject(hdcMem, hOld);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdcScreen);
    pPicture->lpVtbl->Release(pPicture);

    *outW = pixW;
    *outH = pixH;
    return hBmp;
}

/* Calculate fit scale (image fits in container, max 1.0) */
static double calc_fit_scale(int imgW, int imgH, int containerW, int containerH) {
    if (imgW <= 0 || imgH <= 0 || containerW <= 0 || containerH <= 0) return 1.0;
    double sx = (double)containerW / imgW;
    double sy = (double)containerH / imgH;
    double s = (sx < sy) ? sx : sy;
    if (s > 1.0) s = 1.0;
    return s;
}

/* Clamp scroll position */
static void clamp_scroll(ImageViewData *d, int viewW, int viewH) {
    int dispW = (int)(d->imgWidth * d->fitScale * d->scale);
    int dispH = (int)(d->imgHeight * d->fitScale * d->scale);
    int maxX = dispW > viewW ? dispW - viewW : 0;
    int maxY = dispH > viewH ? dispH - viewH : 0;
    if (d->scrollX < 0) d->scrollX = 0;
    if (d->scrollX > maxX) d->scrollX = maxX;
    if (d->scrollY < 0) d->scrollY = 0;
    if (d->scrollY > maxY) d->scrollY = maxY;
}

#define ZOOM_BAR_HEIGHT 28

static void paint_zoom_bar(HDC hdc, RECT *rc, ImageViewData *d) {
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);

    /* Background with slight transparency feel */
    HBRUSH bg = CreateSolidBrush(colors->surface);
    FillRect(hdc, rc, bg);
    DeleteObject(bg);

    /* Top border */
    HPEN pen = CreatePen(PS_SOLID, 1, colors->border);
    HPEN oldPen = SelectObject(hdc, pen);
    MoveToEx(hdc, rc->left, rc->top, NULL);
    LineTo(hdc, rc->right, rc->top);
    SelectObject(hdc, oldPen);
    DeleteObject(pen);

    SetBkMode(hdc, TRANSPARENT);
    ensure_iv_fonts();
    HFONT oldFont = SelectObject(hdc, s_ivZoomFont);

    int pct = (int)(d->scale * d->fitScale * 100);
    wchar_t buf[64];
    _snwprintf(buf, 64, L"\u2212   %d%%   +   \u9002\u5E94   100%%   %dx%d",
               pct, d->imgWidth, d->imgHeight);

    SetTextColor(hdc, colors->textSecondary);
    RECT textRect = *rc;
    textRect.left += 8;
    textRect.right -= 8;
    DrawTextW(hdc, buf, -1, &textRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

    SelectObject(hdc, oldFont);
}

static LRESULT CALLBACK image_view_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    ImageViewData *d = get_data(hwnd);

    switch (msg) {
    case WM_CREATE: {
        ImageViewData *nd = (ImageViewData *)calloc(1, sizeof(ImageViewData));
        nd->scale = 1.0;
        nd->fitScale = 1.0;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)nd);
        return 0;
    }

    case WM_DESTROY:
        if (d) {
            if (d->hBitmap) DeleteObject(d->hBitmap);
            free(d);
        }
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
        return 0;

    case WM_SIZE:
        if (d && d->hBitmap) {
            RECT rc;
            GetClientRect(hwnd, &rc);
            d->fitScale = calc_fit_scale(d->imgWidth, d->imgHeight,
                rc.right, rc.bottom - ZOOM_BAR_HEIGHT);
            clamp_scroll(d, rc.right, rc.bottom - ZOOM_BAR_HEIGHT);
        }
        return 0;

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);

        RECT rc;
        GetClientRect(hwnd, &rc);

        /* Main area background */
        RECT mainArea = { 0, 0, rc.right, rc.bottom - ZOOM_BAR_HEIGHT };
        HBRUSH mainBg = CreateSolidBrush(colors->background);
        FillRect(hdc, &mainArea, mainBg);
        DeleteObject(mainBg);

        if (d && d->hBitmap) {
            int viewW = rc.right;
            int viewH = rc.bottom - ZOOM_BAR_HEIGHT;
            int dispW = (int)(d->imgWidth * d->fitScale * d->scale);
            int dispH = (int)(d->imgHeight * d->fitScale * d->scale);

            /* Center if smaller than view */
            int ox = (dispW < viewW) ? (viewW - dispW) / 2 : -d->scrollX;
            int oy = (dispH < viewH) ? (viewH - dispH) / 2 : -d->scrollY;

            HDC hdcMem = CreateCompatibleDC(hdc);
            HBITMAP hOld = SelectObject(hdcMem, d->hBitmap);
            SetStretchBltMode(hdc, HALFTONE);
            StretchBlt(hdc, ox, oy, dispW, dispH,
                       hdcMem, 0, 0, d->imgWidth, d->imgHeight, SRCCOPY);
            SelectObject(hdcMem, hOld);
            DeleteDC(hdcMem);
        } else {
            /* No image loaded - show placeholder */
            SetBkMode(hdc, TRANSPARENT);
            SetTextColor(hdc, colors->textSecondary);
            ensure_iv_fonts();
            HFONT oldF = SelectObject(hdc, s_ivPlaceholderFont);
            DrawTextW(hdc, L"\u65E0\u6CD5\u52A0\u8F7D\u56FE\u7247", -1, &mainArea,
                      DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            SelectObject(hdc, oldF);
        }

        /* Zoom bar at bottom */
        if (d && d->hBitmap) {
            RECT zoomRect = { 0, rc.bottom - ZOOM_BAR_HEIGHT, rc.right, rc.bottom };
            paint_zoom_bar(hdc, &zoomRect, d);
        }

        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;

    case WM_MOUSEWHEEL: {
        if (!d || !d->hBitmap) return 0;
        int delta = GET_WHEEL_DELTA_WPARAM(wParam);
        double factor = (delta > 0) ? 1.15 : (1.0 / 1.15);
        double newScale = d->scale * factor;
        if (newScale < 0.1) newScale = 0.1;
        if (newScale > 10.0) newScale = 10.0;
        d->scale = newScale;

        RECT rc;
        GetClientRect(hwnd, &rc);
        clamp_scroll(d, rc.right, rc.bottom - ZOOM_BAR_HEIGHT);
        InvalidateRect(hwnd, NULL, FALSE);
        return 0;
    }

    case WM_LBUTTONDOWN: {
        if (!d) return 0;
        RECT rc;
        GetClientRect(hwnd, &rc);
        int y = GET_Y_LPARAM(lParam);
        int x = GET_X_LPARAM(lParam);

        /* Check zoom bar clicks */
        if (y >= rc.bottom - ZOOM_BAR_HEIGHT) {
            int barW = rc.right;
            int center = barW / 2;

            /* Rough hit regions for zoom bar buttons */
            if (x < center - 60) {
                /* Zoom out (-) */
                d->scale *= (1.0 / 1.25);
                if (d->scale < 0.1) d->scale = 0.1;
            } else if (x > center + 40 && x < center + 80) {
                /* Fit */
                d->scale = 1.0;
                d->scrollX = 0;
                d->scrollY = 0;
            } else if (x > center + 80) {
                /* 100% */
                d->scale = 1.0 / d->fitScale;
                d->scrollX = 0;
                d->scrollY = 0;
            } else if (x > center + 10 && x < center + 40) {
                /* Zoom in (+) */
                d->scale *= 1.25;
                if (d->scale > 10.0) d->scale = 10.0;
            }
            clamp_scroll(d, rc.right, rc.bottom - ZOOM_BAR_HEIGHT);
            InvalidateRect(hwnd, NULL, FALSE);
            return 0;
        }

        /* Start drag for panning */
        d->dragging = true;
        d->dragStart.x = x;
        d->dragStart.y = y;
        d->dragScrollX = d->scrollX;
        d->dragScrollY = d->scrollY;
        SetCapture(hwnd);
        return 0;
    }

    case WM_MOUSEMOVE:
        if (d && d->dragging) {
            int x = GET_X_LPARAM(lParam);
            int y = GET_Y_LPARAM(lParam);
            d->scrollX = d->dragScrollX - (x - d->dragStart.x);
            d->scrollY = d->dragScrollY - (y - d->dragStart.y);
            RECT rc;
            GetClientRect(hwnd, &rc);
            clamp_scroll(d, rc.right, rc.bottom - ZOOM_BAR_HEIGHT);
            InvalidateRect(hwnd, NULL, FALSE);
        }
        return 0;

    case WM_LBUTTONUP:
        if (d && d->dragging) {
            d->dragging = false;
            ReleaseCapture();
        }
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

void image_view_register(HINSTANCE hInstance) {
    static bool registered = false;
    if (registered) return;

    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .lpfnWndProc = image_view_proc,
        .hInstance = hInstance,
        .hbrBackground = NULL,
        .lpszClassName = IMAGE_VIEW_CLASS,
        .hCursor = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&wc);
    registered = true;
}

HWND image_view_create(HWND parent, HINSTANCE hInstance) {
    image_view_register(hInstance);
    return CreateWindowExW(
        0, IMAGE_VIEW_CLASS, NULL,
        WS_CHILD | WS_CLIPCHILDREN,
        0, 0, 100, 100,
        parent, NULL, hInstance, NULL
    );
}

bool image_view_load(HWND hwnd, const wchar_t *path) {
    ImageViewData *d = get_data(hwnd);
    if (!d) return false;

    if (d->hBitmap) {
        DeleteObject(d->hBitmap);
        d->hBitmap = NULL;
    }

    wcscpy(d->path, path);
    d->hBitmap = load_image_file(path, &d->imgWidth, &d->imgHeight);
    d->scale = 1.0;
    d->scrollX = 0;
    d->scrollY = 0;

    RECT rc;
    GetClientRect(hwnd, &rc);
    d->fitScale = calc_fit_scale(d->imgWidth, d->imgHeight,
        rc.right, rc.bottom - ZOOM_BAR_HEIGHT);

    InvalidateRect(hwnd, NULL, FALSE);
    return d->hBitmap != NULL;
}

bool image_view_is_image_file(const wchar_t *path) {
    if (!path) return false;
    const wchar_t *ext = PathFindExtensionW(path);
    if (!ext || *ext != L'.') return false;
    ext++; /* skip dot */

    for (int i = 0; s_imageExts[i]; i++) {
        if (_wcsicmp(ext, s_imageExts[i]) == 0) return true;
    }
    return false;
}
