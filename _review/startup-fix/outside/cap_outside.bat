@echo off
cd /d E:\godot_game_by_fable\_review\startup-fix
"C:\Users\Sunrise\AppData\Local\Programs\Python\Python311\python.exe" capture_launcher.py --launcher "E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2_launcher.exe" --out "E:\godot_game_by_fable\_review\startup-fix\cap_outside" --size 1600x900 > "E:\godot_game_by_fable\_review\startup-fix\cap_outside.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "E:\godot_game_by_fable\_review\startup-fix\cap_outside.log"
