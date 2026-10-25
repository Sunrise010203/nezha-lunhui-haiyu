import sys, time
from pathlib import Path
sys.path.insert(0, r'E:\godot_game_by_fable\_review\playable_slice\verify_t7')
import launch_capture as lc

def click(hwnd, fx, fy):
    cw, ch = lc.client_rect(hwnd)
    cx, cy = lc.client_origin(hwnd)
    x, y = int(cx + fx * cw), int(cy + fy * ch)
    lc.u.SetWindowPos(hwnd, -1, cx, cy, 0, 0, lc.SWP_NOSIZE | lc.SWP_SHOWWINDOW)
    lc.u.BringWindowToTop(hwnd)
    lc.u.SetForegroundWindow(hwnd)
    time.sleep(0.5)
    print('FG', lc.u.GetForegroundWindow(), 'HWND', hwnd, 'click', x, y, flush=True)
    lc.u.SetCursorPos(x, y)
    time.sleep(0.4)
    lc.u.mouse_event(1, 0, 0, 0, 0)
    time.sleep(0.15)
    lc.u.mouse_event(2, 0, 0, 0, 0)
    lc.u.mouse_event(4, 0, 0, 0, 0)
    time.sleep(0.6)
    return [x, y]

lc.click = click
lc.run_one(Path(r'E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe'),
           Path(r'E:\godot_game_by_fable\_review\playable_slice\verify_r3_exe_click'),
           1920, 1080, Path(r'E:\godot_game_by_fable\_tmp_t4r3\appdata'))
