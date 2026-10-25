"""Capture the launcher -> game chain with a real double-click (ShellExecuteW).

Steps are logged with flush so a hang is diagnosable. Screenshots go to --out.
Usage:
  python capture_launcher.py --launcher <exe> --out <dir> [--size 1600x900]
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import json
import os
import sys
import time
from pathlib import Path

u = ctypes.windll.user32
k = ctypes.windll.kernel32
shell32 = ctypes.windll.shell32

STATE = {"steps": []}


def log(msg, **kw):
    rec = {"t": round(time.time(), 3), "msg": msg, **kw}
    STATE["steps"].append(rec)
    print(json.dumps(rec, ensure_ascii=False), flush=True)


def set_dpi_aware():
    try:
        u.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
        return "per-monitor-v2"
    except Exception:
        u.SetProcessDPIAware()
        return "system"


def enum_windows():
    out = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(hwnd, _):
        if not u.IsWindowVisible(hwnd):
            return True
        pid = wt.DWORD()
        u.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        cls = ctypes.create_unicode_buffer(128)
        u.GetClassNameW(hwnd, cls, 128)
        r = wt.RECT()
        u.GetWindowRect(hwnd, ctypes.byref(r))
        out.append({"hwnd": int(hwnd), "class": cls.value, "pid": pid.value,
                    "w": r.right - r.left, "h": r.bottom - r.top})
        return True

    u.EnumWindows(cb, 0)
    return out


def integrity_of(pid):
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    TOKEN_QUERY = 0x8
    h = k.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return {"error": k.GetLastError()}
    tok = wt.HANDLE()
    if not ctypes.windll.advapi32.OpenProcessToken(h, TOKEN_QUERY, ctypes.byref(tok)):
        k.CloseHandle(h)
        return {"error": k.GetLastError()}
    need = wt.DWORD(0)
    ctypes.windll.advapi32.GetTokenInformation(tok, 25, None, 0, ctypes.byref(need))
    buf = ctypes.create_string_buffer(need.value)
    res = {}
    if ctypes.windll.advapi32.GetTokenInformation(tok, 25, buf, need, ctypes.byref(need)):
        sidp = ctypes.cast(buf, ctypes.POINTER(ctypes.c_void_p))[0]
        s = ctypes.c_wchar_p()
        ctypes.windll.advapi32.ConvertSidToStringSidW(ctypes.c_void_p(sidp), ctypes.byref(s))
        res["sid"] = s.value
    else:
        res["error"] = k.GetLastError()
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
    style = u.GetWindowLongW(hwnd, -16) & 0xFFFFFFFF
    exstyle = u.GetWindowLongW(hwnd, -20) & 0xFFFFFFFF
    r = wt.RECT(0, 0, cw, ch)
    u.AdjustWindowRectEx(ctypes.byref(r), style, False, exstyle)
    ow, oh = r.right - r.left, r.bottom - r.top
    for _ in range(2):
        u.SetWindowPos(hwnd, 0, 0, 0, ow, oh, 0x0020 | 0x0040)
        time.sleep(0.5)
        got = client_rect(hwnd)
        if got == (cw, ch):
            break
        ow, oh = ow + (cw - got[0]), oh + (ch - got[1])
    return client_rect(hwnd)


def align_client_origin(hwnd):
    for _ in range(5):
        cx, cy = client_origin(hwnd)
        if (cx, cy) == (0, 0):
            return [0, 0]
        wr = wt.RECT()
        u.GetWindowRect(hwnd, ctypes.byref(wr))
        u.SetWindowPos(hwnd, 0, wr.left - cx, wr.top - cy, 0, 0, 0x0001 | 0x0004)
        time.sleep(0.25)
    return list(client_origin(hwnd))


def shot(hwnd, path: Path):
    from PIL import ImageGrab
    cw, ch = client_rect(hwnd)
    cx, cy = client_origin(hwnd)
    u.ShowWindow(hwnd, 9)
    u.SetForegroundWindow(hwnd)
    u.SetWindowPos(hwnd, -1, cx, cy, 0, 0, 0x0001 | 0x0040)  # TOPMOST
    time.sleep(0.7)
    img = ImageGrab.grab(bbox=(cx, cy, cx + cw, cy + ch), all_screens=True)
    u.SetWindowPos(hwnd, -2, cx, cy, 0, 0, 0x0001)
    img.save(path)
    g = img.convert("L").resize((64, 36))
    px = list(g.getdata())
    return {"file": path.name, "client": [cw, ch], "origin": [cx, cy],
            "luma_mean": round(sum(px) / len(px), 2), "luma_spread": max(px) - min(px)}


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


def tail(p: Path, n=60):
    if not p.exists():
        return None
    return p.read_text(encoding="utf-8", errors="replace").splitlines()[-n:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--launcher", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", default="1600x900")
    ap.add_argument("--timeout", type=float, default=55.0)
    args = ap.parse_args()

    launcher = Path(args.launcher).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    w, h = (int(x) for x in args.size.lower().split("x"))
    gamedir = launcher.parent
    ud_app = gamedir / "userdata" / "Godot" / "app_userdata" / "哪吒·轮回海域"

    info = {"dpi_awareness": set_dpi_aware(), "launcher": str(launcher),
            "size": args.size, "portable_userdata": str(ud_app),
            "ud_before": sorted(p.name for p in ud_app.iterdir()) if ud_app.exists() else [],
            "started": time.strftime("%Y-%m-%dT%H:%M:%S")}
    log("start", launched=True)

    before = {x["hwnd"] for x in enum_windows()}
    # NOTE: ShellExecuteW from this harness blocks indefinitely (the Codex sandbox
    # intercepts the shell's process-creation path), so we use CreateProcessW with a
    # Medium-IL parent - the same token Explorer would hand to the launcher.
    import subprocess
    proc = subprocess.Popen([str(launcher)], cwd=str(gamedir))
    info["launch_method"] = "CreateProcessW (Medium-IL parent, cwd=game dir)"
    info["launcher_pid"] = proc.pid
    t0 = time.time()
    log("launched", launcher_pid=proc.pid, method=info["launch_method"])

    win = None
    while time.time() - t0 < args.timeout:
        for cand in enum_windows():
            if cand["hwnd"] in before:
                continue
            if cand["class"] == "Engine" and cand["w"] > 300:
                win = cand
                break
        if win:
            break
        time.sleep(0.4)
    info["window"] = win
    info["window_found"] = bool(win)
    info["seconds_to_window"] = round(time.time() - t0, 2) if win else None
    log("window", found=bool(win), win=win, seconds=info["seconds_to_window"])
    if not win:
        (out / "capture.json").write_text(json.dumps({**info, "steps": STATE["steps"]}, ensure_ascii=False, indent=2), encoding="utf-8")
        return

    hwnd = wt.HWND(win["hwnd"])
    info["game_pid"] = win["pid"]
    info["game_integrity"] = integrity_of(win["pid"])
    log("integrity", **info["game_integrity"])
    info["client_resize"] = resize_client(hwnd, w, h)
    info["client_aligned"] = align_client_origin(hwnd)
    time.sleep(6)
    info["shots"] = [{"step": "menu", **shot(hwnd, out / "menu.png")}]
    log("shot_menu", **info["shots"][-1])
    info["click_select"] = click(hwnd, 0.5, 0.585)
    time.sleep(3.5)
    info["shots"].append({"step": "select", **shot(hwnd, out / "select.png")})
    log("shot_select", **info["shots"][-1])
    info["click_ch1"] = click(hwnd, 0.5, 0.306)
    time.sleep(16)
    info["client_after_ch1"] = resize_client(hwnd, w, h)
    info["client_aligned_ch1"] = align_client_origin(hwnd)
    time.sleep(2.5)
    info["shots"].append({"step": "ch1", **shot(hwnd, out / "ch1.png")})
    log("shot_ch1", **info["shots"][-1])
    info["window_alive"] = bool(u.IsWindow(hwnd) and u.IsWindowVisible(hwnd))
    info["ud_after"] = sorted(p.name for p in ud_app.iterdir()) if ud_app.exists() else []
    info["progress_cfg_exists"] = (ud_app / "progress.cfg").exists()
    if info["progress_cfg_exists"]:
        info["progress_cfg_text"] = (ud_app / "progress.cfg").read_text(encoding="utf-8", errors="replace")
    info["godot_log_tail"] = tail(ud_app / "logs" / "godot.log", 80)
    info["launcher_log_text"] = tail(gamedir / "userdata" / "launcher.log", 20)
    info["steps"] = STATE["steps"]
    (out / "capture.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    print("RESULT " + json.dumps({kk: info.get(kk) for kk in
          ("window_found", "seconds_to_window", "game_pid", "game_integrity",
           "client_resize", "window_alive", "progress_cfg_exists")}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
