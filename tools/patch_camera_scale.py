# -*- coding: utf-8 -*-
"""镜头取景放大 + 角色略微放大。"""
import io

def patch(path, pairs):
    raw = io.open(path, "r", encoding="utf-8", errors="replace").read()
    out = raw
    hits = []
    for old, new in pairs:
        if old in out:
            out = out.replace(old, new)
            hits.append(old)
    io.open(path, "w", encoding="utf-8", newline="").write(out)
    print(path, "->", hits)

# 1) 相机：拉远 + 视角略宽
patch(r"E:\godot_game_by_fable\001\scripts\player_camera.gd", [
    ("const BASE_DIST := 8.2", "const BASE_DIST := 9.6"),
    ("fov = 46.0", "fov = 48.0"),
])

# 2) level_1 的强制 fov：40 -> 44（更宽的画幅）
patch(r"E:\godot_game_by_fable\001\scripts\level_1.gd", [
    ("cam.fov = 40.0", "cam.fov = 44.0"),
])

# 3) 角色：1.9 -> 2.06（约 +8%）
patch(r"E:\godot_game_by_fable\001\scripts\player.gd", [
    ('Game.load_model(MODEL_PATH, 1.9, 90.0, 0.0, 0.0, true, false)',
     'Game.load_model(MODEL_PATH, 2.06, 90.0, 0.0, 0.0, true, false)'),
])
