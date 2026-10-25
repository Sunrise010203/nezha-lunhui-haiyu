"""Create a brighter sRGB albedo from the untouched original GLB (Pillow)."""
import io
import json
import struct
from pathlib import Path

from PIL import Image

ROOT = Path("E:/godot_game_by_fable")
data = (ROOT / "art_source/nezha/nezha_model.glb").read_bytes()
magic, version, length = struct.unpack_from("<4sII", data)
assert magic == b"glTF" and version == 2 and length == len(data)
offset = 12
chunks = {}
while offset < length:
    size, kind = struct.unpack_from("<II", data, offset)
    chunks[kind] = data[offset + 8:offset + 8 + size]
    offset += size + 8
document = json.loads(chunks[0x4E4F534A])
index = document["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
source = document["textures"][index]["source"]
view = document["bufferViews"][document["images"][source]["bufferView"]]
start = view.get("byteOffset", 0)
image = Image.open(io.BytesIO(chunks[0x004E4942][start:start + view["byteLength"]])).convert("RGB")

# A bounded midtone lift: retain true black and white and protect the darkest ink.
gamma = 0.72
lut = []
for value in range(256):
    x = value / 255
    t = min(1.0, x / 0.12)
    protection = t * t * (3 - 2 * t)
    lut.append(round(255 * (x + protection * (x ** gamma - x))))
assert lut[0] == 0 and lut[-1] == 255
assert all(a <= b for a, b in zip(lut, lut[1:]))
corrected = image.point(lut * 3)
target = ROOT / "art_source/nezha/textures/Nezha_Albedo_Bright.png"
target.parent.mkdir(exist_ok=True)
corrected.save(target, compress_level=6)
report = {"source": "art_source/nezha/nezha_model.glb", "output": str(target),
          "size": list(image.size), "srgb_gamma": gamma, "black_protection_end": 0.12,
          "lut": lut, "material_changes": "base color image only; no emission"}
out = ROOT / "_review/nezha_arp/appearance"
(out / "tone_curve.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k != "lut"}))
