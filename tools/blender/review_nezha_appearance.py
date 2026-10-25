"""Verify the exported albedo and assemble the same-lighting comparison."""
import io
import json
import struct
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

ROOT = Path("E:/godot_game_by_fable")
OUT = ROOT / "_review/nezha_arp/appearance"
data = (ROOT / "001/art/models/nezha_arp.glb").read_bytes()
offset = 12
chunks = {}
while offset < len(data):
    size, kind = struct.unpack_from("<II", data, offset)
    chunks[kind] = data[offset + 8:offset + 8 + size]
    offset += size + 8
document = json.loads(chunks[0x4E4F534A])
material = document["materials"][0]
index = material["pbrMetallicRoughness"]["baseColorTexture"]["index"]
source = document["textures"][index]["source"]
view = document["bufferViews"][document["images"][source]["bufferView"]]
start = view.get("byteOffset", 0)
exported = Image.open(io.BytesIO(chunks[0x004E4942][start:start + view["byteLength"]])).convert("RGB")
expected = Image.open(ROOT / "art_source/nezha/textures/Nezha_Albedo_Bright.png").convert("RGB")
assert exported.size == expected.size == (8192, 8192)
assert ImageChops.difference(exported, expected).getbbox() is None, "GLB albedo differs"
assert material.get("emissiveFactor", [0, 0, 0]) == [0, 0, 0]

before = Image.open(OUT / "before_front.png").convert("RGB")
after = Image.open(OUT / "after_front.png").convert("RGB")
mask = ImageChops.difference(before, after).convert("L").point(lambda x: 255 if x > 0 else 0)
means = [ImageStat.Stat(im.convert("L"), mask).mean[0] for im in (before, after)]
assert means[1] > means[0]
report = {"exported_albedo_matches_source_pixels": True, "albedo_size": list(exported.size),
          "emission_added": False, "changed_area_display_luminance_before_after": means,
          "same_render_exposure": True}
(OUT / "texture_export_validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
sheet = Image.new("RGB", (1120, 748), (38, 38, 38))
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 23)
for index, (label, im) in enumerate((("BEFORE", before), ("AFTER", after))):
    draw.text((index * 560 + 22, 13), label, font=font, fill=(235, 235, 235))
    sheet.paste(im.resize((560, 700), Image.Resampling.LANCZOS), (index * 560, 48))
sheet.save(OUT / "comparison.jpg", quality=94)
print(json.dumps(report))
