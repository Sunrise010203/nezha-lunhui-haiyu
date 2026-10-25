# -*- coding: utf-8 -*-
"""数值校验：联络表每个格子是否真是当前磁盘上的单体图（避免肉眼/缓存误判）。"""
import os
from PIL import Image, ImageChops, ImageStat

OUT = r"E:\godot_game_by_fable\art_assets"
SHEET = os.path.join(OUT, "contact_sheet_v2.png")
TILE, COLS, PAD, LBL, TOP = 430, 4, 18, 62, 86
SLUGS = ["ch1_abyss_eye", "ch1_coral_fan", "ch1_pillar_dragon_capital", "ch2_warden",
         "ch2_skull_gate_ornament", "ch2_cage_bones", "ch2_bone_debris", "ch3_void_rock",
         "ch3_dragon_ring_fitting", "ch3_sea_eye_core", "ch4_whale_bone_arch", "ch4_chiwen",
         "ch4_drowned_statue", "ch4_coral_mutation", "ch4_bell_dragon_knob"]

sheet = Image.open(SHEET).convert("RGB")
print("sheet", sheet.size, os.path.getsize(SHEET))
worst = 0.0
for i, slug in enumerate(SLUGS):
    c, r = i % COLS, i // COLS
    x = PAD + c * (TILE + PAD)
    y = TOP + r * (TILE + LBL + PAD)
    cell = sheet.crop((x, y, x + TILE, y + TILE))
    im = Image.open(os.path.join(OUT, slug + ".png")).convert("RGB")
    im.thumbnail((TILE, TILE), Image.LANCZOS)
    ref = Image.new("RGB", (TILE, TILE), (232, 232, 230))
    ref.paste(im, ((TILE - im.width) // 2, (TILE - im.height) // 2))
    mae = sum(ImageStat.Stat(ImageChops.difference(cell, ref)).mean) / 3
    worst = max(worst, mae)
    flag = "OK " if mae < 2.0 else "!! "
    print(f"{flag}T{i+1:02d} {slug:<32} MAE={mae:6.2f}")
print("worst MAE =", round(worst, 2))
