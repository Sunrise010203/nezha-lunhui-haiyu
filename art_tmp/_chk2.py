
import os, struct, hashlib
SRC = r"E:\godot_game_by_fable\art_tmp\nezha_bake"
for f in sorted(os.listdir(SRC)):
    p = os.path.join(SRC, f)
    b = open(p, "rb").read(33)
    w, h = struct.unpack(">II", b[16:24])
    depth, ctype = b[24], b[25]
    print(f, "w", w, "h", h, "bitdepth", depth, "colortype", ctype,
          "size", os.path.getsize(p), "md5", hashlib.md5(open(p,"rb").read()).hexdigest()[:12])
