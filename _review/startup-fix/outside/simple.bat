@echo off
set LOGDIR=E:\godot_game_by_fable\_review\startup-fix\outside
echo hello > "%LOGDIR%\simple.txt" 2>&1
echo APPDATA=%APPDATA% >> "%LOGDIR%\simple.txt"
set UD=%APPDATA%\Godot\app_userdata
for /d %i in ("%UD%\*") do echo DIR=%i >> "%LOGDIR%\simple.txt"
