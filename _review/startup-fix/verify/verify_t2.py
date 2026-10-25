# Independent verification of portable launcher by ACTUAL Explorer double-click.
# No test environment overrides: Explorer (user shell) launches the file; launcher sets
# APPDATA/TEMP/TMP for the child only.
import ctypes, ctypes.wintypes as wt, os, sys, json, time, hashlib, subprocess, traceback

ROOT = r"E:\godot_game_by_fable"
GAME_DIR = os.path.join(ROOT, "builds", "playable-slice")
LAUNCHER = os.path.join(GAME_DIR, "nezha_ch1_playable_r2_launcher.exe")
GAME = os.path.join(GAME_DIR, "nezha_ch1_playable_r2.exe")
UD = os.path.join(GAME_DIR, "userdata")
PROJ = "哪吒·轮回海域"
PORT_SAVE = os.path.join(UD, "Godot", "app_userdata", PROJ, "progress.cfg")
DEF_SAVE = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", PROJ, "progress.cfg")
DEF_DIR = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", PROJ)
LOG = os.path.join(UD, "launcher.log")
OUT = os.path.join(ROOT, "_review", "startup-fix", "verify")
os.makedirs(OUT, exist_ok=True)

try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    ctypes.windll.user32.SetProcessDPIAware()

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32
advapi32 = ctypes.windll.advapi32

PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
SYNCHRONIZE = 0x00100000
TOKEN_QUERY = 0x0008
INVALID_HANDLE = ctypes.c_void_p(-1).value

kernel32.OpenProcess.restype = wt.HANDLE
kernel32.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
kernel32.CreateToolhelp32Snapshot.restype = wt.HANDLE
kernel32.CreateToolhelp32Snapshot.argtypes = [wt.DWORD, wt.DWORD]
kernel32.WaitForSingleObject.argtypes = [wt.HANDLE, wt.DWORD]
kernel32.GetExitCodeProcess.argtypes = [wt.HANDLE, ctypes.POINTER(wt.DWORD)]
kernel32.CloseHandle.argtypes = [wt.HANDLE]
advapi32.OpenProcessToken.argtypes = [wt.HANDLE, wt.DWORD, ctypes.POINTER(wt.HANDLE)]

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def statfile(p):
    if not os.path.exists(p):
        return {"exists": False}
    st = os.stat(p)
    d = {"exists": True, "size": st.st_size, "mtime": st.st_mtime,
         "mtime_iso": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(st.st_mtime))}
    if st.st_size < 20 * 1024 * 1024:
        d["sha256"] = sha256_file(p)
    return d

def snapshot():
    files = {"game_exe": statfile(GAME), "launcher_exe": statfile(LAUNCHER),
             "portable_save": statfile(PORT_SAVE), "default_save": statfile(DEF_SAVE),
             "launcher_log": statfile(LOG)}
    dirs = {}
    for name, p in [("portable_project", os.path.join(UD, "Godot", "app_userdata", PROJ)),
                    ("portable_logs", os.path.join(UD, "Godot", "app_userdata", PROJ, "logs")),
                    ("default_project", DEF_DIR),
                    ("default_logs", os.path.join(DEF_DIR, "logs"))]:
        try:
            items = []
            for fn in sorted(os.listdir(p)):
                fp = os.path.join(p, fn)
                if os.path.isfile(fp):
                    items.append([fn, os.path.getsize(fp), round(os.path.getmtime(fp), 3)])
            dirs[name] = items
        except Exception as e:
            dirs[name] = "ERR " + str(e)
    return {"files": files, "dirs": dirs, "time": time.strftime("%Y-%m-%d %H:%M:%S")}

def integrity_sid(pid):
    h = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return "openprocess_failed:%d" % ctypes.get_last_error()
    try:
        tok = wt.HANDLE()
        if not advapi32.OpenProcessToken(h, TOKEN_QUERY, ctypes.byref(tok)):
            return "opentoken_failed:%d" % ctypes.get_last_error()
        try:
            size = wt.DWORD(0)
            advapi32.GetTokenInformation(tok, 25, None, 0, ctypes.byref(size))
            buf = ctypes.create_string_buffer(size.value)
            if not advapi32.GetTokenInformation(tok, 25, buf, size, ctypes.byref(size)):
                return "getinfo_failed:%d" % ctypes.get_last_error()
            sid_ptr = ctypes.cast(buf, ctypes.POINTER(ctypes.c_void_p))[0]
            advapi32.ConvertSidToStringSidW.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_wchar_p)]
            s = ctypes.c_wchar_p()
            if advapi32.ConvertSidToStringSidW(sid_ptr, ctypes.byref(s)):
                return s.value
        finally:
            kernel32.CloseHandle(tok)
    finally:
        kernel32.CloseHandle(h)
    return "unknown"

class PROCESSENTRY32(ctypes.Structure):
    _fields_ = [("dwSize", wt.DWORD), ("cntUsage", wt.DWORD), ("th32ProcessID", wt.DWORD),
                ("th32DefaultHeapID", ctypes.POINTER(ctypes.c_ulong)), ("th32ModuleID", wt.DWORD),
                ("cntThreads", wt.DWORD), ("th32ParentProcessID", wt.DWORD),
                ("pcPriClassBase", ctypes.c_long), ("dwFlags", wt.DWORD), ("szExeFile", ctypes.c_char * 260)]

def all_processes():
    snap = kernel32.CreateToolhelp32Snapshot(0x2, 0)
    out = []
    if not snap or snap == INVALID_HANDLE:
        return out
    pe = PROCESSENTRY32(); pe.dwSize = ctypes.sizeof(pe)
    try:
        ok = kernel32.Process32First(snap, ctypes.byref(pe))
        while ok:
            out.append({"pid": pe.th32ProcessID, "ppid": pe.th32ParentProcessID,
                        "threads": pe.cntThreads,
                        "name": pe.szExeFile.decode("mbcs", "replace")})
            ok = kernel32.Process32Next(snap, ctypes.byref(pe))
    finally:
        kernel32.CloseHandle(snap)
    return out

def enum_windows():
    res = []
    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(h, _):
        pid = wt.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(pid))
        cls = ctypes.create_unicode_buffer(256); user32.GetClassNameW(h, cls, 256)
        ttl = ctypes.create_unicode_buffer(512); user32.GetWindowTextW(h, ttl, 512)
        vis = bool(user32.IsWindowVisible(h))
        r = wt.RECT(); user32.GetWindowRect(h, ctypes.byref(r))
        res.append({"hwnd": int(h), "pid": pid.value, "class": cls.value, "title": ttl.value,
                    "visible": vis, "rect": [r.left, r.top, r.right, r.bottom]})
        return True
    user32.EnumWindows(cb, 0)
    return res

def pid_at_point(x, y):
    class POINT(ctypes.Structure):
        _fields_ = [("x", wt.LONG), ("y", wt.LONG)]
    h = user32.WindowFromPoint(POINT(int(x), int(y)))
    pid = wt.DWORD(); user32.GetWindowThreadProcessId(h, ctypes.byref(pid))
    return int(h), pid.value

# --- input ---
class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", wt.LONG), ("dy", wt.LONG), ("mouseData", wt.DWORD), ("dwFlags", wt.DWORD),
                ("time", wt.DWORD), ("dwExtraInfo", ctypes.c_ulonglong)]
class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ctypes.c_ulonglong)]
class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [("uMsg", wt.DWORD), ("wParamL", wt.WORD), ("wParamH", wt.WORD)]
class _U(ctypes.Union):
    _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT), ("hi", HARDWAREINPUT)]
class INPUT(ctypes.Structure):
    _fields_ = [("type", wt.DWORD), ("u", _U)]

def send_inputs(events):
    arr = (INPUT * len(events))()
    for i, (typ, a, b, c, d) in enumerate(events):
        arr[i].type = typ
        if typ == 0:
            arr[i].u.mi = MOUSEINPUT(a, b, c, d, 0, 0)
        else:
            arr[i].u.ki = KEYBDINPUT(a, b, c, d, 0)
    user32.SendInput(len(events), arr, ctypes.sizeof(INPUT))

def click(x, y):
    user32.SetCursorPos(int(x), int(y))
    time.sleep(0.05)
    send_inputs([(0, 0, 0, 0, 0x0002), (0, 0, 0, 0, 0x0004)])

def double_click(x, y):
    user32.SetCursorPos(int(x), int(y))
    time.sleep(0.08)
    send_inputs([(0, 0, 0, 0, 0x0002), (0, 0, 0, 0, 0x0004),
                 (0, 0, 0, 0, 0x0002), (0, 0, 0, 0, 0x0004)])

def alt_f4():
    send_inputs([(1, 0x12, 0, 0, 0), (1, 0x73, 0, 0, 0),
                 (1, 0x73, 0, 0, 0x0002), (1, 0x12, 0, 0, 0x0002)])

def client_origin(hwnd):
    class POINT(ctypes.Structure):
        _fields_ = [("x", wt.LONG), ("y", wt.LONG)]
    p = POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(p))
    return p.x, p.y

def client_size(hwnd):
    r = wt.RECT(); user32.GetClientRect(hwnd, ctypes.byref(r))
    return r.right - r.left, r.bottom - r.top

def resize_client(hwnd, w, h, x=30, y=30):
    wr = wt.RECT(); user32.GetWindowRect(hwnd, ctypes.byref(wr))
    cw, ch = client_size(hwnd)
    dw, dh = (wr.right - wr.left) - cw, (wr.bottom - wr.top) - ch
    user32.SetWindowPos(hwnd, 0, x, y, w + dw, h + dh, 0x0004 | 0x0010)
    time.sleep(0.6)

CAP = {"hwnd": None}

def capture(path):
    from PIL import ImageGrab, ImageStat
    hwnd = CAP["hwnd"]
    cx, cy = client_origin(hwnd)
    w, h = client_size(hwnd)
    img = ImageGrab.grab(bbox=(cx, cy, cx + w, cy + h), all_screens=True)
    img.save(path)
    g = img.convert("L")
    st = ImageStat.Stat(g)
    ex = g.getextrema()
    class POINT(ctypes.Structure):
        _fields_ = [("x", wt.LONG), ("y", wt.LONG)]
    p = POINT(); user32.GetCursorPos(ctypes.byref(p))
    return {"path": os.path.basename(path), "size": [w, h], "luma_mean": round(st.mean[0], 2),
            "luma_extrema": list(ex), "spread": ex[1] - ex[0], "cursor": [p.x, p.y]}

def foreground():
    class POINT(ctypes.Structure):
        _fields_ = [("x", wt.LONG), ("y", wt.LONG)]
    h = user32.GetForegroundWindow()
    pid = wt.DWORD(); user32.GetWindowThreadProcessId(h, ctypes.byref(pid))
    return int(h), pid.value

def force_foreground(hwnd, restore=False):
    fg = user32.GetForegroundWindow()
    tid_fg = user32.GetWindowThreadProcessId(fg, None)
    tid_self = kernel32.GetCurrentThreadId()
    attached = bool(user32.AttachThreadInput(tid_self, tid_fg, True))
    try:
        if restore:
            user32.ShowWindow(hwnd, 9)  # SW_RESTORE
        ok = bool(user32.SetForegroundWindow(hwnd))
    finally:
        if attached:
            user32.AttachThreadInput(tid_self, tid_fg, False)
    return {"attach": attached, "set_fg": ok, "fg": foreground()}

def main():
    result = {"started": time.strftime("%Y-%m-%d %H:%M:%S"), "cwd": os.getcwd()}
    pid_self = kernel32.GetCurrentProcessId()
    result["verifier_process"] = {"pid": pid_self, "integrity": integrity_sid(pid_self),
                                  "env": {k: os.environ.get(k) for k in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP", "USERPROFILE")},
                                  "screen": [user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)]}
    result["before"] = snapshot()
    before_pids = {p["pid"] for p in all_processes()}
    zombies = {p["pid"]: p for p in all_processes() if p["name"].lower() == os.path.basename(GAME).lower()}
    result["preexisting_game_processes"] = zombies

    ps = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                         os.path.join(OUT, "explorer_sel.ps1")], capture_output=True, text=True)
    result["explorer_sel_raw"] = ps.stdout.strip()
    sel = json.loads(ps.stdout.strip().splitlines()[-1])
    if "error" in sel:
        result["status"] = "FAILED_NO_EXPLORER_SELECTION"
        return result
    result["explorer_window"] = sel
    wr = wt.RECT(); user32.GetWindowRect(sel["hwnd"], ctypes.byref(wr))
    rr = sel.get("root_rect") or [0, 0, wr.right - wr.left, wr.bottom - wr.top]
    sx = (wr.right - wr.left) / rr[2] if rr[2] else 1.0
    sy = (wr.bottom - wr.top) / rr[3] if rr[3] else 1.0
    result["uia_scale"] = [sx, sy]
    px = wr.left + (sel["x"] - rr[0]) * sx
    py = wr.top + (sel["y"] - rr[1]) * sy
    pw = sel["w"] * sx; ph = sel["h"] * sy
    cx = px + pw / 2.0
    cy = py + ph / 2.0
    result["item_physical_rect"] = [px, py, pw, ph]
    result["explorer_foreground"] = force_foreground(sel["hwnd"])
    time.sleep(0.8)
    fg = foreground()
    result["foreground_before_click"] = fg
    result["point_owner_before_click"] = pid_at_point(cx, cy)
    if fg[1] != sel["pid"] or pid_at_point(cx, cy)[1] != sel["pid"]:
        result["status"] = "FAILED_EXPLORER_NOT_ON_TOP"
        return result

    t0 = time.time()
    double_click(cx, cy)     # REAL double-click in Explorer on the launcher file
    result["double_click_at"] = [cx, cy]
    result["click_method"] = "SendInput left down/up x2 at Explorer file-item center"

    lp = None
    while time.time() - t0 < 15:
        for p in all_processes():
            if p["name"].lower() == os.path.basename(LAUNCHER).lower() and p["pid"] not in before_pids:
                lp = p; break
        if lp:
            break
        time.sleep(0.02)
    if not lp:
        result["double_click_result"] = "launcher not started within 12s after physical double-click"
        fallback_t = time.time()
        subprocess.Popen(["explorer.exe", LAUNCHER])
        result["fallback_launch"] = {"method": "explorer.exe <launcher path> (ShellExecute through Explorer process, NOT a physical double-click)",
                                     "at": time.strftime("%H:%M:%S")}
        while time.time() - fallback_t < 15:
            for p in all_processes():
                if p["name"].lower() == os.path.basename(LAUNCHER).lower() and p["pid"] not in before_pids:
                    lp = p; break
            if lp:
                break
            time.sleep(0.02)
    if not lp:
        result["status"] = "FAILED_LAUNCHER_NOT_STARTED"
        return result
    lpid = lp["pid"]
    result["launcher"] = {"pid": lpid, "ppid": lp["ppid"], "threads": lp["threads"],
                          "integrity": integrity_sid(lpid), "started_after_s": round(time.time() - t0, 3)}
    lhandle = kernel32.OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, False, lpid)
    if not lhandle:
        result["status"] = "FAILED_LAUNCHER_HANDLE"
        return result

    win = None
    while time.time() - t0 < 90:
        for w in enum_windows():
            if w["class"] == "Engine" and w["visible"] and w["pid"] not in zombies:
                win = w; break
        if win:
            break
        time.sleep(0.05)
    if not win:
        result["status"] = "FAILED_NO_WINDOW"
        result["launcher_log"] = open(LOG, "r", encoding="utf-8", errors="replace").read()[-2000:]
        return result
    result["seconds_to_window"] = round(time.time() - t0, 3)
    result["window_initial"] = win
    gpid = win["pid"]
    ghandle = kernel32.OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, False, gpid)
    if not ghandle:
        result["status"] = "FAILED_GAME_HANDLE"
        return result
    gproc = [p for p in all_processes() if p["pid"] == gpid]
    cs = wt.DWORD()
    kernel32.ProcessIdToSessionId(gpid, ctypes.byref(cs))
    result["game"] = {"pid": gpid, "integrity": integrity_sid(gpid), "session": cs.value,
                      "ppid": gproc[0]["ppid"] if gproc else None,
                      "threads": gproc[0]["threads"] if gproc else None}
    CAP["hwnd"] = win["hwnd"]

    result["game_foreground"] = force_foreground(win["hwnd"], restore=True)
    resize_client(win["hwnd"], 1600, 900)
    result["client"] = list(client_size(win["hwnd"]))
    result["game_foreground2"] = force_foreground(win["hwnd"])
    time.sleep(9)

    caps = []
    ox, oy = client_origin(win["hwnd"]); w, h = client_size(win["hwnd"])
    result["click_points"] = {"select": [ox + w * 0.5, oy + h * 0.585],
                              "ch1": [ox + w * 0.5, oy + h * 0.306]}
    result["foreground_game"] = foreground()
    result["point_owner_game"] = pid_at_point(ox + w * 0.5, oy + h * 0.585)
    caps.append(capture(os.path.join(OUT, "menu.png")))
    time.sleep(0.5)
    click(ox + w * 0.5, oy + h * 0.585)   # 选择关卡
    time.sleep(3)
    caps.append(capture(os.path.join(OUT, "select.png")))
    click(ox + w * 0.5, oy + h * 0.306)   # 第一章
    time.sleep(4)
    caps.append(capture(os.path.join(OUT, "ch1.png")))
    time.sleep(8)
    result["window_alive_after_ch1"] = bool(user32.IsWindow(win["hwnd"])) and bool(user32.IsWindowVisible(win["hwnd"]))
    result["game_integrity_after_ch1"] = integrity_sid(gpid)
    caps.append(capture(os.path.join(OUT, "ch1_after8s.png")))
    result["captures"] = caps

    # exit with real Alt+F4
    result["game_foreground3"] = force_foreground(win["hwnd"])
    time.sleep(0.5)
    alt_f4()
    r, code = kernel32.WaitForSingleObject(ghandle, 30000), wt.DWORD(0xFFFFFFFF)
    kernel32.GetExitCodeProcess(ghandle, ctypes.byref(code))
    result["game_exit"] = {"wait": r, "code": code.value, "hex": "0x%08x" % code.value,
                           "seconds": round(time.time() - t0, 2)}
    if r != 0:
        user32.PostMessageW(win["hwnd"], 0x0010, 0, 0)
        r2 = kernel32.WaitForSingleObject(ghandle, 20000)
        c2 = wt.DWORD(0xFFFFFFFF); kernel32.GetExitCodeProcess(ghandle, ctypes.byref(c2))
        result["game_exit_after_wmclose"] = {"wait": r2, "code": c2.value, "hex": "0x%08x" % c2.value}
    rl = kernel32.WaitForSingleObject(lhandle, 20000)
    lc = wt.DWORD(0xFFFFFFFF); kernel32.GetExitCodeProcess(lhandle, ctypes.byref(lc))
    result["launcher_exit"] = {"wait": rl, "code": lc.value, "hex": "0x%08x" % lc.value}
    result["window_gone"] = not bool(user32.IsWindow(win["hwnd"]))
    time.sleep(1)
    result["launcher_log"] = open(LOG, "r", encoding="utf-8", errors="replace").read()[-3000:]
    result["after"] = snapshot()
    result["status"] = "COMPLETED"
    return result

if __name__ == "__main__":
    try:
        r = main()
    except Exception:
        r = {"status": "EXCEPTION", "traceback": traceback.format_exc()}
        try:
            r["launcher_log"] = open(LOG, "r", encoding="utf-8", errors="replace").read()[-3000:]
        except Exception:
            pass
    with open(os.path.join(OUT, "launcher_result.json"), "w", encoding="utf-8") as f:
        json.dump(r, f, ensure_ascii=False, indent=2)
    print(json.dumps(r, ensure_ascii=False, indent=2))
