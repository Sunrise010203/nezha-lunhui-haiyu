# -*- coding: utf-8 -*-
"""参考图 vs 引擎复刻 上下对照图。"""
import sys
from PIL import Image, ImageDraw, ImageFont

REF = r"E:\godot_game_by_fable\art_refs\ch1_corridor_20261020_130544_0.png"
ENG = r"E:\godot_game_by_fable\game_assets\_scenes\f_start3.png"
OUT = r"E:\godot_game_by_fable\game_assets\_scenes\compare_f_start3.png"
FB = r"C:\Windows\Fonts\msyhbd.ttc"

W = 1720
im_ref = Image.open(REF).convert("RGB")
im_eng = Image.open(ENG).convert("RGB")
h_ref = int(im_ref.height * W / im_ref.width)
h_eng = int(im_eng.height * W / im_eng.width)
im_ref = im_ref.resize((W, h_ref), Image.LANCZOS)
im_eng = im_eng.resize((W, h_eng), Image.LANCZOS)

BAR = 46
H = BAR * 2 + h_ref + h_eng
canvas = Image.new("RGB", (W, H), (14, 16, 20))
d = ImageDraw.Draw(canvas)
f = ImageFont.truetype(FB, 26)
d.text((16, 10), "参考图（AI 场景概念）", font=f, fill=(255, 190, 90))
canvas.paste(im_ref, (0, BAR))
y2 = BAR + h_ref
d.rectangle([0, y2, W, y2 + BAR], fill=(14, 16, 20))
d.text((16, y2 + 10), "游戏内 level_1 起点（模块化环境 + 参考图远景 + 新雾/色调）", font=f, fill=(120, 220, 235))
canvas.paste(im_eng, (0, y2 + BAR))
canvas.save(OUT)
print(OUT, canvas.size)
