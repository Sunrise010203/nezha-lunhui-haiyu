@echo off
set O=E:\godot_game_by_fable\_review\startup-fix
cd /d "E:\godot_game_by_fable\builds\playable-slice"
set APPDATA=E:/godot_game_by_fable/_tmp_exp_logtest
"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe" --verbose --quit-after 120 --log-file E:/godot_game_by_fable/_review/startup-fix/ws_logtest.log > "%O%\lt1.out" 2> "%O%\lt1.err"
echo WS_RC=%ERRORLEVEL% > "%O%\lt1.rc"
set APPDATA=C:\Users\Sunrise\AppData\Roaming
"E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe" --verbose --quit-after 120 --log-file E:/godot_game_by_fable/_review/startup-fix/roaming_run.log > "%O%\lt2.out" 2> "%O%\lt2.err"
echo ROAM_RC=%ERRORLEVEL% > "%O%\lt2.rc"
