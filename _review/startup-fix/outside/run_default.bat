@echo off
setlocal
set LOGDIR=E:\godot_game_by_fable\_review\startup-fix\outside
echo APPDATA=%APPDATA% > "%LOGDIR%\env.txt"
echo USERPROFILE=%USERPROFILE% >> "%LOGDIR%\env.txt"
echo USERNAME=%USERNAME% >> "%LOGDIR%\env.txt"
whoami >> "%LOGDIR%\env.txt"
whoami /groups /fo csv >> "%LOGDIR%\env.txt" 2>&1
cd /d "E:\godot_game_by_fable\builds\playable-slice"
del /q "%LOGDIR%\rc.txt" 2>nul
"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe" --verbose --quit-after 600 > "%LOGDIR%\out.txt" 2> "%LOGDIR%\err.txt"
echo %ERRORLEVEL% > "%LOGDIR%\rc.txt"
