#!/usr/bin/env python3
"""Launch the shipped exe under a chosen environment and record exactly what happens.

Modes:
  --env default   : inherit the real user environment (APPDATA=C:\\Users\\<u>\\AppData\\Roaming) -> emulates double-click
  --env appdata=<path> : override APPDATA only (process-local, like the t7 verifier did)
  --via startfile : use ShellExecuteW (exactly what Explorer double-click uses) instead of CreateProcess
Writes a JSON record + stdout/stderr next to it.
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import json
import os
import subprocess
import sys
import time
from pathlib import Path

u = ctypes.windll.user32

STILL_ACTIVE = 259
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000


def windows_of(pid):
    found = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(hwnd, _):
        wpid = wt.DWORD()
        u.GetWindowThreadProcessId(hwnd, ctypes.byref(wpid))
        if wpid.value == pid:
            cls = ctypes.create_unicode_buffer(256)
            u.GetClassNameW(hwnd, cls, 256)
            title = ctypes.create_unicode_buffer(512)
            u.GetWindowTextW(hwnd, title, 512)
            found.append({
                "hwnd": hwnd,
                "class": cls.value,
                "title": title.value,
                "visible": bool(u.IsWindowVisible(hwnd)),
            })
        return True

    u.EnumWindows(cb, 0)
    return found


def snapshot(dirpath: Path):
    if not dirpath.exists():
        return {"path": str(dirpath), "exists": False}
    items = []
    for p in sorted(dirpath.rglob("*")):
        try:
            st = p.stat()
        except OSError:
            continue
        items.append({"rel": str(p.relative_to(dirpath)), "size": st.st_size,
                      "mtime": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(st.st_mtime))})
    return {"path": str(dirpath), "exists": True, "items": items}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", required=True)
    ap.add_argument("--out", required=True, help="directory for the record")
    ap.add_argument("--env", default="default")
    ap.add_argument("--args", default="", help="extra engine args, space separated")
    ap.add_argument("--via", default="create", choices=["create", "startfile"])
    ap.add_argument("--timeout", type=float, default=30.0)
    ap.add_argument("--tag", default="run")
    a = ap.parse_args()

    exe = Path(a.exe).resolve()
    out = Path(a.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    tag = a.tag

    if a.env in ("default", "appdata"):
        env = dict(os.environ)
        env_note = "inherited"
    else:
        # Explorer-like clean environment: no MSYS / DSH shell variables.
        base = os.environ.get("USERPROFILE", r"C:\Users\Sunrise")
        env = {
            "SystemRoot": r"C:\Windows",
            "windir": r"C:\Windows",
            "SystemDrive": "C:",
            "PATH": r"C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0",
            "PATHEXT": ".COM;.EXE;.BAT;.CMD",
            "TEMP": os.path.join(base, "AppData", "Local", "Temp"),
            "TMP": os.path.join(base, "AppData", "Local", "Temp"),
            "USERPROFILE": base,
            "HOMEDRIVE": base[:2],
            "HOMEPATH": base[2:],
            "USERNAME": os.environ.get("USERNAME", "Sunrise"),
            "USERDOMAIN": os.environ.get("USERDOMAIN", ""),
            "APPDATA": os.path.join(base, "AppData", "Roaming"),
            "LOCALAPPDATA": os.path.join(base, "AppData", "Local"),
            "ComSpec": r"C:\Windows\system32\cmd.exe",
            "NUMBER_OF_PROCESSORS": os.environ.get("NUMBER_OF_PROCESSORS", "24"),
            "PROCESSOR_ARCHITECTURE": "AMD64",
            "OS": "Windows_NT",
            "PSModulePath": "",
            "LANG": "zh_CN.UTF-8",
        }
        env_note = "clean-explorer-like"
    if "appdata=" in a.env:
        env["APPDATA"] = a.env.split("appdata=", 1)[1]
        env_note += " APPDATA=" + env["APPDATA"]
    extra = [s for s in a.args.split(" ") if s]

    userdata = Path(env.get("APPDATA", "")) / "Godot" / "app_userdata" / "哪吒·轮回海域"
    before = snapshot(userdata)

    info = {
        "tag": tag, "exe": str(exe), "cwd": str(exe.parent), "env_mode": env_note,
        "APPDATA": env.get("APPDATA"), "LOCALAPPDATA": env.get("LOCALAPPDATA"),
        "extra_args": extra, "via": a.via, "started": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "userdata_before": before,
    }

    so_path, se_path = out / f"{tag}.stdout.txt", out / f"{tag}.stderr.txt"
    so = open(so_path, "wb")
    se = open(se_path, "wb")
    t0 = time.time()
    if a.via == "startfile":
        import ctypes.wintypes
        r = ctypes.windll.shell32.ShellExecuteW(None, "open", str(exe), None, str(exe.parent), 1)
        info["shellexecute_ret"] = r
        # find the process by exe name
        proc = None
        pid = None
        deadline = time.time() + 10
        while time.time() < deadline and pid is None:
            ps = subprocess.run(["powershell", "-NoProfile", "-Command",
                                 "(Get-CimInstance Win32_Process -Filter \"Name='%s'\" | Sort-Object CreationDate -Descending | Select-Object -First 1).ProcessId" % exe.name],
                                capture_output=True, text=True)
            txt = ps.stdout.strip()
            if txt:
                try:
                    pid = int(txt.splitlines()[-1].strip())
                except ValueError:
                    pid = None
            time.sleep(0.3)
        info["pid"] = pid
        if pid:
            h = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
            info["handle"] = h
            deadline = time.time() + a.timeout
            while time.time() < deadline:
                code = wt.DWORD()
                if not ctypes.windll.kernel32.GetExitCodeProcess(h, ctypes.byref(code)) or code.value != STILL_ACTIVE:
                    info["exit_code"] = code.value
                    break
                time.sleep(0.25)
            info["windows"] = windows_of(pid)
    else:
        proc = subprocess.Popen([str(exe)] + extra, cwd=str(exe.parent), env=env,
                                stdout=so, stderr=se)
        info["pid"] = proc.pid
        win_seen = None
        deadline = time.time() + a.timeout
        while time.time() < deadline:
            rc = proc.poll()
            if rc is not None:
                info["exit_code"] = rc
                break
            if win_seen is None:
                ws = windows_of(proc.pid)
                vis = [w for w in ws if w["visible"]]
                if vis:
                    win_seen = {"at_s": round(time.time() - t0, 2), "windows": ws}
            time.sleep(0.25)
        info["windows_seen"] = win_seen
        info["windows_final"] = windows_of(proc.pid)
        if proc.poll() is None:
            info["still_running_at_timeout"] = True
    info["elapsed_s"] = round(time.time() - t0, 2)
    so.close()
    se.close()

    code = info.get("exit_code")
    if code is not None:
        info["exit_hex"] = hex(code & 0xFFFFFFFF)
        info["exit_ntstatus_guess"] = {
            0xC0000005: "ACCESS_VIOLATION", 0xC0000409: "STACK_BUFFER_OVERRUN",
            0xC000001D: "ILLEGAL_INSTRUCTION", 0xC0000374: "HEAP_CORRUPTION",
            0x80000003: "BREAKPOINT", 0xC00000FD: "STACK_OVERFLOW",
        }.get(code & 0xFFFFFFFF, "")
    info["userdata_after"] = snapshot(userdata)
    info["stdout_text"] = so_path.read_text(encoding="utf-8", errors="replace")[-6000:]
    info["stderr_text"] = se_path.read_text(encoding="utf-8", errors="replace")[-6000:]
    (out / f"{tag}.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: info.get(k) for k in
                      ("tag", "pid", "exit_code", "exit_hex", "exit_ntstatus_guess", "elapsed_s",
                       "windows_seen", "still_running_at_timeout")}, ensure_ascii=False))
    print("stdout:", repr(info["stdout_text"][:800]))
    print("stderr:", repr(info["stderr_text"][:800]))


if __name__ == "__main__":
    main()
