"""t7 verifier harness: launch the real r2 exe with a process-local APPDATA,
resize its CLIENT area exactly, drive 主菜单 -> 选择关卡 -> 第一章 by real mouse
input, and capture CLIENT-AREA screenshots (no window frame, exact client size).

Usage (PowerShell/cmd):
  python launch_capture.py --exe E:\\godot_game_by_fable\\builds\\playable-slice\\nezha_ch1_playable_r2.exe ^
      --out  E:\\godot_game_by_fable\\_review\\playable_slice\\verify_t7 ^
      --size 1920x1080 --size 1600x900 --size 1280x720

It writes into <out>/<size>/: menu.png, select.png, ch1.png, launch.json, stdout.log, stderr.log
and prints a JSON summary line `RESULT {...}` per size.
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

u = ctypes.windll.user32
k = ctypes.windll.kernel32

GWL_STYLE = -16
GWL_EXSTYLE = -20
SWP_NOSIZE = 0x0001
SWP_NOZORDER = 0x0004
SWP_FRAMECHANGED = 0x0020
SWP_SHOWWINDOW = 0x0040
SW_RESTORE = 9
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000


def set_dpi_aware():
    try:
        u.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))  # PER_MONITOR_AWARE_V2
        return "per-monitor-v2"
    except Exception:
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(2)
            return "per-monitor"
        except Exception:
            u.SetProcessDPIAware()
            return "system"


def exe_hash(p: Path):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_window(pid: int):
    found = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(hwnd, _):
        wpid = wt.DWORD()
        u.GetWindowThreadProcessId(hwnd, ctypes.byref(wpid))
        if wpid.value == pid and u.IsWindowVisible(hwnd):
            found.append(hwnd)
        return True

    u.EnumWindows(cb, 0)
    return found[0] if found else None


def client_rect(hwnd):
    r = wt.RECT()
    u.GetClientRect(hwnd, ctypes.byref(r))
    return r.right, r.bottom


def client_origin(hwnd):
    pt = wt.POINT(0, 0)
    u.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y


def dpi_of(hwnd):
    try:
        return u.GetDpiForWindow(hwnd)
    except Exception:
        return 96


def resize_client(hwnd, cw, ch):
    style = u.GetWindowLongW(hwnd, GWL_STYLE) & 0xFFFFFFFF
    exstyle = u.GetWindowLongW(hwnd, GWL_EXSTYLE) & 0xFFFFFFFF
    r = wt.RECT(0, 0, cw, ch)
    u.AdjustWindowRectEx(ctypes.byref(r), style, False, exstyle)
    ow, oh = r.right - r.left, r.bottom - r.top
    # Place so the CLIENT origin lands at (0,0); frame may go off-screen above.
    u.SetWindowPos(hwnd, 0, 0, -(oh - ch), ow, oh, SWP_FRAMECHANGED | SWP_SHOWWINDOW)
    time.sleep(0.6)
    got = client_rect(hwnd)
    if got != (cw, ch):  # one corrective pass
        u.SetWindowPos(hwnd, 0, 0, -(oh - ch), ow + (cw - got[0]), oh + (ch - got[1]),
                       SWP_FRAMECHANGED | SWP_SHOWWINDOW)
        time.sleep(0.6)
    return client_rect(hwnd)


def capture_client(hwnd):
    """PrintWindow(PW_RENDERFULLCONTENT) 抓取客户区；即使被其它窗口遮挡也有效。"""
    from PIL import Image
    cw, ch = client_rect(hwnd)
    gdi = ctypes.windll.gdi32
    hdc_win = u.GetDC(hwnd)
    hdc_mem = gdi.CreateCompatibleDC(hdc_win)
    hbmp = gdi.CreateCompatibleBitmap(hdc_win, cw, ch)
    gdi.SelectObject(hdc_mem, hbmp)

    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_ = [("biSize", wt.DWORD), ("biWidth", wt.LONG), ("biHeight", wt.LONG),
                    ("biPlanes", wt.WORD), ("biBitCount", wt.WORD), ("biCompression", wt.DWORD),
                    ("biSizeImage", wt.DWORD), ("biXPelsPerMeter", wt.LONG), ("biYPelsPerMeter", wt.LONG),
                    ("biClrUsed", wt.DWORD), ("biClrImportant", wt.DWORD)]

    bi = BITMAPINFOHEADER(); bi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bi.biWidth = cw; bi.biHeight = -ch; bi.biPlanes = 1; bi.biBitCount = 32; bi.biCompression = 0
    buf = ctypes.create_string_buffer(cw * ch * 4)
    ok = u.PrintWindow(hwnd, hdc_mem, 2)  # PW_RENDERFULLCONTENT
    gdi.GetDIBits(hdc_mem, hbmp, 0, ch, buf, ctypes.byref(bi), 0)
    gdi.DeleteObject(hbmp); gdi.DeleteDC(hdc_mem); u.ReleaseDC(hwnd, hdc_win)
    img = Image.frombuffer("RGBA", (cw, ch), buf.raw, "raw", "BGRA", 0, 1).convert("RGB")
    return img, bool(ok)


def shot(hwnd, path: Path):
    from PIL import ImageGrab
    cw, ch = client_rect(hwnd)
    cx, cy = client_origin(hwnd)
    u.ShowWindow(hwnd, SW_RESTORE)
    u.BringWindowToTop(hwnd)
    u.SetWindowPos(hwnd, -1, cx, cy, 0, 0, SWP_NOSIZE | SWP_SHOWWINDOW)  # HWND_TOPMOST, 提到最前
    u.SetForegroundWindow(hwnd)
    time.sleep(0.5)
    # 屏幕抓取：窗口已 HWND_TOPMOST + 前置，抓取的就是纯客户区（不含标题栏）
    img = ImageGrab.grab(bbox=(cx, cy, cx + cw, cy + ch), all_screens=True)
    pw_ok = None
    blank = False
    u.SetWindowPos(hwnd, -2, cx, cy, 0, 0, SWP_NOSIZE)  # HWND_NOTOPMOST，恢复普通层级
    img.save(path)
    return {"file": path.name, "client": [cw, ch], "origin": [cx, cy], "image": list(img.size),
            "printwindow_ok": pw_ok, "blank_fallback": blank}


def click(hwnd, fx, fy):
    cw, ch = client_rect(hwnd)
    cx, cy = client_origin(hwnd)
    x, y = int(cx + fx * cw), int(cy + fy * ch)
    u.SetCursorPos(x, y)
    time.sleep(0.25)
    u.mouse_event(2, 0, 0, 0, 0)  # LEFTDOWN
    u.mouse_event(4, 0, 0, 0, 0)  # LEFTUP
    return [x, y]


def run_one(exe: Path, out: Path, w: int, h: int, appdata: Path, wait_menu=12.0, wait_select=3.0, wait_ch1=16.0):
    tag = f"{w}x{h}"
    d = out / tag
    d.mkdir(parents=True, exist_ok=True)
    appdata.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env_orig = {kk: os.environ.get(kk) for kk in ("APPDATA", "LOCALAPPDATA", "USERPROFILE", "TEMP")}
    env["APPDATA"] = str(appdata)
    cmd = [str(exe)]
    info = {
        "size": [w, h], "exe": str(exe), "exe_sha256": exe_hash(exe),
        "exe_bytes": exe.stat().st_size, "cmd": cmd, "cwd": str(exe.parent),
        "env_before": env_orig, "env_override": {"APPDATA": str(appdata)},
        "dpi_awareness": set_dpi_aware(), "started": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }
    so = open(d / "stdout.log", "wb")
    se = open(d / "stderr.log", "wb")
    proc = subprocess.Popen(cmd, cwd=str(exe.parent), env=env, stdout=so, stderr=se)
    info["pid"] = proc.pid
    hwnd = None
    deadline = time.time() + 45
    while time.time() < deadline:
        if proc.poll() is not None:
            info["exit_before_window"] = proc.returncode
            info["exit_hex"] = hex(proc.returncode & 0xFFFFFFFF)
            break
        hwnd = find_window(proc.pid)
        if hwnd:
            break
        time.sleep(0.5)
    info["window_found"] = bool(hwnd)
    info["screen"] = [u.GetSystemMetrics(0), u.GetSystemMetrics(1)]
    if hwnd:
        u.ShowWindow(hwnd, SW_RESTORE)
        u.SetForegroundWindow(hwnd)
        info["dpi"] = dpi_of(hwnd)
        info["client_after_resize"] = resize_client(hwnd, w, h)
        # 把客户区左上角精确对齐到屏幕 (0,0)，避免标题栏/边框污染的截图
        for _ in range(3):
            cx, cy = client_origin(hwnd)
            if (cx, cy) == (0, 0):
                break
            wr = wt.RECT()
            u.GetWindowRect(hwnd, ctypes.byref(wr))
            u.SetWindowPos(hwnd, 0, wr.left - cx, wr.top - cy, 0, 0, SWP_NOSIZE | SWP_NOZORDER)
            time.sleep(0.3)
        info["client_aligned"] = list(client_origin(hwnd))
        info["shots"] = []
        time.sleep(wait_menu)
        info["shots"].append({"step": "menu", **shot(hwnd, d / "menu.png")})
        info["click_select"] = click(hwnd, 0.5, 0.585)  # 选择关卡
        time.sleep(wait_select)
        info["shots"].append({"step": "select", **shot(hwnd, d / "select.png")})
        info["click_ch1"] = click(hwnd, 0.5, 0.306)  # 第一章卡片
        time.sleep(wait_ch1)
        # Godot 在窗口跨 DPI/被移动后会按 DPI 比例重设窗口；进关后再精确恢复一次客户区尺寸
        info["client_after_ch1"] = resize_client(hwnd, w, h)
        for _ in range(3):
            cx, cy = client_origin(hwnd)
            if (cx, cy) == (0, 0):
                break
            wr = wt.RECT()
            u.GetWindowRect(hwnd, ctypes.byref(wr))
            u.SetWindowPos(hwnd, 0, wr.left - cx, wr.top - cy, 0, 0, SWP_NOSIZE | SWP_NOZORDER)
            time.sleep(0.3)
        time.sleep(1.5)
        info["shots"].append({"step": "ch1", **shot(hwnd, d / "ch1.png")})
        info["client_final"] = list(client_rect(hwnd))
        info["exit_live"] = proc.poll()
    so.close()
    se.close()
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=10)
    info["exit_after_terminate"] = proc.returncode
    info["exit_after_terminate_hex"] = hex(proc.returncode & 0xFFFFFFFF) if proc.returncode is not None else None
    (d / "launch.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    print("RESULT " + json.dumps({kk: info[kk] for kk in
          ("size", "pid", "window_found", "client_after_resize", "client_final",
           "exit_before_window", "exit_after_terminate", "dpi") if kk in info}, ensure_ascii=False))
    return info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", action="append", default=[])
    ap.add_argument("--appdata", required=True)
    args = ap.parse_args()
    exe = Path(args.exe).resolve()
    out = Path(args.out).resolve()
    appdata = Path(args.appdata).resolve()
    sizes = []
    for s in args.size or ["1920x1080"]:
        w, h = s.lower().split("x")
        sizes.append((int(w), int(h)))
    for w, h in sizes:
        run_one(exe, out, w, h, appdata)


if __name__ == "__main__":
    main()
