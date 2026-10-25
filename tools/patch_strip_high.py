# -*- coding: utf-8 -*-
"""level_1：清掉旧构建遗留在高空（y>7）的大件装饰，避免黑色锥体压在画面上。"""
import io

P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"
raw = io.open(P, "r", encoding="utf-8", errors="replace").read()
nl = "\r\n" if "\r\n" in raw else "\n"

anchor = "\t_decor_vortex(Vector3(158, 8, -36))"
assert anchor in raw, "anchor missing"

inject = nl.join([
    anchor,
    "\t# 清理旧构建遗留的高空大件（会把画面压出一块黑影）",
    "\tawait get_tree().process_frame",
    "\tfor n in find_children(\"*\", \"MeshInstance3D\", true, false):",
    "\t\tvar mi := n as MeshInstance3D",
    "\t\tif mi == null or mi.mesh == null:",
    "\t\t\tcontinue",
    "\t\tvar s: Vector3 = mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()",
    "\t\tif mi.global_position.y > 7.0 and maxf(s.x, maxf(s.y, s.z)) > 2.5:",
    "\t\t\tmi.visible = false",
])

raw = raw.replace(anchor, inject, 1)
io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("injected strip pass")
