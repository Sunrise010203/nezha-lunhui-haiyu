# -*- coding: utf-8 -*-
"""关掉 level_1 里用 GLB 石柱拼的背景断柱长廊（会和参考图背景冲突、
且个别柱子的锚点在顶部，缩放后像倒挂的黑锥）。"""
import io

P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"
raw = io.open(P, "r", encoding="utf-8", errors="replace").read()
nl = "\r\n" if "\r\n" in raw else "\n"

old = "\tfor i in 26:" + nl + "\t\tvar x := -10.0 + i * 7.0 + rng.randf_range(-2.0, 2.0)"
new = "\t# 背景断柱长廊停用：远景改由参考图承担，中景柱子由 T17+T18 模块补" + nl + "\tfor i in 0:" + nl + "\t\tvar x := -10.0 + i * 7.0 + rng.randf_range(-2.0, 2.0)"
if old in raw:
    raw = raw.replace(old, new, 1)
    print("pillar loop disabled")
else:
    print("pillar loop MISS")

io.open(P, "w", encoding="utf-8", newline="").write(raw)
