# -*- coding: utf-8 -*-
"""浮台底部垂石：双面渲染 + 略提亮，避免只看到锥体背面的一片纯黑。"""
import io

P = r"E:\godot_game_by_fable\001\scripts\level_base.gd"
raw = io.open(P, "r", encoding="utf-8", errors="replace").read()
nl = "\r\n" if "\r\n" in raw else "\n"

old = "\tGame.add_mesh(body, tip, mat_stone, Vector3(0, -1.0, 0))"
new = nl.join([
    "\tvar tip_mat: StandardMaterial3D = mat_stone.duplicate()",
    "\ttip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED",
    "\ttip_mat.albedo_color = Color(0.16, 0.24, 0.26)",
    "\tGame.add_mesh(body, tip, tip_mat, Vector3(0, -1.0, 0))",
])
if old in raw:
    raw = raw.replace(old, new, 1)
    io.open(P, "w", encoding="utf-8", newline="").write(raw)
    print("tip material fixed")
else:
    print("anchor missing")
