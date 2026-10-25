# -*- coding: utf-8 -*-
"""把 art_assets 下的单体资产图拼成联络表（4 列，带编号/中文名）。"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = r"E:\godot_game_by_fable\art_assets"
FB = r"C:\Windows\Fonts\msyhbd.ttc"
FR = r"C:\Windows\Fonts\msyh.ttc"

ITEMS = [
    ("ch1_abyss_eye", "归墟之喉 · 巨眼"),
    ("ch1_coral_fan", "红珊瑚扇"),
    ("ch1_pillar_dragon_capital", "柱头蟠龙雕饰"),
    ("ch2_warden", "棘狱守卫（Boss）"),
    ("ch2_skull_gate_ornament", "骷髅门饰"),
    ("ch2_cage_bones", "悬吊铁笼 · 囚徒骨堆"),
    ("ch2_bone_debris", "平台骨堆 / 镣铐尸骸"),
    ("ch3_void_rock", "虚空岩块"),
    ("ch3_dragon_ring_fitting", "铜环 · 龙首扣件"),
    ("ch3_sea_eye_core", "海眼 · 二阶段巨瞳"),
    ("ch4_whale_bone_arch", "鲸骨拱 / 椎骨段"),
    ("ch4_chiwen", "螭吻（Boss）"),
    ("ch4_drowned_statue", "骨白雕像"),
    ("ch4_coral_mutation", "潮蚀异化珊瑚"),
    ("ch4_bell_dragon_knob", "沉钟 · 钟顶龙钮"),
]

TILE, COLS, PAD, LBL, TOP = 430, 4, 18, 62, 86
rows = (len(ITEMS) + COLS - 1) // COLS
W = COLS * TILE + (COLS + 1) * PAD
H = TOP + rows * (TILE + LBL + PAD) + PAD
canvas = Image.new("RGB", (W, H), (17, 20, 25))
d = ImageDraw.Draw(canvas)
d.text((PAD, 20), "TRIPO 单体资产参考图 · 15 件", font=ImageFont.truetype(FB, 36), fill=(255, 255, 255))
d.text((PAD, 62), "浅灰底 / 单物体 / 居中 / 3-4 视角  ·  直接可作 Tripo 图生 3D 输入",
       font=ImageFont.truetype(FR, 20), fill=(150, 165, 180))

for i, (slug, cn) in enumerate(ITEMS):
    p = os.path.join(OUT, slug + ".png")
    if not os.path.exists(p):
        continue
    c, r = i % COLS, i // COLS
    x = PAD + c * (TILE + PAD)
    y = TOP + r * (TILE + LBL + PAD)
    im = Image.open(p).convert("RGB")
    im.thumbnail((TILE, TILE), Image.LANCZOS)
    cell = Image.new("RGB", (TILE, TILE), (232, 232, 230))
    cell.paste(im, ((TILE - im.width) // 2, (TILE - im.height) // 2))
    canvas.paste(cell, (x, y))
    d.text((x + 2, y + TILE + 8), f"T{i + 1:02d}", font=ImageFont.truetype(FB, 22), fill=(255, 178, 64))
    d.text((x + 62, y + TILE + 8), cn, font=ImageFont.truetype(FR, 22), fill=(235, 240, 245))
    d.text((x + 62, y + TILE + 34), slug, font=ImageFont.truetype(FR, 16), fill=(130, 145, 160))

out = os.path.join(OUT, "contact_sheet_v2.png")
canvas.save(out)
print(out, canvas.size)
