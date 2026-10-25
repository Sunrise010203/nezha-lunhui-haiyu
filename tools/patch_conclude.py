# -*- coding: utf-8 -*-
"""两处收尾修正：
1) 背景板加宽到 200 宽（原来 118 宽居中在 x=80，起点看不到左侧，露出黑边）；
2) 隐藏检查点那根“通光柱”——黑色巨型倒锥就是它（CylinderMesh 高 5.5，近距离投影成倒三角）。
"""
import io
import re

P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"
raw = io.open(P, "r", encoding="utf-8", errors="replace").read()
nl = "\r\n" if "\r\n" in raw else "\n"
changed = []

# --- 1) 收尾扫描：藏在 _align_env_to_showcase 的末尾 ---
marker = "\tif cam != null:"
tail_fix = nl.join([
    "\t# 收尾：检查点的通光柱是纯黑且巨大的圆柱，近距离会被读成一块黑色倒锥，先关掉",
    "\tfor mi in find_children('*', 'MeshInstance3D', true, false):",
    "\t\tvar m := mi as MeshInstance3D",
    "\t\tif m == null or m.mesh == null:",
    "\t\t\tcontinue",
    "\t\tif m.mesh is CylinderMesh and m.get_aabb().size.y > 4.0 and m.global_position.y > 2.0:",
    "\t\t\tm.visible = false",
    "",
])
if "检查点的通光柱" not in raw:
    raw = raw.replace(marker, tail_fix + marker, 1)
    changed.append("hide check-point beam")

# --- 2) 背景板尺寸 ---
for old, new in (
    ("Vector2(118.0, 50.6)", "Vector2(210.0, 72.0)"),
    ("Vector2(118, 50.6)", "Vector2(210, 72)"),
):
    if old in raw:
        raw = raw.replace(old, new)
        changed.append("backdrop " + old + " -> " + new)

io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("changed:", changed)
