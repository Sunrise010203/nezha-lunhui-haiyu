"""Contact sheet for Poly Haven stone textures."""
import io
import json
import urllib.request

from PIL import Image, ImageDraw

META = r"E:\godot_game_by_fable\tools\blender\library\polyhaven_textures.json"
OUT = r"E:\godot_game_by_fable\_baseline\stone_tex.png"

IDS = [
    "rock_face_03", "stone_tiles_02", "granite_tile", "stone_brick_wall_001",
    "castle_brick_02_red", "rock_boulder_dry", "mossy_cobblestone",
    "cobblestone_floor_04", "rocky_terrain_02", "rock_wall_08",
    "brick_wall_006", "rocky_terrain_08",
]


def main():
    meta = json.load(open(META, encoding="utf-8"))
    tiles = []
    for aid in IDS:
        m = meta.get(aid)
        if not m:
            print("missing", aid)
            continue
        url = m["thumbnail_url"] + "?width=256&height=256"
        req = urllib.request.Request(url, headers={"User-Agent": "local-tool"})
        with urllib.request.urlopen(req, timeout=60) as r:
            img = Image.open(io.BytesIO(r.read())).convert("RGB")
        img.thumbnail((220, 220))
        tiles.append((aid, img, m.get("categories", [])[:2], m.get("download_count")))

    cols = 4
    cell, pad, label_h = 220, 8, 34
    rows = (len(tiles) + cols - 1) // cols
    W = cols * (cell + pad) + pad
    H = rows * (cell + label_h + pad) + pad
    sheet = Image.new("RGB", (W, H), (18, 18, 22))
    d = ImageDraw.Draw(sheet)
    for i, (aid, img, cats, dl) in enumerate(tiles):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + label_h + pad)
        sheet.paste(img, (x + (cell - img.width) // 2,
                          y + label_h + (cell - img.height) // 2))
        d.text((x, y), aid[:32], fill=(240, 240, 240))
        d.text((x, y + 13), f"{cats} dl={dl}", fill=(150, 210, 255))
    sheet.save(OUT)
    print("SAVED", OUT, sheet.size, "tiles", len(tiles))


if __name__ == "__main__":
    main()
