"""Build a labelled contact sheet of Poly Haven candidate models."""
import io
import json
import os
import sys
import urllib.request

from PIL import Image, ImageDraw

META = r"E:\godot_game_by_fable\tools\blender\library\polyhaven_models.json"
OUT = r"E:\godot_game_by_fable\_baseline\candidates.png"

GROUPS = {
    "tall/stone": ["namaqualand_cliff_02", "coastal_cliff_04", "stone_fire_pit",
                   "gothic_statue", "horse_statue_01", "bronze_shark_statue"],
    "rocks": ["boulder_01", "rock_09", "moon_rock_01", "namaqualand_stones_01",
              "rock_moss_set_01", "coast_rocks_03"],
    "plants": ["fern_02", "grass_medium_02", "weed_plant_02", "nettle_plant",
               "dry_branches_medium_01", "calathea_orbifolia_01"],
    "lanterns": ["Lantern_01", "wooden_lantern_01", "brass_diya_lantern"],
    "pots": ["antique_ceramic_vase_01", "ceramic_vase_02", "brass_vase_03",
             "planter_pot_clay", "brass_pot_02"],
    "industrial": ["modular_chainlink_fence", "Barrel_01", "wooden_crate_01"],
}

CELL, PAD, LABEL_H = 200, 8, 34


def main():
    meta = json.load(open(META, encoding="utf-8"))
    flat = [a for g in GROUPS.values() for a in g]
    missing = [a for a in flat if a not in meta]
    if missing:
        print("MISSING:", missing)

    tiles = []
    for group, ids in GROUPS.items():
        for aid in ids:
            m = meta.get(aid)
            if not m:
                continue
            url = m["thumbnail_url"] + "?width=256&height=256"
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "local-tool"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    img = Image.open(io.BytesIO(r.read())).convert("RGB")
            except Exception as e:
                print("thumb fail", aid, e)
                img = Image.new("RGB", (CELL, CELL), (40, 40, 40))
            img.thumbnail((CELL, CELL))
            tiles.append((group, aid, img, m.get("polycount"), m.get("dimensions")))

    cols = 6
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
        d.text((x, y), f"{aid}", fill=(240, 240, 240))
        sub = f"{group} tri={poly}"
        d.text((x, y + 13), sub[:40], fill=(150, 210, 255))
        if dims:
            d.text((x, y + 24), f"{dims[0]:.2f}x{dims[1]:.2f}x{dims[2]:.2f} m",
                   fill=(160, 160, 160))

    sheet.save(OUT)
    print("SAVED:", OUT, sheet.size, "tiles:", len(tiles))
    for group, aid, _, poly, dims in tiles:
        print(f"{group:<12} {aid:<28} tri={poly:<7} dims={dims}")


if __name__ == "__main__":
    main()
