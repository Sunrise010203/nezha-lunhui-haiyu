"""Keep only remote palace roofs; never reuse the reference's actor or bridge.

Run with a Python containing Pillow. The mirrored tile has matching opposite
edges; the shader repeats it only in the far distance and fades its lower edge.
"""
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
src = Image.open(ROOT / "001/art/ref/ch1_corridor.png").convert("RGB")
w, h = src.size
# Central remote palace only: no lower walkway, left character, or right eye.
crop = src.crop((round(w * .32), round(h * .16), round(w * .59), round(h * .63)))
crop = crop.resize((768, 1024), Image.Resampling.LANCZOS)
crop = crop.filter(ImageFilter.GaussianBlur(3.5))
crop = ImageEnhance.Color(crop).enhance(.55)
crop = ImageEnhance.Contrast(crop).enhance(.65)
tile = Image.new("RGB", (1536, 1024))
tile.paste(crop, (0, 0))
tile.paste(ImageOps.mirror(crop), (768, 0))
out = ROOT / "001/art/ref/ch1_palace_far.png"
tile.save(out)
print(out, tile.size)
