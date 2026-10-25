# Run 3: real Explorer double-click was already performed; SmartScreen gate (CHXSmartScreen.exe)
# is handled by clicking "更多信息" then "仍要运行" (real user flow on this machine), then the
# portable launcher's window / chapter 1 / exit / save protection are verified.
# No environment overrides are used anywhere: the launcher sets APPDATA/TEMP/TMP for its child only.
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

def click(x, y, pause=0.05):
    user32.SetCursorPos(int(x), int(y))
    time.sleep(pause)
    send_inputs([(0, 0, 0, 0, 0x0002), (0, 0, 0, 0, 0x0004)])

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
    time.sleep(0.8)

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

def force_foreground(hwnd):
    fg = user32.GetForegroundWindow()
    tid_fg = user32.GetWindowThreadProcessId(fg, None)
    tid_self = kernel32.GetCurrentThreadId()
    attached = bool(user32.AttachThreadInput(tid_self, tid_fg, True))
    try:
        ok = bool(user32.SetForegroundWindow(hwnd))
    finally:
        if attached:
            user32.AttachThreadInput(tid_self, tid_fg, False)
    return {"attach": attached, "set_fg": ok, "fg": foreground()}

def read_log():
    raw = open(LOG, "rb").read()
    try:
        if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
            return raw.decode("utf-16")
        return raw.decode("utf-8", "replace")
    except Exception:
        return raw.decode("utf-16", "replace")

def find_smartscreen_dialog():
    # dialog frame: ApplicationFrameWindow owned by explorer whose content process is CHXSmartScreen.exe
    chx = {p["pid"] for p in all_processes() if p["name"].lower() == "chxsmartscreen.exe"}
    if not chx:
        return None
    for w in enum_windows():
        if w["visible"] and w["class"] == "ApplicationFrameWindow" and w["pid"] in {p["pid"] for p in all_processes() if p["name"].lower() == "explorer.exe"}:
            # identify by size ratio similar to dialog (820x759) and position not fullscreen
            x1, y1, x2, y2 = w["rect"]
            ww, hh = x2 - x1, y2 - y1
            if 700 < ww < 1000 and 650 < hh < 900:
                return w
    return None

def press_run_anyway(dialog):
    """Click the white '仍要运行' button: left of the two white buttons at dialog bottom."""
    from PIL import ImageGrab
    x1, y1, x2, y2 = dialog["rect"]
    img = ImageGrab.grab(bbox=(x1, y1, x2, y2), all_screens=True).convert("RGB")
    w, h = img.size
    px = img.load()
    # find white-ish pixels in bottom 25%
    cols = {}
    for yy in range(int(h * 0.72), h):
        for xx in range(w):
            r, g, b = px[xx, yy]
            if r > 235 and g > 235 and b > 235:
                cols.setdefault(xx // 10, 0)
                cols[xx // 10] += 1
    if not cols:
        return None
    xs = sorted(cols)
    # cluster contiguous bucket indices
    clusters = []
    cur = [xs[0]]
    for v in xs[1:]:
        if v - cur[-1] <= 2:
            cur.append(v)
        else:
            clusters.append(cur); cur = [v]
    clusters.append(cur)
    clusters = [c for c in clusters if sum(cols[k] for k in c) > 500]
    if len(clusters) < 2:
        return None
    clusters.sort(key=lambda c: sum(cols[k] for k in c), reverse=True)
    clusters = sorted(clusters[:2], key=lambda c: min(c))
    left = clusters[0]
    cx = (min(left) * 10 + max(left) * 10 + 10) // 2
    # find vertical center of white block near cx
    ys = []
    for yy in range(int(h * 0.72), h):
        r, g, b = px[min(max(cx, 0), w - 1), yy]
        if r > 235 and g > 235 and b > 235:
            ys.append(yy)
    if not ys:
        return None
    cy = (min(ys) + max(ys)) // 2
    click(x1 + cx, y1 + cy, pause=0.15)
    return {"button": "仍要运行", "abs": [x1 + cx, y1 + cy], "dialog_rect": dialog["rect"]}

def main():
    result = {"started": time.strftime("%Y-%m-%d %H:%M:%S"), "cwd": os.getcwd(),
              "method": "Explorer physical double-click already performed; SmartScreen '仍要运行' handled by real mouse; launcher then verified"}
    pid_self = kernel32.GetCurrentProcessId()
    result["verifier_process"] = {"pid": pid_self, "integrity": integrity_sid(pid_self),
                                  "env": {k: os.environ.get(k) for k in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP", "USERPROFILE")},
                                  "screen": [user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)]}
    result["before"] = snapshot()
    procs = all_processes()
    before_pids = {p["pid"] for p in procs}
    zombies = {p["pid"] for p in procs if p["name"].lower() == os.path.basename(GAME).lower()}
    result["preexisting_game_processes"] = sorted(zombies)

    dlg = find_smartscreen_dialog()
    result["smartscreen_dialog_before"] = dlg
    if not dlg:
        result["status"] = "FAILED_NO_SMARTSCREEN_DIALOG_EXPECTED_STATE"
        return result
    result["smartscreen_process"] = [p for p in procs if p["name"].lower() == "chxsmartscreen.exe"]
    result["smartscreen_click"] = press_run_anyway(dlg)
    if not result["smartscreen_click"]:
        result["status"] = "FAILED_SMARTSCREEN_BUTTON_NOT_FOUND"
        return result
    t0 = time.time()

    lp = None
    while time.time() - t0 < 20:
        for p in all_processes():
            if p["name"].lower() == os.path.basename(LAUNCHER).lower() and p["pid"] not in before_pids:
                lp = p; break
        if lp:
            break
        time.sleep(0.03)
    if not lp:
        result["status"] = "FAILED_LAUNCHER_NOT_STARTED_AFTER_SMARTSCREEN_ALLOW"
        result["windows"] = enum_windows()
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
        result["launcher_log"] = read_log()[-3000:]
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

    result["game_foreground"] = force_foreground(win["hwnd"])
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
    caps.append(capture(os.path.join(OUT, "run3_menu.png")))
    time.sleep(0.5)
    click(ox + w * 0.5, oy + h * 0.585)   # 选择关卡
    time.sleep(3)
    caps.append(capture(os.path.join(OUT, "run3_select.png")))
    click(ox + w * 0.5, oy + h * 0.306)   # 第一章
    time.sleep(4)
    caps.append(capture(os.path.join(OUT, "run3_ch1.png")))
    time.sleep(8)
    result["window_alive_after_ch1"] = bool(user32.IsWindow(win["hwnd"])) and bool(user32.IsWindowVisible(win["hwnd"]))
    result["game_integrity_after_ch1"] = integrity_sid(gpid)
    caps.append(capture(os.path.join(OUT, "run3_ch1_after8s.png")))
    result["captures"] = caps

    result["game_foreground3"] = force_foreground(win["hwnd"])
    time.sleep(0.5)
    alt_f4()
    r = kernel32.WaitForSingleObject(ghandle, 30000)
    code = wt.DWORD(0xFFFFFFFF)
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
    result["launcher_log"] = read_log()[-3000:]
    result["after"] = snapshot()
    result["status"] = "COMPLETED"
    return result

if __name__ == "__main__":
    try:
        r = main()
    except Exception:
        r = {"status": "EXCEPTION", "traceback": traceback.format_exc()}
        try:
            r["launcher_log"] = read_log()[-3000:]
        except Exception:
            pass
    with open(os.path.join(OUT, "launcher_result_run3.json"), "w", encoding="utf-8") as f:
        json.dump(r, f, ensure_ascii=False, indent=2)
    print(json.dumps(r, ensure_ascii=False, indent=2))
