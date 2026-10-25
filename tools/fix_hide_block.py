# -*- coding: utf-8 -*-
"""修掉 HIDE_A/HIDE_B 调试块里被 PowerShell 吃掉的双引号。"""
import io

P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"
src = io.open(P, "r", encoding="utf-8", errors="replace").read()

start = src.index("\t# 调试开关")
end = src.index("\tif cam != null", start)
block = (
    "\t# 调试开关：HIDE_A/HIDE_B 指定要隐藏的子节点下标区间（定位黑锥用）\n"
    "\tvar ha := OS.get_environment('HIDE_A')\n"
    "\tif ha != '':\n"
    "\t\tvar a0 := int(ha)\n"
    "\t\tvar a1 := int(OS.get_environment('HIDE_B'))\n"
    "\t\tvar ch := get_children()\n"
    "\t\tfor i in range(maxi(a0, 0), mini(a1, ch.size())):\n"
    "\t\t\tvar node := ch[i]\n"
    "\t\t\tif node is Node3D:\n"
    "\t\t\t\t(node as Node3D).visible = false\n"
)
if "\r\n" in src:
    block = block.replace("\n", "\r\n")
src = src[:start] + block + src[end:]
io.open(P, "w", encoding="utf-8", newline="").write(src)
print("fixed")
