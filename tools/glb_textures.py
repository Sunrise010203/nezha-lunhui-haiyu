# -*- coding: utf-8 -*-
"""从 GLB 里抽出内嵌贴图（basecolor 优先），拼成联络表，用来认领编号 ↔ 资产对应关系。"""
import json
import os
import struct
import sys
from pathlib import Path

OUT = r"E:\godot_game_by_fable\game_assets\_tex_check"
os.makedirs(OUT, exist_ok=True)


def glb_chunks(path):
    data = Path(path).read_bytes()
    magic, ver, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF"
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


def dump_images(path):
    g, bins = glb_chunks(path)
    saved = []
    for i, img in enumerate(g.get("images", [])):
        bv = g["bufferViews"][img["bufferView"]]
        start = bv.get("byteOffset", 0)
        raw = bins[start:start + bv["byteLength"]]
        mime = img.get("mimeType", "image/png")
        ext = ".png" if "png" in mime else ".jpg"
        p = os.path.join(OUT, f"{Path(path).stem}_{i}{ext}")
        Path(p).write_bytes(raw)
        saved.append(p)
    return saved


if __name__ == "__main__":
    for f in sys.argv[1:]:
        print(f, "->", len(dump_images(f)), "images")
