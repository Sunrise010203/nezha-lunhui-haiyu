@echo off
set APPDATA=E:/_expD5
cd /d "E:\godot_game_by_fable\builds\playable-slice"
"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe" --verbose --quit-after 180 > "E:\godot_game_by_fable\_review\startup-fix\outside\everyone.out" 2> "E:\godot_game_by_fable\_review\startup-fix\outside\everyone.err"
echo %ERRORLEVEL% > "E:\godot_game_by_fable\_review\startup-fix\outside\everyone.rc"
