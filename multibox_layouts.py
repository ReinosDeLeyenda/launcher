"""Detección de monitores y cálculo geométrico de layouts para Multiboxing."""
import ctypes
from ctypes import wintypes

PRESAVED_LAYOUTS = [
    "Cuadricula (Filas x Columnas)",
    "Prioridad 1 arriba - 2 abajo",
    "Prioridad 2 arriba, 3 abajo",
    "Prioridad centro arriba",
    "Prioridad centro",
]

MONITOR_ARRANGEMENTS = [
    "Real (Windows)",
    "Horizontal (1 | 2 | 3)",
    "Horizontal Invertido (3 | 2 | 1)",
    "Vertical (Arriba / Abajo)",
]


class MONITORINFO(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("rcMonitor", wintypes.RECT),
        ("rcWork", wintypes.RECT),
        ("dwFlags", wintypes.DWORD),
    ]


def get_monitors_info(debug_args=None):
    debug_args = [a.lower() for a in (debug_args or [])]
    is_debug = "--debug" in debug_args
    user32 = ctypes.windll.user32
    raw_monitors = []

    if is_debug:
        w, h = 1920, 1080
        if any(f in debug_args for f in ("--4k", "-4k", "4k", "3840x2160")):
            w, h = 3840, 2160
        elif any(f in debug_args for f in ("--2k", "--1440p", "2k", "1440p", "2560x1440")):
            w, h = 2560, 1440
        elif any(f in debug_args for f in ("--ultrawide", "ultrawide", "3440x1440")):
            w, h = 3440, 1440
        elif any(f in debug_args for f in ("--1080p", "1080p", "1920x1080")):
            w, h = 1920, 1080

        if any(f in debug_args for f in ("--quad", "quad")):
            count = 4
        elif any(f in debug_args for f in ("--triple", "triple")):
            count = 3
        elif any(f in debug_args for f in ("--dual", "dual")):
            count = 2
        else:
            has_res = any(f in debug_args for f in ("--4k", "--2k", "--1440p", "--ultrawide", "--1080p", "4k", "2k", "1440p", "ultrawide", "1080p"))
            count = 1 if has_res else 2

        for i in range(count):
            raw_monitors.append((i == 0, i * w, 0, w, h))
    else:
        @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HMONITOR, wintypes.HDC, ctypes.POINTER(wintypes.RECT), wintypes.LPARAM)
        def monitor_cb(hmon, _hdc, _lprect, _lparam):
            mi = MONITORINFO()
            mi.cbSize = ctypes.sizeof(MONITORINFO)
            if user32.GetMonitorInfoW(hmon, ctypes.byref(mi)):
                wx, wy = mi.rcWork.left, mi.rcWork.top
                ww, wh = mi.rcWork.right - wx, mi.rcWork.bottom - wy
                is_primary = bool(mi.dwFlags & 1)
                raw_monitors.append((is_primary, wx, wy, ww, wh))
            return True

        user32.EnumDisplayMonitors(0, 0, monitor_cb, 0)
        if not raw_monitors:
            raw_monitors = [(True, 0, 0, 1920, 1080)]
        raw_monitors.sort(key=lambda m: (not next(iter(m)), m))

    result = []
    for idx, (is_prim, wx, wy, ww, wh) in enumerate(raw_monitors):
        tag = (" (Debug Principal)" if is_prim else " (Debug)") if is_debug else (" (Principal)" if is_prim else "")
        result.append((f"Monitor {idx + 1}{tag} — {ww}x{wh}", (wx, wy, ww, wh)))
    return result

def compute_grid_rects(rows, cols, area_x, area_y, area_w, area_h):
    rects = []
    cell_w = area_w // cols
    cell_h = area_h // rows
    for r in range(rows):
        y = area_y + r * cell_h
        h = (area_h - r * cell_h) if r == rows - 1 else cell_h
        for c in range(cols):
            x = area_x + c * cell_w
            w = (area_w - c * cell_w) if c == cols - 1 else cell_w
            rects.append((x, y, w, h))
    return rects


def compute_layout_rects(layout_name, rows, cols, area_x, area_y, area_w, area_h):
    if layout_name == "Prioridad 1 arriba - 2 abajo":
        top_h = int(area_h * 0.66)
        bot_h = area_h - top_h
        w1 = area_w // 2
        return [
            (area_x, area_y, area_w, top_h),
            (area_x, area_y + top_h, w1, bot_h),
            (area_x + w1, area_y + top_h, area_w - w1, bot_h),
        ]
    if layout_name == "Prioridad 2 arriba, 3 abajo":
        top_h = int(area_h * 0.66)
        bot_h = area_h - top_h
        tw = area_w // 2
        bw = area_w // 3
        return [
            (area_x, area_y, tw, top_h),
            (area_x + tw, area_y, area_w - tw, top_h),
            (area_x, area_y + top_h, bw, bot_h),
            (area_x + bw, area_y + top_h, bw, bot_h),
            (area_x + bw * 2, area_y + top_h, area_w - bw * 2, bot_h),
        ]
    if layout_name == "Prioridad centro arriba":
        top_h = int(area_h * 0.66)
        bot_h = area_h - top_h
        side_w = int(area_w * 0.25)
        mid_w = area_w - side_w * 2
        half_top = top_h // 2
        rects = [
            (area_x + side_w, area_y, mid_w, top_h),
            (area_x, area_y, side_w, half_top),
            (area_x, area_y + half_top, side_w, top_h - half_top),
            (area_x + side_w + mid_w, area_y, side_w, half_top),
            (area_x + side_w + mid_w, area_y + half_top, side_w, top_h - half_top),
        ]
        bot_w = area_w // 6
        for i in range(6):
            bx = area_x + i * bot_w
            bw = (area_w - i * bot_w) if i == 5 else bot_w
            rects.append((bx, area_y + top_h, bw, bot_h))
        return rects
    if layout_name == "Prioridad centro":
        cw = area_w // 4
        ch = area_h // 4
        rects = [(area_x + cw, area_y + ch, cw * 2, ch * 2)]
        for r in range(4):
            y = area_y + r * ch
            h = (area_h - r * ch) if r == 3 else ch
            for c in range(4):
                if r in (1, 2) and c in (1, 2):
                    continue
                x = area_x + c * cw
                w = (area_w - c * cw) if c == 3 else cw
                rects.append((x, y, w, h))
        return rects
    return compute_grid_rects(rows, cols, area_x, area_y, area_w, area_h)


def compute_monitor_subrects(mode, count, mx, my, mw, mh, default_cols=2):
    n = max(1, count)
    if n == 1:
        return [(mx, my, mw, mh)]
    if mode == "h_split":
        return compute_grid_rects(1, n, mx, my, mw, mh)
    if mode == "v_split":
        return compute_grid_rects(n, 1, mx, my, mw, mh)
    if mode == "h_prio":
        main_w = int(mw * 2 / 3)
        side_w = mw - main_w
        rects = [(mx, my, main_w, mh)]
        side_n = n - 1
        for i in range(side_n):
            sy = my + (mh * i) // side_n
            sh = (my + mh - sy) if i == side_n - 1 else ((mh * (i + 1)) // side_n - (mh * i) // side_n)
            rects.append((mx + main_w, sy, side_w, sh))
        return rects
    if mode == "v_prio":
        main_h = int(mh * 2 / 3)
        bot_h = mh - main_h
        rects = [(mx, my, mw, main_h)]
        bot_n = n - 1
        for i in range(bot_n):
            bx = mx + (mw * i) // bot_n
            bw = (mx + mw - bx) if i == bot_n - 1 else ((mw * (i + 1)) // bot_n - (mw * i) // bot_n)
            rects.append((bx, my + main_h, bw, bot_h))
        return rects
    c_cnt = min(n, max(1, default_cols))
    r_cnt = (n + c_cnt - 1) // c_cnt
    return compute_grid_rects(r_cnt, c_cnt, mx, my, mw, mh)
