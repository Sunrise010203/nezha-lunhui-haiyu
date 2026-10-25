# -*- coding: utf-8 -*-
"""把 level_1 的环境参数对齐到样板场景（scene_ch1.gd）的一套值。

差异来源：样板用 fov36 平视 + ACES + 指数雾 0.008 + 体积雾 0.006，
游戏 LevelBase 用 fov46 + FILMIC + 深度雾(6→110) + 体积雾 0.010，
所以同一批模块在两边观感完全不同。
"""
import io

P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"
raw = io.open(P, "r", encoding="utf-8", errors="replace").read()
nl = "\r\n" if "\r\n" in raw else "\n"

anchor = "\t_decor_vortex(Vector3(158, 8, -36))"
assert anchor in raw
new_anchor = anchor + nl + "\t_align_env_to_showcase()"
raw = raw.replace(anchor, new_anchor, 1)

func = nl.join([
    "",
    "",
    "func _align_env_to_showcase() -> void:",
    "\t## 让关卡的环境与样板 scene_ch1 一致：ACES + 指数雾 + 同样的体积雾与 ambient。",
    "\tvar we: WorldEnvironment = null",
    "\tfor n in get_children():",
    "\t\tif n is WorldEnvironment:",
    "\t\t\twe = n",
    "\t\t\tbreak",
    "\tif we == null or we.environment == null:",
    "\t\treturn",
    "\tvar e := we.environment",
    "\te.ambient_light_color = Color(0.26, 0.55, 0.64)",
    "\te.ambient_light_energy = 0.42",
    "\te.tonemap_mode = Environment.TONE_MAPPER_ACES",
    "\te.tonemap_exposure = 1.05",
    "\te.fog_enabled = true",
    "\te.fog_mode = Environment.FOG_MODE_EXPONENTIAL",
    "\te.fog_light_color = Color(0.06, 0.28, 0.34)",
    "\te.fog_light_energy = 0.40",
    "\te.fog_density = 0.008",
    "\te.fog_aerial_perspective = 0.20",
    "\te.volumetric_fog_enabled = true",
    "\te.volumetric_fog_density = 0.006",
    "\te.volumetric_fog_albedo = Color(0.42, 0.78, 0.86)",
    "\te.volumetric_fog_emission = Color(0.015, 0.08, 0.10)",
    "\te.volumetric_fog_emission_energy = 0.30",
    "\te.volumetric_fog_anisotropy = 0.40",
    "\te.volumetric_fog_length = 55.0",
    "\te.adjustment_enabled = true",
    "\te.adjustment_contrast = 1.08",
    "\te.adjustment_saturation = 1.04",
    "\t# 相机画幅也靠近样板：fov 46 → 40，稍微拉平一点透视",
    "\tif cam != null:",
    "\t\tcam.fov = 40.0",
    "",
])

if "_align_env_to_showcase() -> void:" not in raw:
    raw = raw.rstrip() + nl + func

io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("env alignment injected")
