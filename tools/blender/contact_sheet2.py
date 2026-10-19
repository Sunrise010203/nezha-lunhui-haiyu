"""Contact sheet #2 - underwater/ruin candidates."""
import io
import json
import urllib.request

from PIL import Image, ImageDraw

META = r"E:\godot_game_by_fable\tools\blender\library\polyhaven_models.json"
OUT = r"E:\godot_game_by_fable\_baseline\candidates2.png"

GROUPS = {
    "cage/lamp": ["caged_hanging_light", "industrial_caged_sconce",
                  "lantern_chandelier_01"],
    "statue": ["marble_bust_01", "gothic_statue", "bronze_shark_statue"],
    "misc": ["lambis_shell", "dead_tree_trunk_02", "nettle_plant",
             "dead_branch"],
}

CELL, PAD, LABEL_H = 220, 8, 36


def main():
    meta = json.load(open(META, encoding="utf-8"))
    tiles = []
    for group, ids in GROUPS.items():
        for aid in ids:
            m = meta.get(aid)
            if not m:
                print("missing", aid)
                continue
            url = m["thumbnail_url"] + "?width=256&height=256"
            req = urllib.request.Request(url, headers={"User-Agent": "local-tool"})
            with urllib.request.urlopen(req, timeout=60) as r:
                img = Image.open(io.BytesIO(r.read())).convert("RGB")
            img.thumbnail((CELL, CELL))
            tiles.append((group, aid, img, m.get("polycount"), m.get("dimensions")))

    cols = 5
    rows = (len(tiles) + cols - 1) // cols
    W = cols * (CELL + PAD) + PAD
    H = rows * (CELL + LABEL_H + PAD) + PAD
    sheet = Image.new("RGB", (W, H), (18, 18, 22))
    d = ImageDraw.Draw(sheet)
    for i, (group, aid, img, poly, dims) in enumerate(tiles):
        r, c = divmod(i, cols)
        x = PAD + c * (CELL + PAD)
        y = PAD + r * (CELL + LABEL_H + PAD)
        sheet.paste(img, (x + (CELL - img.width) // 2,
                          y + LABEL_H + (CELL - img.height) // 2))
        d.text((x, y), aid, fill=(240, 240, 240))
        d.text((x, y + 13), f"{group} tri={poly}", fill=(150, 210, 255))
        if dims:
            d.text((x, y + 25), f"{dims[0]:.0f}x{dims[1]:.0f}x{dims[2]:.0f} mm",
                   fill=(160, 160, 160))
    sheet.save(OUT)
    print("SAVED", OUT, sheet.size)


if __name__ == "__main__":
    main()
