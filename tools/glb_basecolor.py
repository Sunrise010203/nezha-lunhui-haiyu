# -*- coding: utf-8 -*-
"""按材质引用关系抽出 basecolor，并拼成认领表。"""
import json
import os
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SRC_DIR = r"C:\Users\Sunrise\Downloads"
OUT = r"E:\godot_game_by_fable\game_assets\_tex_check"
FB = r"C:\Windows\Fonts\msyhbd.ttc"
SHEET = r"E:\godot_game_by_fable\game_assets\_basecolor_sheet.png"
os.makedirs(OUT, exist_ok=True)

FILES = [f"{i}.glb" for i in range(2, 16)] + ["001 (1).glb"]


def chunks(path):
    data = Path(path).read_bytes()
    magic, ver, length = struct.unpack_from("<4sII", data, 0)
    off, js, bins = 12, None, None
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            bins = chunk
        off += 8 + clen + ((4 - clen % 4) % 4 if clen % 4 else 0)
    return js, bins


def basecolor(path):
    g, bins = chunks(path)
    mat = g["materials"][0]
    pbr = mat.get("pbrMetallicRoughness", {})
    tex = pbr.get("baseColorTexture")
    if tex is None:
        return None
    texdef = g["textures"][tex["index"]]
    img = g["images"][texdef["source"]]
    bv = g["bufferViews"][img["bufferView"]]
    start = bv.get("byteOffset", 0)
    return bins[start:start + bv["byteLength"]], img.get("mimeType", "image/png")


saved = []
for name in FILES:
    src = os.path.join(SRC_DIR, name)
    if not os.path.exists(src):
        continue
    data, mime = basecolor(src)
    ext = ".png" if "png" in mime else ".jpg"
    p = os.path.join(OUT, Path(name).stem.replace(" ", "_").replace("(", "").replace(")", "") + "_bc" + ext)
    Path(p).write_bytes(data)
    saved.append((name, p))
    print(name, p, len(data) // 1024, "KB", mime)

TILE, COLS, PAD, TOP, LBL = 300, 5, 12, 54, 40
rows = (len(saved) + COLS - 1) // COLS
W = COLS * (TILE + PAD) + PAD
H = TOP + rows * (TILE + LBL) + PAD
canvas = Image.new("RGB", (W, H), (18, 18, 20))
d = ImageDraw.Draw(canvas)
d.text((PAD, 12), "GLB basecolor ↔ 资产认领表", font=ImageFont.truetype(FB, 26), fill=(255, 255, 255))
for i, (name, p) in enumerate(saved):
    c, r = i % COLS, i // COLS
    x = PAD + c * (TILE + PAD)
    y = TOP + r * (TILE + LBL)
    im = Image.open(p).convert("RGB")
    im.thumbnail((TILE, TILE), Image.LANCZOS)
    canvas.paste(im, (x + (TILE - im.width) // 2, y + (TILE - im.height) // 2))
    d.text((x + 2, y + TILE + 8), name, font=ImageFont.truetype(FB, 20), fill=(255, 190, 90))
canvas.save(SHEET)
print("sheet", SHEET)
