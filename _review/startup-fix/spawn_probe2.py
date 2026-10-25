import os, subprocess, sys, time, json
sys.path.insert(0, r"E:\godot_game_by_fable\_review\startup-fix")
from probe_token import token_info

exe = r"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe"
env = dict(os.environ); env["APPDATA"] = r"E:\godot_game_by_fable\_tmp_exp_A1"
t0 = time.time()
p = subprocess.Popen([exe, "--quit-after", "6000"], cwd=os.path.dirname(exe), env=env,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
samples = []
for i in range(40):
    if p.poll() is not None:
        samples.append((round(time.time()-t0,3), "exited", p.returncode)); break
    info = token_info(p.pid)
    samples.append((round(time.time()-t0,3), info.get("integrity_sid"), info.get("elevation_type")))
    time.sleep(0.05)
print(json.dumps(samples[:12], indent=None))
try: p.terminate()
except Exception: pass
