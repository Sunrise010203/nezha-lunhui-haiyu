import os, subprocess, sys, time, json
sys.path.insert(0, r"E:\godot_game_by_fable\_review\startup-fix")
from probe_token import token_info
cases = {
 "editor": (r"E:\GODOT\Godot_v4.6.3-stable_win64.exe", ["--quit"], None),
 "game_ws": (r"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe", ["--quit-after","6000"], r"E:\godot_game_by_fable\_tmp_exp_A1"),
 "notepad": (r"C:\Windows\System32\notepad.exe", [], None),
}
for name,(exe,args,ap) in cases.items():
    env = dict(os.environ)
    if ap: env["APPDATA"]=ap
    p = subprocess.Popen([exe]+args, cwd=os.path.dirname(exe), env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    il=None
    for _ in range(30):
        if p.poll() is not None: break
        i=token_info(p.pid); il=i.get("integrity_sid"); 
        if il: break
        time.sleep(0.02)
    print(name, "->", il, "pyIL=Medium(S-1-16-8192)")
    try: p.terminate()
    except Exception: pass
    time.sleep(0.3)
