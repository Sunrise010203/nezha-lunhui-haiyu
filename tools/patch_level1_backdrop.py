# -*- coding: utf-8 -*-
"""把 level_1 的背景换成第一章参考图，并隐藏旧陶罐。"""
import io

P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"
with io.open(P, "rb") as f:
    raw = f.read().decode("utf-8", "replace")
nl = "\r\n" if "\r\n" in raw else "\n"

old_bd = '\tvar bd := Game.tex("res://art/backdrop.png")'
new_bd = '\tvar bd := Game.tex("res://art/ref/ch1_corridor.png")'
assert old_bd in raw
raw = raw.replace(old_bd, new_bd, 1)

old_tints = "\t\t_build_backdrop_layers(bd, [" + nl + "\t\t\tColor(0.72, 0.82, 0.86), Color(0.48, 0.56, 0.60)," + nl + "\t\t\tColor(0.24, 0.30, 0.34)], 80.0)"
new_tints = "\t\t_build_backdrop_layers(bd, [" + nl + "\t\t\tColor(0.86, 0.92, 0.95), Color(0.52, 0.60, 0.64)," + nl + "\t\t\tColor(0.22, 0.27, 0.31)], 80.0)"
if old_tints in raw:
    raw = raw.replace(old_tints, new_tints, 1)
    print("tints updated")
else:
    print("tints MISS")

# 旧陶罐：直接不生成（保留可击碎逻辑给后续替换）
old_urns = "\tfor u: Array in urns:"
if old_urns in raw:
    raw = raw.replace(old_urns, "\t# 旧陶罐已停用：等待换成新模块化可破坏物" + nl + "\tfor u: Array in []:", 1)
    print("urns disabled")
else:
    print("urns MISS")

with io.open(P, "wb") as f:
    f.write(raw.encode("utf-8"))
print("backdrop ->", new_bd.strip())
