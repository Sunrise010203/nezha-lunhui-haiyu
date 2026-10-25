# -*- coding: utf-8 -*-
"""读取 GLB（二进制 glTF）头部 JSON，列出节点名 / 网格 / 面数 / 材质 / 贴图 / 包围盒。
用法: python inspect_glb.py <file> [file...]
"""
import json
import struct
import sys
from pathlib import Path

def load_glb(path):
    data = Path(path).read_bytes()
    magic, ver, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF", magic
    off = 12
    js = None
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        off += 8 + clen + ((4 - clen % 4) % 4 if clen % 4 else 0)
    return js, len(data)

def tri_count(g):
    total = 0
    for m in g.get("meshes", []):
        for p in m.get("primitives", []):
            if "indices" in p:
                total += g["accessors"][p["indices"]]["count"] // 3
            else:
                mode = p.get("mode", 4)
                if mode == 4:
                    total += g["accessors"][p["attributes"]["POSITION"]]["count"] // 3
    return total

def bbox(g):
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for m in g.get("meshes", []):
        for p in m.get("primitives", []):
            acc = g["accessors"][p["attributes"]["POSITION"]]
            if "min" in acc:
                mn = [min(a, b) for a, b in zip(mn, acc["min"])]
                mx = [max(a, b) for a, b in zip(mx, acc["max"])]
    return mn, mx

for path in sys.argv[1:]:
    g, size = load_glb(path)
    nodes = [n.get("name", "?") for n in g.get("nodes", [])]
    mats = [m.get("name", "?") for m in g.get("materials", [])]
    imgs = len(g.get("images", []))
    mn, mx = bbox(g)
    print(f"\n=== {Path(path).name}  ({size/1e6:.1f} MB) ===")
    print(f"  nodes={len(nodes)} meshes={len(g.get('meshes', []))} tris={tri_count(g)} mats={len(mats)} imgs={imgs}")
    print(f"  bbox min={[round(v,2) for v in mn]} max={[round(v,2) for v in mx]}")
    print(f"  node names: {nodes[:8]}")
    print(f"  materials: {mats[:8]}")
    if g.get("images"):
        ims = [i.get("mimeType", "?") for i in g["images"]]
        print(f"  image mimes: {ims[:6]}")
