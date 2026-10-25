# -*- coding: utf-8 -*-
"""把 preview_proj/scene_ch1.gd 字节级复制进 001 工程，并把外部绝对路径改成 res://。"""
import sys

src, dst = sys.argv[1], sys.argv[2]
b = open(src, "rb").read()

reps = [
    (b'const OUT := "E:/godot_game_by_fable/game_assets/_scenes"', b'const OUT := "user://env_shots"'),
    (b'const GLB := "E:/godot_game_by_fable/game_assets/glb_game"', b'const GLB := "res://art/models/glb_game"'),
    (b'const REF := "E:/godot_game_by_fable/art_refs/ch1_corridor_20261020_130544_0.png"', b'const REF := "res://art/ref/ch1_corridor.png"'),
    (b'ch1_v16.png', b'env_ch1_showcase.png'),
    (b'SHOT ch1_v16', b'SHOT env_ch1_showcase'),
    (b'DirAccess.make_dir_recursive_absolute(OUT)', b'DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))'),
    (b'Image.load_from_file(REF)', b'Image.load_from_file(ProjectSettings.globalize_path(REF))'),
]

total = 0
for a, c in reps:
    n = b.count(a)
    total += n
    b = b.replace(a, c)
    print("replace %d x %s" % (n, a[:48].decode("ascii", "replace")))

open(dst, "wb").write(b)
print("written", dst, "hits", total)
