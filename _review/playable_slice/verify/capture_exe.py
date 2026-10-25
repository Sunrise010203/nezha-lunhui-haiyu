import ctypes, ctypes.wintypes as wt, subprocess, time, os, sys
from PIL import Image
exe = r'E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe'
out = r'E:\godot_game_by_fable\_review\playable_slice\verify\exe_window.png'
env = os.environ.copy()
env['APPDATA'] = r'E:\godot_game_by_fable\_review\playable_slice\verify\export_run\appdata'
p = subprocess.Popen([exe, '--resolution', '1920x1080', '--position', '0,0'], env=env)
print('PID', p.pid, flush=True)
user32 = ctypes.windll.user32
user32.SetProcessDPIAware()
EnumWindows = user32.EnumWindows
EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)
GetWindowThreadProcessId = user32.GetWindowThreadProcessId
IsWindowVisible = user32.IsWindowVisible
GetWindowTextW = user32.GetWindowTextW
GetWindowTextLengthW = user32.GetWindowTextLengthW
GetWindowRect = user32.GetWindowRect
PrintWindow = user32.PrintWindow
SetForegroundWindow = user32.SetForegroundWindow
ShowWindow = user32.ShowWindow
wins=[]
def cb(hwnd, lparam):
    pid=wt.DWORD()
    GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    if pid.value==p.pid and IsWindowVisible(hwnd):
        n=GetWindowTextLengthW(hwnd)
        buf=ctypes.create_unicode_buffer(n+1)
        GetWindowTextW(hwnd, buf, n+1)
        wins.append((hwnd, buf.value))
    return True
for i in range(60):
    time.sleep(0.25)
    wins.clear()
    EnumWindows(EnumWindowsProc(cb), 0)
    if wins:
        break
print('WINS', wins, flush=True)
if not wins:
    print('NO_WINDOW')
    p.kill(); sys.exit(2)
hwnd, title = wins[0]
ShowWindow(hwnd, 5); SetForegroundWindow(hwnd)
time.sleep(5)
class RECT(ctypes.Structure):
    _fields_=[('left',ctypes.c_long),('top',ctypes.c_long),('right',ctypes.c_long),('bottom',ctypes.c_long)]
r=RECT(); GetWindowRect(hwnd, ctypes.byref(r))
w=r.right-r.left; h=r.bottom-r.top
print('RECT', w, h, flush=True)
if w<=0 or h<=0:
    w,h=1920,1080
bmp=ctypes.windll.gdi32.CreateCompatibleDC(0)
b=ctypes.windll.gdi32.CreateCompatibleBitmap(ctypes.windll.gdi32.CreateCompatibleDC(0), w, h)
ctypes.windll.gdi32.SelectObject(bmp, b)
ok=PrintWindow(hwnd, bmp, 2)
print('PRINTWINDOW', ok, flush=True)
# use PrintWindow into a bitmap selected in DC
class BITMAPINFOHEADER(ctypes.Structure):
    _fields_=[('biSize',ctypes.c_uint32),('biWidth',ctypes.c_long),('biHeight',ctypes.c_long),('biPlanes',ctypes.c_ushort),('biBitCount',ctypes.c_ushort),('biCompression',ctypes.c_uint32),('biSizeImage',ctypes.c_uint32),('biXPelsPerMeter',ctypes.c_long),('biYPelsPerMeter',ctypes.c_long),('biClrUsed',ctypes.c_uint32),('biClrImportant',ctypes.c_uint32)]
class BITMAPINFO(ctypes.Structure):
    _fields_=[('bmiHeader',BITMAPINFOHEADER),('bmiColors',ctypes.c_uint32*3)]
bi=BITMAPINFO(); bi.bmiHeader.biSize=ctypes.sizeof(BITMAPINFOHEADER); bi.bmiHeader.biWidth=w; bi.bmiHeader.biHeight=-h; bi.bmiHeader.biPlanes=1; bi.bmiHeader.biBitCount=32
buf=ctypes.create_string_buffer(w*h*4)
lines=ctypes.windll.gdi32.GetDIBits(bmp, b, 0, h, buf, ctypes.byref(bi), 0)
print('GETDIBITS', lines, flush=True)
img=Image.frombuffer('RGBA',(w,h),buf,'raw','BGRA',0,1)
img.save(out)
print('SAVED', out, flush=True)
p.kill()
