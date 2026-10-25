import os, subprocess, sys, time, json
sys.path.insert(0, r"E:\godot_game_by_fable\_review\startup-fix")
from probe_token import token_info
out = {"py_integrity": token_info(os.getpid()).get("integrity_sid")}
exe = r"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe"
env = dict(os.environ); env["APPDATA"] = r"E:\godot_game_by_fable\_tmp_exp_A1"
p = subprocess.Popen([exe, "--quit-after", "6000"], cwd=os.path.dirname(exe), env=env,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
for _ in range(60):
    if p.poll() is not None: break
    i = token_info(p.pid).get("integrity_sid")
    if i and i != "err":
        out["game_integrity"] = i; break
    time.sleep(0.02)
out["game_user_sid"] = token_info(p.pid).get("user_sid")
try: p.terminate()
except Exception: pass
open(r"E:\godot_game_by_fable\_review\startup-fix\outside\ilprobe.json","w").write(json.dumps(out, indent=1))
