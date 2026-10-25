import os, json, subprocess, sys, time
OUT = r"E:\godot_game_by_fable\_review\startup-fix\outside"
res = {"appdata": os.environ.get("APPDATA"), "pid": os.getpid(), "t": time.strftime("%H:%M:%S")}
ud = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "\u54ea\u5412\u00b7\u8f6e\u56de\u6d77\u57df")
logs = os.path.join(ud, "logs")
def attempt(name, fn):
    try:
        res[name] = {"ok": True, "value": fn()}
    except Exception as e:
        res[name] = {"ok": False, "err": "%s: %s" % (type(e).__name__, e)}
attempt("list_ud", lambda: sorted(os.listdir(ud))[:6])
attempt("list_logs", lambda: sorted(os.listdir(logs)))
def newfile():
    p = os.path.join(logs, "probe_%d.txt" % os.getpid())
    with open(p, "w", encoding="utf-8") as f:
        f.write("hello\n")
    n = os.path.getsize(p); os.remove(p); return n
attempt("create_file_in_logs", newfile)
def append_log():
    p = os.path.join(logs, "godot.log")
    with open(p, "a", encoding="utf-8") as f:
        f.write("[probe] append %s\n" % time.strftime("%H:%M:%S"))
    return os.path.getsize(p)
attempt("append_godot_log", append_log)
def newdir():
    p = os.path.join(ud, "probe_dir_%d" % os.getpid())
    os.makedirs(p); os.rmdir(p); return True
attempt("mkdir_in_ud", newdir)
def mkdirtree():
    p = os.path.join(os.environ["APPDATA"], "Godot_probe_tree", "a", "b")
    os.makedirs(p); os.removedirs(os.path.join(os.environ["APPDATA"], "Godot_probe_tree")); return True
attempt("mkdir_tree_in_roaming", mkdirtree)
def icacls(p):
    r = subprocess.run(["icacls", p], capture_output=True)
    return r.stdout.decode("gbk", "replace")[:900]
attempt("icacls_logs", lambda: icacls(logs))
attempt("icacls_ud", lambda: icacls(ud))
open(os.path.join(OUT, "pyprobe.json"), "w", encoding="utf-8").write(json.dumps(res, ensure_ascii=False, indent=1))
