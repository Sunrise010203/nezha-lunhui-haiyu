# -*- coding: utf-8 -*-
"""level_1：移除与模块化环境冲突的旧装饰（兼容 CRLF / LF）。"""
P = r"E:\godot_game_by_fable\001\scripts\level_1.gd"
raw = open(P, "rb").read().decode("utf-8")
crlf = "\r\n" in raw
nl = "\r\n" if crlf else "\n"

blocks = [
    (
        "\t_decor_great_ring(45, -30, 9.0, mat_gold){n}\t_decor_great_ring(110, -34, 12.0, mat_trim)",
        "\t# 巨环已移除：纵深改由新的柱列 / 栏杆模块承担",
    ),
    (
        "\tfor i in crystal_spots.size():{n}\t\tvar s: Array = crystal_spots[i]{n}\t\t_decor_crystal(Vector3(s[0], s[1], s[2]), i % 2 == 0, rng, i % 3 == 0)",
        "\t# 水晶已移除：前景细节交给模块化碎石 / 藤壶",
    ),
    (
        "\tfor i in 30:{n}\t\tvar x := rng.randf_range(-8.0, 160.0){n}\t\tvar z := rng.randf_range(-7.0, -3.5){n}\t\t_decor_kelp(x, z, rng)",
        "\t# 海草已移除：与模块化柱列重叠，读成一团",
    ),
    (
        "\tfor x in [8.0, 44.0, 76.0, 116.0, 146.0]:{n}\t\t_decor_lantern(Vector3(x, 5.5 + sin(x) * 1.5, -4.0))",
        "\t# 旧残灯已移除：改由 T16 石灯笼模块提供",
    ),
]

hits = 0
for a, b in blocks:
    a = a.replace("{n}", nl)
    if a in raw:
        raw = raw.replace(a, b, 1)
        hits += 1
    else:
        print("MISS", a.split(nl)[0][:50])

open(P, "wb").write(raw.encode("utf-8"))
print("applied", hits, "of", len(blocks), "crlf=", crlf)
