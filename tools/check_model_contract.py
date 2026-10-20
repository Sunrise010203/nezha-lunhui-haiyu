# -*- coding: utf-8 -*-
"""哪吒模型契约检查器 —— 换模型前跑一遍，确认新 GLB 能满足游戏侧的硬约束。

用法：
    python tools/check_model_contract.py 001/art/models/nezha_lit.glb
    python tools/check_model_contract.py 新模型.glb --baseline 001/art/models/nezha_lit.glb
    python tools/check_model_contract.py 001/art/models/nezha_lit.glb --json

检查项来自代码里的真实依赖，不是猜的：
  * 骨骼名 22 根：player.gd 用 _bones["名称"] 取索引后直接 set_bone_pose_rotation，
    名字对不上 = 该骨骼不动（静默失败，不报错）。
    用到：hips chest head upper_arm.L/R forearm.L/R hand.R thigh.L/R shin.L/R foot.L/R rib.L/R.1~3
    仅有层级作用：neck、hand.L（hand.L 进 rig 但代码只跟 hand.R）
  * 混天绫三段链：rib.L.1 → rib.L.2 → rib.L.3（父级依次），rib.R 同理；rib.*.1 的父级必须是 chest
  * 三角面数 ≤ 12000：当前 9,888，第四章 33 万 tris/帧的预算已经吃紧
  * 必须有 TEXCOORD_0：六张烘焙贴图全靠 UV 图集，没有 UV 就没法 bake
  * 不允许带 animation：动作全部由 player.gd 程序化驱动，带 clip 会互相打架
  * 轴朝向：本项目 GLB 是非标准 Z-up，load_model 里 pitch=-90 立起来。
    Tripo 导出的是标准 Y-up，直接塞进来角色会躺下（脚本会提示）
"""
from __future__ import annotations

import json
import struct
import sys

MAX_TRIS = 12000

# 代码里真正被驱动的骨骼（player.gd 的 _pose_target / _update_spear_follow）
REQUIRED_BONES = [
    "hips", "chest", "neck", "head",
    "upper_arm.L", "forearm.L", "hand.L",
    "upper_arm.R", "forearm.R", "hand.R",
    "thigh.L", "shin.L", "foot.L",
    "thigh.R", "shin.R", "foot.R",
    "rib.L.1", "rib.L.2", "rib.L.3",
    "rib.R.1", "rib.R.2", "rib.R.3",
]
# 骨骼 -> 期望父级（None 表示根）。只校验这几条关键链，其余不强制。
EXPECTED_PARENT = {
    "chest": "hips", "neck": "chest", "head": "neck",
    "hips": None,
    "upper_arm.L": "chest", "forearm.L": "upper_arm.L", "hand.L": "forearm.L",
    "upper_arm.R": "chest", "forearm.R": "upper_arm.R", "hand.R": "forearm.R",
    "thigh.L": "hips", "shin.L": "thigh.L", "foot.L": "shin.L",
    "thigh.R": "hips", "shin.R": "thigh.R", "foot.R": "shin.R",
    "rib.L.1": "chest", "rib.L.2": "rib.L.1", "rib.L.3": "rib.L.2",
    "rib.R.1": "chest", "rib.R.2": "rib.R.1", "rib.R.3": "rib.R.2",
}


def load_glb(path: str) -> dict:
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:  # 'glTF'
        raise ValueError(f"{path} 不是 GLB（magic={magic:#x}）")
    off = 12
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        off += 8
        if ctype == 0x4E4F534A:  # JSON
            return json.loads(data[off:off + clen].decode("utf-8"))
        off += clen
    raise ValueError(f"{path} 没有 JSON chunk")


def tris_of(gltf: dict) -> int:
    total = 0
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            idx = prim.get("indices")
            if idx is None:
                acc = gltf["accessors"][prim["attributes"]["POSITION"]]
                total += acc["count"] // 3
            else:
                total += gltf["accessors"][idx]["count"] // 3
    return total


def bbox_of(gltf: dict) -> tuple[list[float], list[float]] | None:
    lo = [1e9] * 3
    hi = [-1e9] * 3
    found = False
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            if "min" in acc and "max" in acc:
                found = True
                for i in range(3):
                    lo[i] = min(lo[i], acc["min"][i])
                    hi[i] = max(hi[i], acc["max"][i])
    return (lo, hi) if found else None


def skin_report(gltf: dict) -> dict:
    nodes = gltf.get("nodes", [])
    parent = {}
    for i, node in enumerate(nodes):
        for c in node.get("children", []):
            parent[c] = i

    skins = gltf.get("skins", [])
    if not skins:
        return {"joints": [], "names": [], "parents": {}}
    joints = skins[0]["joints"]
    names = [nodes[j].get("name", f"node{j}") for j in joints]
    name_of = {j: nodes[j].get("name", f"node{j}") for j in joints}
    parents = {}
    for j in joints:
        p = parent.get(j)
        while p is not None and nodes[p].get("name") not in name_of.values():
            p = parent.get(p)
        parents[name_of[j]] = nodes[p].get("name") if p is not None else None
    return {"joints": joints, "names": names, "parents": parents}


def check(path: str, baseline: str | None = None) -> tuple[bool, list[str]]:
    gltf = load_glb(path)
    lines: list[str] = []
    fails: list[str] = []

    def ok(cond: bool, msg: str, bad: str | None = None) -> None:
        lines.append(("  PASS  " if cond else "  FAIL  ") + msg)
        if not cond and bad:
            fails.append(bad)

    tris = tris_of(gltf)
    sk = skin_report(gltf)
    names = sk["names"]
    prim0 = gltf["meshes"][0]["primitives"][0] if gltf.get("meshes") else {}
    attrs = prim0.get("attributes", {})
    n_img = len(gltf.get("images", []))
    n_anim = len(gltf.get("animations", []))
    mats = [m.get("name", "?") for m in gltf.get("materials", [])]

    lines.append(f"== {path}")
    lines.append(f"  tris={tris}  joints={len(names)}  materials={mats}  "
                 f"images={n_img}  animations={n_anim}")

    missing = [b for b in REQUIRED_BONES if b not in names]
    ok(not missing, f"骨骼名齐全（缺 {len(missing)}）{('→ ' + ', '.join(missing)) if missing else ''}",
       "缺骨骼：" + ", ".join(missing))
    extra = [n for n in names if n not in REQUIRED_BONES]
    if extra:
        lines.append(f"  注意   多出骨骼：{', '.join(extra)}")

    bad_parent = []
    for bone, want in EXPECTED_PARENT.items():
        if bone not in names:
            continue
        got = sk["parents"].get(bone)
        if got != want:
            bad_parent.append(f"{bone}: 期望父级 {want}，实际 {got}")
    ok(not bad_parent, f"骨骼层级正确（{len(EXPECTED_PARENT)} 条关键链）"
       + ("" if not bad_parent else "：" + "；".join(bad_parent)), "; ".join(bad_parent))

    ok(tris <= MAX_TRIS, f"三角面 {tris} ≤ {MAX_TRIS}", f"面数超预算 {tris}")

    ok("TEXCOORD_0" in attrs, "有 UV（TEXCOORD_0）", "缺 UV，没法烘焙六张贴图")
    ok("JOINTS_0" in attrs and "WEIGHTS_0" in attrs, "有蒙皮权重（JOINTS_0/WEIGHTS_0）",
       "缺蒙皮数据")
    if "COLOR_0" not in attrs:
        lines.append("  注意   无顶点色（COLOR_0）：如 CharLook 贴图缺失，回退材质会变纯白")
    ok(n_anim == 0, f"无内置动画（{n_anim} 个 clip）", "带 animation，会和程序化动作打架")

    bbox = bbox_of(gltf)
    if bbox:
        lo, hi = bbox
        size = [round(hi[i] - lo[i], 3) for i in range(3)]
        tall_axis = max(range(3), key=lambda i: size[i])
        lines.append(f"  信息   bbox 尺寸 xyz={size}（纵向轴 = {'XYZ'[tall_axis]}）")
        if tall_axis == 1:
            lines.append("  提示   纵向轴是 Y：标准 glTF。load_model 的 pitch 应传 0.0，"
                         "当前项目默认 -90 会把它放倒")
        elif tall_axis == 2:
            lines.append("  提示   纵向轴是 Z：与本项目现有约定一致，pitch=-90 可用")

    if baseline:
        base = load_glb(baseline)
        b_tris = tris_of(base)
        b_names = skin_report(base)["names"]
        lines.append(f"== 对照基线 {baseline}")
        lines.append(f"  面数  {b_tris} → {tris}（{(tris - b_tris) / max(b_tris, 1) * 100:+.0f}%）")
        diff = [n for n in b_names if n not in names]
        if diff:
            lines.append(f"  基线里有、新模型缺的骨骼：{', '.join(diff)}")

    return (not fails), lines


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    baseline = None
    if "--baseline" in sys.argv:
        i = sys.argv.index("--baseline")
        baseline = sys.argv[i + 1]
        args = [a for a in args if a != baseline]
    if not args:
        print(__doc__)
        return 2
    all_ok = True
    for p in args:
        passed, lines = check(p, baseline)
        print("\n".join(lines))
        print(f"  结论：{'通过' if passed else '不通过'}\n")
        all_ok = all_ok and passed
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
