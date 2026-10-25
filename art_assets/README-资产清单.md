# Tripo 单体资产参考图 · 清单与出图说明

> 生成于 2026-10-21，全部由 APIMart（`gpt-image-2`）出图，1k 分辨率。
> 用途：作为 **Tripo 图生 3D** 的输入参考图（不是最终贴图，也不是可直接进 Unity 的成品）。
> 联络表：`contact_sheet_v2.png`（4 列，T01–T15）。

## 一、出图规格（每张图都带这段前缀）

```
single isolated 3D game asset, one object only, centered, entire object visible in frame,
three-quarter front view, plain seamless light warm-grey studio background, soft even lighting,
subtle ambient occlusion, no cast shadow, no pedestal, no text, no UI, no extra props,
stylized semi-realistic game art, hand-painted PBR, weathered surfaces, crisp readable silhouette
```

+ 每个资产单独一句主体描述（见 `art_refs/gen_assets.py` 的 A/B/C 三组）。

- 比例：方形摆件用 `1:1`，高瘦件（守卫、柱头、雕像）用 `3:4`
- 输出：`1254×1254` 或 `1086×1448`，PNG，浅暖灰底
- 成本：约 **0.0085 美元/张**，15 张合计约 0.13 美元

## 二、资产清单

| 编号 | 文件 | 章节 | 比例 | Tripo 建议面数 | 用途 / 挂载 | 备注 |
|---|---|---|---|---|---|---|
| T01 | `ch1_abyss_eye.png` | 一 | 1:1 | LOD0 90k | Boss「归墟之喉」本体，远景 1/3 处 | 触须要 12–16 根分叉，眼睑做 2 层 |
| T02 | `ch1_coral_fan.png` | 一 | 1:1 | 6k ×2 变体 | 玩家区两侧珊瑚廊，近景遮罩 | 图里只做一个母版，Blender 里缩放/旋转出 4 种 |
| T03 | `ch1_pillar_dragon_capital.png` | 一 | 3:4 | 18k | 断柱柱头（四根断柱复用一个母版） | 柱身不用 Tripo，Blender 圆柱即可 |
| T04 | `ch2_warden.png` | 二 | 3:4 | LOD0 70k + 20k 增生件 | Boss「棘狱守卫」剪影，右后景 | 盾/甲是硬表面，Tripo 只吃"轮廓+有机增生" |
| T05 | `ch2_skull_gate_ornament.png` | 二 | 1:1 | 15k | 左门楣门饰，可做 2 处 | 骨+铜混合浮雕，母版 1 个 |
| T06 | `ch2_cage_bones.png` | 二 | 1:1 | 20k | 悬吊铁笼 + 笼内囚徒骨堆，第一视觉锚点 | **修订：整件出**（含笼体），栏杆偏细，进 Blender 后把 8 根竖栏做直加粗 |
| T07 | `ch2_bone_debris.png` | 二 | 1:1 | 12k | 平台散落骨堆 / 镣铐尸骸，可做 3 变体 | 与 T06 骨骼风格同源 |
| T08 | `ch3_void_rock.png` | 三 | 1:1 | 4k–8k | 虚空残骸，全图约 12 处实例 | 3–4 个变体，Blender 也可用 Displace 替代 |
| T09 | `ch3_dragon_ring_fitting.png` | 三 | 1:1 | 3k | 铜环四个龙首扣件 | 环本体 Blender 曲线，只出扣件母版 |
| T10 | `ch3_sea_eye_core.png` | 三 | 1:1 | 60k（可选） | 二阶段巨瞳实体 | 若走纯 VFX 可不出；要实体眼就出 |
| T11 | `ch4_whale_bone_arch.png` | 四 | 1:1 | 25k × 2–3 段 | 鲸骨拱天顶，左右各一 | 出 2–3 段母版，Blender 阵列 + 弯曲成拱 |
| T12 | `ch4_chiwen.png` | 四 | 1:1 | LOD0 70k | Boss「螭吻」，光柱中剪影 | 龙首鱼身，腹内潮水是特效不是模型 |
| T13 | `ch4_drowned_statue.png` | 四 | 3:4 | 25k × 2 变体 | 骨白命官立像，左右各一 | 2 个变体：完整 / 断臂破损 |
| T14 | `ch4_coral_mutation.png` | 四 | 1:1 | 10k × 2 | 潮蚀异化珊瑚，前景压角 | 深红尖刺 + 弱自发光 |
| T15 | `ch4_bell_dragon_knob.png` | 四 | 1:1 | 6k | 沉钟（钟顶龙钮），中景地标 | **修订：整件出**（含钟体），Blender 只做壁厚/钟口开口 |

## 三、与标注图的差异（两处已按实际可用性修订）

| 项 | 标注图上写的 | 实际出图 | 处理 |
|---|---|---|---|
| T06 悬吊铁笼 | 「笼体 Blender，笼内骨堆 Tripo」 | 图里给了整件（笼 + 骨） | 直接整件 Tripo 出，进 Blender 把竖栏做直、加厚到 ≥3 cm，再分离成"笼"和"骨堆"两个物件 |
| T15 沉钟 | 「钟体 Blender 车削，龙钮 Tripo」 | 图里给了整件（钟 + 龙钮） | 整件 Tripo 出反而更省事（钟是不复杂回转体 + 一对浮雕），Blender 只修壁厚和钟口 |

其余 13 件与标注图一致。

## 四、拿去 Tripo 之前的三条建议

1. **一张图不如四张图**。Tripo 支持多视角输入，把同一件资产补出「正 / 侧 / 背 / 顶」四张，重建质量明显高于单张 3/4 视角。当前每件只有一张 3/4 视角，属于"能出型、细节靠后期修"的水平。
2. **先降面数再进 Blender**。Tripo 导出时选 Quad + 目标面数（按上表），别直接用默认 30 万面，否则修模成本比手搓还高。
3. **贴图只留底色**。AI 重建的贴图会把"浅灰摄影棚底"也烘进去，进 Blender 后统一重展 UV + 重贴（配色按《场景参考图-画风配色与构图规范.md》的 60/30/10）。

## 五、文件位置

```
E:\godot_game_by_fable\
├─ art_assets\
│   ├─ ch1_abyss_eye.png           T01
│   ├─ ch1_coral_fan.png           T02
│   ├─ ch1_pillar_dragon_capital.png T03
│   ├─ ch2_warden.png              T04
│   ├─ ch2_skull_gate_ornament.png T05
│   ├─ ch2_cage_bones.png          T06
│   ├─ ch2_bone_debris.png         T07
│   ├─ ch3_void_rock.png           T08
│   ├─ ch3_dragon_ring_fitting.png T09
│   ├─ ch3_sea_eye_core.png        T10
│   ├─ ch4_whale_bone_arch.png     T11
│   ├─ ch4_chiwen.png              T12
│   ├─ ch4_drowned_statue.png      T13
│   ├─ ch4_coral_mutation.png      T14
│   ├─ ch4_bell_dragon_knob.png    T15
│   └─ contact_sheet_v2.png        联络表
└─ art_refs\
    ├─ gen_assets.py               提示词表（A/B/C 三组）+ 简单串行版
    ├─ gen_assets2.py              带 12 次重试 + 任务台账的稳定版
    ├─ make_asset_sheet.py         联络表脚本
    └─ qa_cells.py                 抽检脚本
```

复现某一组：

```powershell
$py='C:\Users\Sunrise\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
& $py E:\godot_game_by_fable\art_refs\gen_assets2.py --group a
& $py E:\godot_game_by_fable\art_refs\gen_assets2.py --group b --only ch2_cage_bones
```


## 追加（2026-10-21 晚）

| 编号 | 文件 | 内容 | 源 | 备注 |
|---|---|---|---|---|
| T16 | ch1_stone_lantern.png | 石灯笼（龙宫式） | APIMart 生成参考图 | 用户已出模型 → glb_game/T16_lantern.glb |
| T17 | ch1_pillar_module.png | 柱身模块（柱础+莲座+收分+铜箍） | APIMart 生成参考图 | 用户已出模型 → glb_game/T17_pillar.glb |

入模记录：111.glb → T16_lantern.glb（191.5 万面 → 5.74 万）；222.glb → T17_pillar.glb（189.6 万 → 5.69 万），命令 `gltfpack -i <src> -o <dst> -si 0.03 -noq -kn`。
