# -*- coding: utf-8 -*-
"""level_1：压暗新走道材质 + 移除与模块化环境冲突的旧装饰。"""
P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"
s = open(P, "rb").read().decode("utf-8")
orig = s

pairs = [
    # 压暗材质，贴近参考图的深青暗调
    ('Color(0.205, 0.335, 0.365), Color(0.015, 0.05, 0.06), 0.06, 0.85',
     'Color(0.105, 0.180, 0.200), Color(0.012, 0.040, 0.048), 0.06, 0.85'),
    ('Color(0.145, 0.245, 0.275), Color(0.01, 0.03, 0.04), 0.08, 0.8',
     'Color(0.072, 0.125, 0.145), Color(0.008, 0.024, 0.030), 0.08, 0.8'),
    ('Color(0.085, 0.145, 0.165), Color(0.005, 0.02, 0.025), 0.1, 0.75',
     'Color(0.040, 0.072, 0.085), Color(0.004, 0.015, 0.020), 0.1, 0.75'),
    # 旧背景巨环
    ('\t_decor_great_ring(45, -30, 9.0, mat_gold)\n\t_decor_great_ring(110, -34, 12.0, mat_trim)',
     '\t# 巨环已移除：纵深改由新的柱列 / 栏杆模块承担'),
    # 水晶
    ('\tfor i in crystal_spots.size():\n\t\tvar s: Array = crystal_spots[i]\n\t\t_decor_crystal(Vector3(s[0], s[1], s[2]), i % 2 == 0, rng, i % 3 == 0)',
     '\t# 水晶已移除：前景细节交给模块化碎石 / 藤壶'),
    # 海草
    ('\tfor i in 30:\n\t\tvar x := rng.randf_range(-8.0, 160.0)\n\t\tvar z := rng.randf_range(-7.0, -3.5)\n\t\t_decor_kelp(x, z, rng)',
     '\t# 海草已移除：与模块化柱列重叠，读成一团'),
    # 旧残灯
    ('\tfor x in [8.0, 44.0, 76.0, 116.0, 146.0]:\n\t\t_decor_lantern(Vector3(x, 5.5 + sin(x) * 1.5, -4.0))',
     '\t# 旧残灯已移除：改由 T16 石灯笼模块提供'),
]

hits = 0
for a, b in pairs:
    if a in s:
        s = s.replace(a, b, 1)
        hits += 1
    else:
        print("MISS:", a.split("\\n")[0][:60])

open(P, "wb").write(s.encode("utf-8"))
print("applied", hits, "of", len(pairs))
