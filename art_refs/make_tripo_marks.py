# -*- coding: utf-8 -*-
"""在四张章节场景参考图上标注"建议用 Tripo 生成"的资产。
实线框 = 直接 Tripo 生成（再进 Blender 重拓扑/烘焙）
虚线框 = Tripo 只出母版，Blender 做阵列/拼接/精修
输出：E:\\godot_game_by_fable\\asset_split\\tripo_ch1..4.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

SRC = r"E:\godot_game_by_fable\art_refs"
OUT = r"E:\godot_game_by_fable\asset_split"
os.makedirs(OUT, exist_ok=True)

W, H = 2048, 1152            # 画面区（16:9）
LW = 2048                    # 整张标注图宽
FONT_B = r"C:\Windows\Fonts\msyhbd.ttc"
FONT_R = r"C:\Windows\Fonts\msyh.ttc"

CORE = (255, 61, 106, 255)     # 实线：Tripo 直出
HYB = (255, 178, 64, 255)      # 虚线：Tripo 母版 + Blender 加工
CY = (79, 232, 255, 255)
AM = (242, 193, 78, 255)
TXT = (240, 245, 248, 255)
MUTED = (150, 165, 180, 255)


def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT_R, size)


def text(d, xy, s, size=26, fill=TXT, bold=False, anchor="la"):
    d.text(xy, s, font=font(size, bold), fill=fill, anchor=anchor)


CH = {
    "ch1": dict(
        title="第一章  东海 · 碎潮回廊", sub="Dragon Palace Outer Corridor", src="ch1_corridor_20261020_130544_0.png",
        note="玩家区 5–31%　玩法带 62–82%　出口/竞技场 65–96%",
        items=[
            dict(id="T1", solid=True, box=(0.600, 0.265, 0.855, 0.605), name="归墟之喉 · 巨眼", note="有机 Boss 本体，12–16 根触须+眼睑褶皱", tris="LOD0 90k"),
            dict(id="T2", solid=True, box=(0.062, 0.450, 0.190, 0.655), name="红珊瑚扇（左）", note="有机分枝，2 个变体后全章实例化", tris="6k ×2"),
            dict(id="T3", solid=True, box=(0.820, 0.470, 0.915, 0.635), name="红珊瑚扇（右）", note="复用 T2 资产，只换缩放/旋转", tris="—"),
            dict(id="T4", solid=False, box=(0.806, 0.004, 0.902, 0.135), name="柱头蟠龙雕饰", note="1 个母版，四根断柱复用，柱身 Blender 建模", tris="18k"),
            dict(id="T5", solid=False, box=(0.205, 0.635, 0.258, 0.755), name="哪吒（玩家）", note="Tripo 出形 → Blender 重拓扑+绑定", tris="LOD0 45k"),
        ]),
    "ch2": dict(
        title="第二章  龙宫深狱", sub="Deep Sea Prison", src="ch2_prison_20261020_130649_0.png",
        note="玩家区 5–31%　玩法带 62–82%　出口/竞技场 65–96%",
        items=[
            dict(id="T1", solid=False, box=(0.790, 0.380, 0.900, 0.600), name="棘狱守卫（Boss）", note="甲胄走 Blender 硬表面，只让 Tripo 出背部有机增生/棘刺", tris="增生件 20k"),
            dict(id="T2", solid=True, box=(0.112, 0.045, 0.192, 0.150), name="骷髅门饰（左门楣）", note="骨+铜混合雕饰，母版 1 个", tris="15k"),
            dict(id="T3", solid=True, box=(0.383, 0.240, 0.452, 0.360), name="悬吊铁笼 · 囚徒骨堆", note="笼体 Blender，笼内骨堆 Tripo", tris="20k"),
            dict(id="T4", solid=True, box=(0.000, 0.520, 0.100, 0.660), name="平台骨堆 / 镣铐尸骸", note="散落骨骸组合件，可做 3 变体", tris="12k"),
            dict(id="T5", solid=False, box=(0.305, 0.510, 0.378, 0.690), name="哪吒（玩家）", note="同第一章 T5，全项目 1 份", tris="LOD0 45k"),
        ]),
    "ch3": dict(
        title="第三章  归墟虚空「海眼」", sub="The Void of Guixu", src="ch3_void_20261020_130658_0.png",
        note="海眼巨涡=引擎 VFX/Shader　封印石板/铜环本体=Blender",
        items=[
            dict(id="T1", solid=False, box=(0.205, 0.550, 0.262, 0.700), name="哪吒（玩家）", note="全项目 1 份，四章复用", tris="LOD0 45k"),
            dict(id="T2", solid=True, box=(0.163, 0.393, 0.268, 0.532), name="虚空岩块 / 断台碎块", note="3–4 变体，全图约 12 处实例化（可选：Blender Displace 也能替代）", tris="4–8k"),
            dict(id="T3", solid=False, box=(0.567, 0.588, 0.632, 0.668), name="铜环 · 龙首扣件", note="环本体 Blender 曲线，只让 Tripo 出 4 个扣件母版", tris="3k"),
            dict(id="T4", solid=False, box=(0.455, 0.195, 0.585, 0.415), name="海眼 · 二阶段巨瞳", note="（可选）二阶段要做实体眼球才做；纯 VFX 可省", tris="60k"),
        ]),
    "ch4": dict(
        title="第四章  龙骨沉殿「潮心」", sub="Sunken Hall of Whale Bones", src="ch4_hall_20261020_130705_0.png",
        note="潮纹碑/沉钟/龙宫柱=Blender　潮脉水流/光柱=引擎 VFX",
        items=[
            dict(id="T1", solid=False, box=(0.160, 0.000, 0.845, 0.235), name="鲸骨拱 / 椎骨天顶", note="Tripo 出 2–3 段母版，Blender 阵列+弯曲成拱", tris="25k / 段"),
            dict(id="T2", solid=True, box=(0.440, 0.320, 0.610, 0.550), name="螭吻（Boss）", note="龙首鱼身，需手动骨架+腹内潮水特效", tris="LOD0 70k"),
            dict(id="T3", solid=True, box=(0.135, 0.375, 0.185, 0.615), name="骨白雕像（左）", note="溺毙命官立像，衣褶/残损交给 Tripo", tris="25k"),
            dict(id="T4", solid=True, box=(0.818, 0.355, 0.872, 0.600), name="骨白雕像（右）", note="复用 T3 资产，换姿态/破损", tris="—"),
            dict(id="T5", solid=True, box=(0.838, 0.650, 0.990, 0.980), name="潮蚀异化珊瑚 / 菌簇", note="前景压角，2 变体", tris="10k"),
            dict(id="T6", solid=False, box=(0.612, 0.525, 0.690, 0.605), name="沉钟 · 钟顶龙钮", note="钟体 Blender 车削，龙钮 Tripo", tris="6k"),
            dict(id="T7", solid=False, box=(0.172, 0.620, 0.238, 0.765), name="哪吒（玩家）", note="全项目 1 份，四章复用", tris="LOD0 45k"),
        ]),
}


def rrect(d, box, r, width, color, dashed=False):
    x0, y0, x1, y1 = box
    if not dashed:
        d.rounded_rectangle(box, radius=r, outline=color, width=width)
        return
    # 虚线圆角矩形：四边分段绘制
    seg = 18
    gap = 12
    for x in range(int(x0 + r), int(x1 - r), seg + gap):
        d.line([(x, y0), (min(x + seg, x1 - r), y0)], fill=color, width=width)
        d.line([(x, y1), (min(x + seg, x1 - r), y1)], fill=color, width=width)
    for y in range(int(y0 + r), int(y1 - r), seg + gap):
        d.line([(x0, y), (x0, min(y + seg, y1 - r))], fill=color, width=width)
        d.line([(x1, y), (x1, min(y + seg, y1 - r))], fill=color, width=width)
    d.arc([x0, y0, x0 + 2 * r, y0 + 2 * r], 180, 270, fill=color, width=width)
    d.arc([x1 - 2 * r, y0, x1, y0 + 2 * r], 270, 360, fill=color, width=width)
    d.arc([x0, y1 - 2 * r, x0 + 2 * r, y1], 90, 180, fill=color, width=width)
    d.arc([x1 - 2 * r, y1 - 2 * r, x1, y1], 0, 90, fill=color, width=width)


def tag(d, x, y, s, color, size=25):
    f = font(size, True)
    tw = d.textlength(s, font=f)
    pad = 9
    d.rounded_rectangle([x, y, x + tw + 2 * pad, y + size + 2 * pad - 4], radius=6, fill=color)
    d.text((x + pad, y + pad - 3), s, font=f, fill=(16, 20, 26, 255))


def make(key):
    cfg = CH[key]
    base = Image.open(os.path.join(SRC, cfg["src"])).convert("RGB")
    if key == "ch4":
        base = base.crop((0, 0, 2720, 1530))          # 裁掉底部 UI 条
    base = base.resize((W, H), Image.LANCZOS)
    items = cfg["items"]
    rows = (len(items) + 1) // 2
    TOP = 92
    LH = 96 + rows * 62 + 74
    canvas = Image.new("RGB", (LW, TOP + H + LH), (11, 14, 19))
    canvas.paste(base, (0, TOP))
    ov = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)

    # 顶部标题条（独占 92px，不压画面）
    d.rectangle([0, 0, LW, TOP], fill=(8, 10, 14, 255))
    text(d, (36, 16), cfg["title"], 40, (255, 255, 255, 255), True)
    text(d, (36, 62), cfg["sub"] + "　·　Tripo 资产标注 / Asset Split", 22, MUTED, False)
    text(d, (LW - 36, 24), "实线 = Tripo 直出　　虚线 = Tripo 母版 + Blender 加工", 22, (255, 255, 255, 255), False, "ra")

    for it in items:
        x0, y0, x1, y1 = it["box"]
        box = (x0 * W, y0 * H + TOP, x1 * W, y1 * H + TOP)
        col = CORE if it["solid"] else HYB
        d.rounded_rectangle(box, radius=14, fill=col[:3] + (26,))
        rrect(d, box, 14, 4, col, dashed=not it["solid"])
        tx = box[0] + 6
        ty = box[1] - 40
        if ty < TOP + 8:
            ty = box[3] - 36
        if tx > W - 140:
            tx = W - 140
        tag(d, tx, ty, it["id"], col)

    canvas = Image.alpha_composite(canvas.convert("RGBA"), ov).convert("RGB")
    d2 = ImageDraw.Draw(canvas)

    # 图例
    ty = TOP + H + 14
    d2.line([(36, TOP + H), (LW - 36, TOP + H)], fill=(60, 72, 86), width=1)
    text(d2, (36, ty), "TRIPO 生成清单", 26, CY, True)
    text(d2, (LW - 36, ty + 4), cfg["note"], 20, MUTED, False, "ra")
    ty += 44
    colw = (LW - 72) // 2
    for i, it in enumerate(items):
        c, r = i // rows, i % rows
        cx = 36 + c * colw
        cy = ty + r * 62
        col = CORE if it["solid"] else HYB
        if it["solid"]:
            d2.rectangle([cx, cy + 6, cx + 14, cy + 20], fill=col)
        else:
            d2.rectangle([cx, cy + 6, cx + 14, cy + 20], outline=col, width=2)
        text(d2, (cx + 26, cy), it["id"], 22, col, True)
        text(d2, (cx + 66, cy), it["name"], 22, TXT, True)
        text(d2, (cx + 66, cy + 28), it["note"], 18, MUTED)
        text(d2, (cx + colw - 30, cy + 1), it["tris"], 19, AM, True, "ra")
    fy = ty + rows * 62 + 12
    d2.line([(36, fy), (LW - 36, fy)], fill=(60, 72, 86), width=1)
    text(d2, (36, fy + 14),
         "其余资产不走 Tripo：断柱 / 平台台阶 / 铁栏门 / 锁链吊笼 / 封印石板 / 铜环本体 / 潮纹碑 / 沉钟 / 龙宫柱 = Blender 硬表面模块化；水面 / 雾 / 光柱 / 焦散 / 粒子 / 巨涡 = Unity Shader + VFX",
         19, MUTED)

    out = os.path.join(OUT, f"tripo_{key}.png")
    canvas.save(out)
    print(out)


for k in CH:
    make(k)
