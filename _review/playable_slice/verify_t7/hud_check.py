"""t7 HUD evidence checker (deterministic, no eyeballing).

For each captured CLIENT-AREA screenshot it verifies:
  1. image size == requested client size (no crop / no scaling of the file itself)
  2. top-right 龙魂残片 counter region contains enough warm-gold text pixels
  3. bottom key-hint bar region contains enough light-grey text pixels
  4. (sanity) the frame is not a single flat colour (i.e. the game actually rendered)

Usage:
  python hud_check.py --root <verify_t7 dir> --case 1920x1080/ch1.png [...]
It writes hud_check.json next to the images and prints one PASS/FAIL line per case.

Thresholds are fractions of image area, so they scale with the client size.
"""
import argparse
import json
from pathlib import Path

from PIL import Image

# 归一化感兴趣区域（相对客户区宽高）
ROI_SOUL = (0.78, 0.00, 1.00, 0.060)   # 右上：龙魂残片 0 / 3
ROI_KEYS = (0.00, 0.955, 0.62, 1.00)   # 底部：A/D 移动 … Esc 暂停

MIN_SOUL_GOLD_FRAC = 0.00015   # 暖金色文字像素 / 整幅面积
MIN_KEYS_LIGHT_FRAC = 0.00030  # 浅灰文字像素 / 整幅面积
MIN_ABS_PX = {"soul": 30, "keys": 100}


def is_gold(r, g, b):
    return r > 120 and g > 90 and r - b > 20 and b < 200


def is_light(r, g, b):
    return r > 100 and g > 100 and b > 100 and max(r, g, b) - min(r, g, b) < 70


def count_roi(img, roi, pred):
    w, h = img.size
    x0, y0, x1, y1 = (int(roi[0] * w), int(roi[1] * h), int(roi[2] * w), int(roi[3] * h))
    crop = img.crop((x0, y0, x1, y1)).convert("RGB")
    data = list(crop.get_flattened_data()) if hasattr(crop, "get_flattened_data") else list(crop.getdata())
    return sum(1 for px in data if pred(*px)), (x0, y0, x1, y1)


def check(path: Path, want_w: int, want_h: int):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    area = w * h
    gold, soul_box = count_roi(img, ROI_SOUL, is_gold)
    light, keys_box = count_roi(img, ROI_KEYS, is_light)
    # 画面平整度：抽样 20x20 网格，统计不同颜色桶数量
    small = img.resize((20, 20))
    colours = len(set(small.get_flattened_data() if hasattr(small, "get_flattened_data") else small.getdata()))
    res = {
        "file": path.name,
        "size": [w, h],
        "expected_size": [want_w, want_h],
        "size_ok": (w, h) == (want_w, want_h),
        "soul_gold_px": gold,
        "soul_gold_frac": round(gold / area, 6),
        "soul_threshold_frac": MIN_SOUL_GOLD_FRAC,
        "soul_ok": gold >= MIN_ABS_PX["soul"] and gold / area >= MIN_SOUL_GOLD_FRAC,
        "soul_roi": soul_box,
        "keys_light_px": light,
        "keys_light_frac": round(light / area, 6),
        "keys_threshold_frac": MIN_KEYS_LIGHT_FRAC,
        "keys_ok": light >= MIN_ABS_PX["keys"] and light / area >= MIN_KEYS_LIGHT_FRAC,
        "keys_roi": keys_box,
        "grid_colours_20x20": colours,
        "rendered_ok": colours >= 40,
    }
    res["pass"] = all(res[k] for k in ("size_ok", "soul_ok", "keys_ok", "rendered_ok"))
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--case", action="append", required=True,
                    help="相对 --root 的图片路径，形如 1920x1080/ch1.png")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    out = []
    for case in args.case:
        path = root / case
        w, h = (int(v) for v in case.split("/")[0].lower().split("x"))
        r = check(path, w, h)
        out.append(r)
        print(f"{'PASS' if r['pass'] else 'FAIL'} {case} size={r['size']} "
              f"soul={r['soul_gold_px']}px({r['soul_gold_frac']:.5f}) "
              f"keys={r['keys_light_px']}px({r['keys_light_frac']:.5f}) colours={r['grid_colours_20x20']}")
    (root / "hud_check.json").write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print("wrote", root / "hud_check.json")


if __name__ == "__main__":
    main()
