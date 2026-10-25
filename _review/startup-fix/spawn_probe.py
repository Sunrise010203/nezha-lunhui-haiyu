import os, subprocess, sys, time, json
sys.path.insert(0, r"E:\godot_game_by_fable\_review\startup-fix")
from probe_token import token_info

exe = r"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe"
env = dict(os.environ)
env["APPDATA"] = r"E:\godot_game_by_fable\_tmp_exp_A1"
p = subprocess.Popen([exe, "--quit-after", "6000"], cwd=os.path.dirname(exe), env=env,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(2.0)
info = token_info(p.pid)
info["alive"] = (p.poll() is None)
print(json.dumps(info, indent=1)[:2500])
p.terminate()
