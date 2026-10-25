"""Verify the portable launcher end-to-end with a TRUE double-click chain.

The launcher is started with ShellExecuteW (exactly what Explorer does), it then
starts the game; we locate the game's Engine window (class "Engine"), resize to an
exact client size, drive 主菜单 -> 选择关卡 -> 第一章 with real mouse input, capture
client-area PNGs, and dump the engine log written into the portable userdata dir.

Usage:
  "C:/Users/Sunrise/AppData/Local/Programs/Python/Python311/python.exe" verify_launcher.py \
      --launcher E:/godot_game_by_fable/builds/playable-slice/nezha_ch1_playable_r2_launcher.exe \
      --out E:/godot_game_by_fable/_review/startup-fix/verify_launcher --size 1600x900
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import hashlib
import json
import os
import time
from pathlib import Path

u = ctypes.windll.user32
k = ctypes.windll.kernel32
shell32 = ctypes.windll.shell32

GWL_STYLE = -16
GWL_EXSTYLE = -20
SWP_NOSIZE = 0x0001
SWP_NOZORDER = 0x0004
SWP_FRAMECHANGED = 0x0020
SWP_SHOWWINDOW = 0x0040
SW_RESTORE = 9
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
TOKEN_QUERY = 0x0008
TokenIntegrityLevel = 25


def set_dpi_aware():
    try:
        u.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
        return "per-monitor-v2"
    except Exception:
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(2)
            return "per-monitor"
        except Exception:
            u.SetProcessDPIAware()
            return "system"


def sha256_of(p: Path):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def visible_windows():
    out = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(hwnd, _):
        if not u.IsWindowVisible(hwnd):
            return True
        n = u.GetWindowTextLengthW(hwnd)
        buf = ctypes.create_unicode_buffer(n + 1)
        u.GetWindowTextW(hwnd, buf, n + 1)
        cls = ctypes.create_unicode_buffer(256)
        u.GetClassNameW(hwnd, cls, 256)
        pid = wt.DWORD()
        u.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        r = wt.RECT()
        u.GetWindowRect(hwnd, ctypes.byref(r))
        out.append({"hwnd": int(hwnd), "title": buf.value, "class": cls.value,
                    "pid": pid.value, "rect": [r.left, r.top, r.right, r.bottom]})
        return True

    u.EnumWindows(cb, 0)
    return out


def find_engine_window(exclude_hwnds):
    for w in visible_windows():
        if w["hwnd"] in exclude_hwnds:
            continue
        if w["class"] == "Engine" and w["rect"][2] - w["rect"][0] > 200:
            return w
    return None


def integrity_of(pid):
    h = k.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return {"error": ctypes.get_last_error()}
    tok = wt.HANDLE()
    if not ctypes.windll.advapi32.OpenProcessToken(h, TOKEN_QUERY, ctypes.byref(tok)):
        k.CloseHandle(h)
        return {"error": ctypes.get_last_error()}
    size = wt.DWORD(0)
    ctypes.windll.advapi32.GetTokenInformation(tok, TokenIntegrityLevel, None, 0, ctypes.byref(size))
    buf = ctypes.create_string_buffer(size.value)
    res = {"raw_len": size.value}
    if ctypes.windll.advapi32.GetTokenInformation(tok, TokenIntegrityLevel, buf, size, ctypes.byref(size)):
        sid_ptr = ctypes.cast(buf, ctypes.POINTER(ctypes.c_void_p))[0]
        strsid = ctypes.c_wchar_p()
        ctypes.windll.advapi32.ConvertSidToStringSidW(ctypes.c_void_p(sid_ptr), ctypes.byref(strsid))
        res["sid"] = strsid.value
    else:
        res["error"] = ctypes.get_last_error()
    k.CloseHandle(tok)
    k.CloseHandle(h)
    return res


def client_rect(hwnd):
    r = wt.RECT()
    u.GetClientRect(hwnd, ctypes.byref(r))
    return r.right, r.bottom


def client_origin(hwnd):
    pt = wt.POINT(0, 0)
    u.ClientToScreen(hwnd, ctypes.byref(pt))
    return pt.x, pt.y


def resize_client(hwnd, cw, ch):
    style = u.GetWindowLongW(hwnd, GWL_STYLE) & 0xFFFFFFFF
    exstyle = u.GetWindowLongW(hwnd, GWL_EXSTYLE) & 0xFFFFFFFF
    r = wt.RECT(0, 0, cw, ch)
    u.AdjustWindowRectEx(ctypes.byref(r), style, False, exstyle)
    ow, oh = r.right - r.left, r.bottom - r.top
    u.SetWindowPos(hwnd, 0, 0, -(oh - ch), ow, oh, SWP_FRAMECHANGED | SWP_SHOWWINDOW)
    time.sleep(0.6)
    got = client_rect(hwnd)
    if got != (cw, ch):
        u.SetWindowPos(hwnd, 0, 0, -(oh - ch), ow + (cw - got[0]), oh + (ch - got[1]),
                       SWP_FRAMECHANGED | SWP_SHOWWINDOW)
        time.sleep(0.6)
    return client_rect(hwnd)


def align_client_origin(hwnd):
    for _ in range(4):
        cx, cy = client_origin(hwnd)
        if (cx, cy) == (0, 0):
            return [0, 0]
        wr = wt.RECT()
        u.GetWindowRect(hwnd, ctypes.byref(wr))
        u.SetWindowPos(hwnd, 0, wr.left - cx, wr.top - cy, 0, 0, SWP_NOSIZE | SWP_NOZORDER)
        time.sleep(0.3)
    return list(client_origin(hwnd))


def shot(hwnd, path: Path):
    from PIL import ImageGrab
    cw, ch = client_rect(hwnd)
    cx, cy = client_origin(hwnd)
    u.ShowWindow(hwnd, SW_RESTORE)
    u.SetWindowPos(hwnd, -1, cx, cy, 0, 0, SWP_NOSIZE | SWP_SHOWWINDOW)  # HWND_TOPMOST
    u.SetForegroundWindow(hwnd)
    time.sleep(0.6)
    img = ImageGrab.grab(bbox=(cx, cy, cx + cw, cy + ch), all_screens=True)
    u.SetWindowPos(hwnd, -2, cx, cy, 0, 0, SWP_NOSIZE)  # HWND_NOTOPMOST
    img.save(path)
    # crude "is it a black/blank frame" check
    small = img.convert("L").resize((64, 36))
    px = list(small.getdata())
    mean = sum(px) / len(px)
    spread = max(px) - min(px)
    return {"file": path.name, "client": [cw, ch], "origin": [cx, cy],
            "luma_mean": round(mean, 2), "luma_spread": spread}


def click(hwnd, fx, fy):
    cw, ch = client_rect(hwnd)
    cx, cy = client_origin(hwnd)
    x, y = int(cx + fx * cw), int(cy + fy * ch)
    u.SetForegroundWindow(hwnd)
    u.SetCursorPos(x, y)
    time.sleep(0.3)
    u.mouse_event(2, 0, 0, 0, 0)
    u.mouse_event(4, 0, 0, 0, 0)
    return [x, y]


def tail(path: Path, n=40):
    if not path.exists():
        return None
    data = path.read_text(encoding="utf-8", errors="replace").splitlines()
    return data[-n:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--launcher", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", default="1600x900")
    ap.add_argument("--wait-menu", type=float, default=25.0)
    ap.add_argument("--wait-select", type=float, default=4.0)
    ap.add_argument("--wait-ch1", type=float, default=20.0)
    ap.add_argument("--keep-open", action="store_true")
    args = ap.parse_args()

    launcher = Path(args.launcher).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    w, h = (int(x) for x in args.size.lower().split("x"))
    gamedir = launcher.parent
    game = gamedir / "nezha_ch1_playable_r2.exe"
    ud = gamedir / "userdata"
    ud_app = ud / "Godot" / "app_userdata" / "哪吒·轮回海域"

    info = {
        "dpi_awareness": set_dpi_aware(),
        "launcher": str(launcher), "launcher_sha256": sha256_of(launcher),
        "game": str(game), "game_sha256": sha256_of(game), "game_bytes": game.stat().st_size,
        "launcher_bytes": launcher.stat().st_size,
        "portable_userdata": str(ud_app),
        "portable_userdata_before": sorted(p.name for p in ud_app.iterdir()) if ud_app.exists() else [],
        "default_roaming_log_mtime_before": None,
        "started": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "env_APPDATA_of_verifier": os.environ.get("APPDATA"),
    }
    roam_log = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "哪吒·轮回海域" / "logs" / "godot.log"
    if roam_log.exists():
        info["default_roaming_log_mtime_before"] = roam_log.stat().st_mtime

    before = {x["hwnd"] for x in visible_windows()}
    # TRUE double-click chain
    rc = shell32.ShellExecuteW(None, "open", str(launcher), None, str(gamedir), 1)
    info["shellexecute_rc"] = int(rc)
    info["launched_at"] = time.time()

    win = None
    deadline = time.time() + 60
    while time.time() < deadline:
        win = find_engine_window(before)
        if win:
            break
        time.sleep(0.4)
    info["window"] = win
    info["window_found"] = bool(win)
    info["seconds_to_window"] = round(time.time() - info["launched_at"], 2) if win else None
    if not win:
        (out / "verify.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
        print("RESULT " + json.dumps(info, ensure_ascii=False))
        return

    hwnd = wt.HWND(win["hwnd"])
    info["game_pid"] = win["pid"]
    info["game_integrity"] = integrity_of(win["pid"])
    info["launcher_pid_integrity"] = None
    info["client_after_resize"] = resize_client(hwnd, w, h)
    info["client_aligned"] = align_client_origin(hwnd)
    time.sleep(args.wait_menu)
    info["shots"] = [{"step": "menu", **shot(hwnd, out / "menu.png")}]
    info["click_select"] = click(hwnd, 0.5, 0.585)
    time.sleep(args.wait_select)
    info["shots"].append({"step": "select", **shot(hwnd, out / "select.png")})
    info["click_ch1"] = click(hwnd, 0.5, 0.306)
    time.sleep(args.wait_ch1)
    info["client_after_ch1"] = resize_client(hwnd, w, h)
    info["client_aligned_after_ch1"] = align_client_origin(hwnd)
    time.sleep(2.0)
    info["shots"].append({"step": "ch1", **shot(hwnd, out / "ch1.png")})
    info["client_final"] = list(client_rect(hwnd))
    info["window_still_alive"] = u.IsWindow(hwnd) and u.IsWindowVisible(hwnd)

    info["portable_userdata_after"] = sorted(p.name for p in ud_app.iterdir()) if ud_app.exists() else []
    info["portable_progress_cfg"] = (ud_app / "progress.cfg").exists()
    if (ud_app / "progress.cfg").exists():
        info["portable_progress_cfg_text"] = (ud_app / "progress.cfg").read_text(encoding="utf-8", errors="replace")
    info["portable_godot_log_tail"] = tail(ud_app / "logs" / "godot.log", 60)
    info["launcher_log_tail"] = tail(ud / "launcher.log", 20)
    if roam_log.exists():
        info["default_roaming_log_mtime_after"] = roam_log.stat().st_mtime
    (out / "verify.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    print("RESULT " + json.dumps({kk: info.get(kk) for kk in
          ("window_found", "seconds_to_window", "game_pid", "game_integrity",
           "client_final", "portable_progress_cfg", "window_still_alive")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
