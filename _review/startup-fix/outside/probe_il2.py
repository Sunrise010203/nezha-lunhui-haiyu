import os, subprocess, sys, time, json
sys.path.insert(0, r"E:\godot_game_by_fable\_review\startup-fix")
from probe_token import token_info
res = {"py": token_info(os.getpid()).get("integrity_sid")}
def probe(name, exe, args, ap=None):
    env = dict(os.environ)
    if ap: env["APPDATA"] = ap
    try:
        p = subprocess.Popen([exe]+args, cwd=os.path.dirname(exe), env=env,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        res[name] = "spawn-fail: %s" % e; return
    il = None
    for _ in range(60):
        if p.poll() is not None: break
        i = token_info(p.pid).get("integrity_sid")
        if i and i != "err": il = i; break
        time.sleep(0.02)
    res[name] = il
    try: p.terminate()
    except Exception: pass
    time.sleep(0.3)
probe("notepad_ws", r"E:\godot_game_by_fable\_probe_bin\notepad_copy.exe", [])
probe("notepad_sys", r"C:\Windows\System32\notepad.exe", [])
probe("game_ws_appdata", r"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe", ["--quit-after","6000"], r"E:\godot_game_by_fable\_tmp_exp_A1")
open(r"E:\godot_game_by_fable\_review\startup-fix\outside\ilprobe2.json","w").write(json.dumps(res, indent=1))
