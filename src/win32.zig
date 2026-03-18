const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

comptime {
    if (builtin.os.tag != .windows) {
        @compileError("This UI build targets Windows only.");
    }
}

pub const win = struct {
    pub const BOOL = windows.BOOL;
    pub const UINT = windows.UINT;
    pub const WPARAM = windows.WPARAM;
    pub const LPARAM = windows.LPARAM;
    pub const LRESULT = windows.LRESULT;
    pub const HINSTANCE = windows.HINSTANCE;
    pub const HWND = windows.HWND;
    pub const HDC = windows.HDC;
    pub const HBRUSH = windows.HBRUSH;
    pub const HPEN = *opaque {};
    pub const HBITMAP = *opaque {};
    pub const HCURSOR = windows.HCURSOR;
    pub const HMENU = windows.HMENU;
    pub const POINT = windows.POINT;
    pub const RECT = windows.RECT;
    pub const COLORREF = u32;
    pub const ATOM = windows.ATOM;
    pub const HGDIOBJ = *opaque {};
    pub const WNDPROC = *const fn (?HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;
    pub const BLENDFUNCTION = extern struct {
        BlendOp: u8,
        BlendFlags: u8,
        SourceConstantAlpha: u8,
        AlphaFormat: u8,
    };

    pub const WNDCLASSA = extern struct {
        style: u32,
        lpfnWndProc: ?WNDPROC,
        cbClsExtra: i32,
        cbWndExtra: i32,
        hInstance: ?HINSTANCE,
        hIcon: ?*opaque {},
        hCursor: ?HCURSOR,
        hbrBackground: ?HBRUSH,
        lpszMenuName: ?[*:0]const u8,
        lpszClassName: [*:0]const u8,
    };

    pub const MSG = extern struct {
        hwnd: ?HWND,
        message: UINT,
        wParam: WPARAM,
        lParam: LPARAM,
        time: u32,
        pt: POINT,
        lPrivate: u32,
    };

    pub const CS_VREDRAW: u32 = 0x0001;
    pub const CS_HREDRAW: u32 = 0x0002;
    pub const WS_VISIBLE: u32 = 0x10000000;
    pub const WS_OVERLAPPEDWINDOW: u32 = 0x00CF0000;
    pub const CW_USEDEFAULT: i32 = @as(i32, @bitCast(@as(u32, 0x80000000)));
    pub const PM_REMOVE: UINT = 0x0001;
    pub const WM_DESTROY: UINT = 0x0002;
    pub const WM_ERASEBKGND: UINT = 0x0014;
    pub const WM_QUIT: UINT = 0x0012;
    pub const WM_LBUTTONDOWN: UINT = 0x0201;
    pub const WM_MOUSEWHEEL: UINT = 0x020A;
    pub const BLACK_BRUSH: i32 = 4;
    pub const SRCCOPY: u32 = 0x00CC0020;
    pub const TRANSPARENT: i32 = 1;
    pub const IDC_ARROW: [*:0]const u8 = @ptrFromInt(32512);
    pub const PS_SOLID: i32 = 0;
    pub const AC_SRC_OVER: u8 = 0x00;

    pub extern "kernel32" fn GetModuleHandleA(lpModuleName: ?[*:0]const u8) callconv(.winapi) ?HINSTANCE;
    pub extern "user32" fn RegisterClassA(lpWndClass: *const WNDCLASSA) callconv(.winapi) ATOM;
    pub extern "user32" fn CreateWindowExA(
        dwExStyle: u32,
        lpClassName: [*:0]const u8,
        lpWindowName: [*:0]const u8,
        dwStyle: u32,
        X: i32,
        Y: i32,
        nWidth: i32,
        nHeight: i32,
        hWndParent: ?HWND,
        hMenu: ?HMENU,
        hInstance: ?HINSTANCE,
        lpParam: ?*anyopaque,
    ) callconv(.winapi) ?HWND;
    pub extern "user32" fn LoadCursorA(hInstance: ?HINSTANCE, lpCursorName: ?[*:0]const u8) callconv(.winapi) ?HCURSOR;
    pub extern "user32" fn DefWindowProcA(hWnd: ?HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
    pub extern "user32" fn PostQuitMessage(exit_code: i32) callconv(.winapi) void;
    pub extern "user32" fn PeekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.winapi) BOOL;
    pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
    pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(.winapi) LRESULT;
    pub extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.winapi) BOOL;
    pub extern "user32" fn ScreenToClient(hWnd: HWND, lpPoint: *POINT) callconv(.winapi) BOOL;
    pub extern "user32" fn GetDC(hWnd: HWND) callconv(.winapi) ?HDC;
    pub extern "user32" fn ReleaseDC(hWnd: HWND, hDC: HDC) callconv(.winapi) i32;
    pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
    pub extern "user32" fn FillRect(hDC: HDC, lprc: *const RECT, hbr: HBRUSH) callconv(.winapi) i32;
    pub extern "user32" fn FrameRect(hDC: HDC, lprc: *const RECT, hbr: HBRUSH) callconv(.winapi) i32;
    pub extern "gdi32" fn CreateSolidBrush(color: COLORREF) callconv(.winapi) ?HBRUSH;
    pub extern "gdi32" fn CreatePen(iStyle: i32, cWidth: i32, color: COLORREF) callconv(.winapi) ?HPEN;
    pub extern "gdi32" fn CreateCompatibleDC(hdc: HDC) callconv(.winapi) ?HDC;
    pub extern "gdi32" fn CreateCompatibleBitmap(hdc: HDC, cx: i32, cy: i32) callconv(.winapi) ?HBITMAP;
    pub extern "gdi32" fn DeleteObject(ho: HGDIOBJ) callconv(.winapi) BOOL;
    pub extern "gdi32" fn DeleteDC(hdc: HDC) callconv(.winapi) BOOL;
    pub extern "gdi32" fn GetStockObject(index: i32) callconv(.winapi) ?HGDIOBJ;
    pub extern "gdi32" fn SelectObject(hdc: HDC, h: HGDIOBJ) callconv(.winapi) ?HGDIOBJ;
    pub extern "gdi32" fn SetTextColor(hdc: HDC, color: COLORREF) callconv(.winapi) COLORREF;
    pub extern "gdi32" fn SetBkMode(hdc: HDC, mode: i32) callconv(.winapi) i32;
    pub extern "gdi32" fn TextOutA(hdc: HDC, x: i32, y: i32, text: [*]const u8, len: i32) callconv(.winapi) BOOL;
    pub extern "gdi32" fn BitBlt(hdc: HDC, x: i32, y: i32, cx: i32, cy: i32, hdc_src: HDC, x1: i32, y1: i32, rop: u32) callconv(.winapi) BOOL;
    pub extern "gdi32" fn Ellipse(hdc: HDC, left: i32, top: i32, right: i32, bottom: i32) callconv(.winapi) BOOL;
    pub extern "gdi32" fn RoundRect(hdc: HDC, left: i32, top: i32, right: i32, bottom: i32, width: i32, height: i32) callconv(.winapi) BOOL;
    pub extern "msimg32" fn AlphaBlend(
        hdcDest: HDC,
        xoriginDest: i32,
        yoriginDest: i32,
        wDest: i32,
        hDest: i32,
        hdcSrc: HDC,
        xoriginSrc: i32,
        yoriginSrc: i32,
        wSrc: i32,
        hSrc: i32,
        ftn: BLENDFUNCTION,
    ) callconv(.winapi) BOOL;
};
