@echo off
set LOGDIR=E:\godot_game_by_fable\_review\startup-fix\outside
cd /d "C:\Users\Sunrise\AppData\Roaming\Godot\app_userdata\哪吒·轮回海域\logs"
echo probe > "%LOGDIR%\write_probe.txt" 2>"%LOGDIR%\write_probe_err.txt"
echo exit=%ERRORLEVEL% >> "%LOGDIR%\write_probe.txt"
echo newfile > probe_new.txt 2>>"%LOGDIR%\write_probe_err.txt"
echo newexit=%ERRORLEVEL% >> "%LOGDIR%\write_probe.txt"
icacls . > "%LOGDIR%\logs_icacls.txt" 2>&1
dir /a > "%LOGDIR%\logs_dir.txt" 2>&1
icacls "C:\Users\Sunrise\AppData\Roaming\Godot\app_userdata\哪吒·轮回海域" > "%LOGDIR%\ud_icacls.txt" 2>&1
