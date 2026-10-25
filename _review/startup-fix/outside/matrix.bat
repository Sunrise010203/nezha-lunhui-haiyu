@echo off
set O=E:\godot_game_by_fable\_review\startup-fix\outside\m
if not exist "%O%" mkdir "%O%"
set EXE=E:\godot_game_by_fable\builds\playable-slice\nezha_ch1_playable_r2.exe
set CD=E:\godot_game_by_fable\builds\playable-slice
call :one A_Croot "C:/_expC"
call :one B_Local "C:/Users/Sunrise/AppData/Local/_expB"
call :one C_Roam "C:/Users/Sunrise/AppData/Roaming/_expA"
call :one D_Eroot "E:/_expD2"
call :one E_ws "E:/godot_game_by_fable/_tmp_exp_c3"
goto :eof
:one
set TAG=%~1
set APPDATA=%~2
cd /d "%CD%"
"%EXE%" --verbose --quit-after 240 > "%O%\%TAG%.out" 2> "%O%\%TAG%.err"
echo %ERRORLEVEL% > "%O%\%TAG%.rc"
goto :eof
