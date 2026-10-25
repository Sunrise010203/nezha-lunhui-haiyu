@echo off
"C:\msys64\ucrt64\bin\python.exe" "E:\godot_game_by_fable\_review\startup-fix\outside\probe.py" > "E:\godot_game_by_fable\_review\startup-fix\outside\pyprobe_stdout.txt" 2>&1
echo rc=%ERRORLEVEL% >> "E:\godot_game_by_fable\_review\startup-fix\outside\pyprobe_stdout.txt"
