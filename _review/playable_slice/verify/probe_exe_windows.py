import ctypes, ctypes.wintypes as wt, subprocess, time, os
exe=r'E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe'
env=os.environ.copy(); env['APPDATA']=r'E:\godot_game_by_fable\_review\playable_slice\verify\export_run\appdata'
p=subprocess.Popen([exe,'--resolution','1920x1080'],env=env)
print('pid',p.pid,flush=True)
time.sleep(8)
print('poll',p.poll(),flush=True)
os.system('tasklist /FI "IMAGENAME eq nezha_ch1_playable_r2.exe" /FO LIST')
u=ctypes.windll.user32; u.SetProcessDPIAware()
EnumWindows=u.EnumWindows; CB=ctypes.WINFUNCTYPE(ctypes.c_bool,wt.HWND,wt.LPARAM)
GetPID=u.GetWindowThreadProcessId; IsVis=u.IsWindowVisible; GetLen=u.GetWindowTextLengthW; GetTxt=u.GetWindowTextW
rows=[]
def cb(h,l):
    pid=wt.DWORD(); GetPID(h,ctypes.byref(pid)); n=GetLen(h); b=ctypes.create_unicode_buffer(n+1); GetTxt(h,b,n+1)
    rows.append((pid.value,IsVis(h),b.value)); return True
EnumWindows(CB(cb),0)
for r in rows:
    if r[0]==p.pid or 'nezha' in r[2].lower() or '轮' in r[2]:
        print('WIN',r,flush=True)
print('total windows',len(rows),flush=True)
p.kill()
