import ctypes, sys, time
from pathlib import Path
sys.path.insert(0, r'E:\godot_game_by_fable\_review\playable_slice\verify_t7')
import launch_capture as lc

exe = Path(r'E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe')
out = Path(r'E:\godot_game_by_fable\_review\playable_slice\verify_r3_exe_keys')
appdata = Path(r'E:\godot_game_by_fable\_tmp_t4r3\appdata')
out.mkdir(parents=True, exist_ok=True)
import os, subprocess
env = dict(os.environ); env['APPDATA'] = str(appdata)
p = subprocess.Popen([str(exe)], cwd=str(exe.parent), env=env,
                     stdout=open(out/'stdout.log','wb'), stderr=open(out/'stderr.log','wb'))
hwnd=None
for _ in range(90):
    if p.poll() is not None: print('EXITED', p.returncode); sys.exit(1)
    hwnd=lc.find_window(p.pid)
    if hwnd: break
    time.sleep(.5)
print('HWND', hwnd, 'pid', p.pid)
lc.u.ShowWindow(hwnd, 9); lc.u.SetForegroundWindow(hwnd)
print('client', lc.resize_client(hwnd, 1920, 1080))
for _ in range(3):
    cx,cy=lc.client_origin(hwnd)
    if (cx,cy)==(0,0): break
    import ctypes.wintypes as wt
    wr=wt.RECT(); lc.u.GetWindowRect(hwnd, ctypes.byref(wr))
    lc.u.SetWindowPos(hwnd,0,wr.left-cx,wr.top-cy,0,0,lc.SWP_NOSIZE|lc.SWP_NOZORDER); time.sleep(.3)
time.sleep(10)
lc.u.SetWindowPos(hwnd,-1,0,0,0,0,lc.SWP_NOSIZE|lc.SWP_SHOWWINDOW)
lc.u.BringWindowToTop(hwnd); lc.u.SetForegroundWindow(hwnd); time.sleep(1)
print('FG-before', lc.u.GetForegroundWindow(), 'HWND', hwnd)
def key(vk, up=False):
    lc.u.keybd_event(vk, 0, 2 if up else 0, 0)
def tap(vk):
    key(vk, False); time.sleep(.08); key(vk, True); time.sleep(.25)
time.sleep(1)
lc.shot(hwnd, out/'menu.png')
# menu: down to 选择关卡 then enter
tap(0x28); tap(0x0D); time.sleep(4)
lc.shot(hwnd, out/'select.png')
# select first chapter
tap(0x0D); time.sleep(12)
lc.shot(hwnd, out/'ch1.png')
print('FG-after', lc.u.GetForegroundWindow())
p.terminate()
try: p.wait(5)
except: p.kill()
print('DONE')
