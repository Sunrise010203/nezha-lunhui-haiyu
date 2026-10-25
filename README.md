# 哪吒 · 轮回海域

一款用 **Godot 4.6.3** 制作的 **2.5D 横版动作游戏**：四章、四个 Boss、八种敌人、五个技能，
全部关卡用 GDScript 程序化构建，全部音效用代码合成，全部特效由着色器 + 程序化网格生成，
美术资产走「AI 出图 → 图生 3D → Blender 修模 → glTF 进引擎」的流水线。

个人项目 · AI 辅助美术 · 无外部美术/音频素材依赖。

| 项目 | 值 |
|---|---|
| 引擎 | Godot 4.6.3（Forward+ · D3D12 · Jolt Physics） |
| 语言 | GDScript（43 个脚本 + 全局单例，约 1.96 万行） |
| 平台 | Windows x86_64（可移植到其他平台，见「快速开始」） |
| 分辨率 | 1920×1080，`canvas_items` + `expand` 拉伸 |
| 内容 | 4 章 · 170/174/172/176 米 · 4 Boss · 8 敌人 · 5 技能 |
| 仓库 | 私有 GitHub，1941 个跟踪文件 / 约 4.0 GB（含 .git 约 1.05 GB） |

> 本仓库只保留这一份 README。历史的设计、评审、施工图、备份说明（共 67 份 Markdown）
> 已于 2026-10-25 清理删除，其中仍有长期价值的结论已全部折入本文对应章节。

---

## 目录

1. [快速开始](#1-快速开始)
2. [四章内容](#2-四章内容)
3. [玩法系统](#3-玩法系统)
4. [技术架构](#4-技术架构)
5. [美术与音效管线](#5-美术与音效管线)
6. [工具链](#6-工具链)
7. [性能基线](#7-性能基线)
8. [验证与证据](#8-验证与证据)
9. [仓库、忽略规则与备份](#9-仓库忽略规则与备份)
10. [已知技术债与未完成项](#10-已知技术债与未完成项)
11. [踩坑记录](#11-踩坑记录)
12. [许可](#12-许可)

---

## 1. 快速开始

### 1.1 环境要求

- **Godot 4.6.3-stable**（版本必须匹配：`project.godot` 的 `config/features` 写的就是 `4.6`；
  4.5 打开会因 `rendering_device` 与 Jolt 配置报错）
- Windows 10/11 + 支持 D3D12 的显卡（本机实测 RTX 5070 Laptop）
- 磁盘：检出约 3.0 GB；首次导入后会额外生成 `001/.godot/` 导入缓存（约 1.5 GB，已忽略）

非 Windows 平台需要改两处：`001/project.godot` 里删掉 `rendering_device/driver.windows="d3d12"`，
按需把渲染后端换成 Vulkan；`Jolt Physics` 在 4.6 各平台都可直接用。

### 1.2 克隆与首次导入

```bash
git clone https://github.com/Sunrise010203/nezha-lunhui-haiyu.git
cd nezha-lunhui-haiyu
```

**仓库不含 `001/.godot/`（导入缓存），但含全部 `.import` 参数文件。**
所以克隆后第一次必须做一次完整导入，否则编辑器里贴图/模型是灰的：

```powershell
& 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe' --path .\001 --import
```

（等它跑完、进程退出即可；第二次起就不用再跑。）

### 1.3 运行

```powershell
# 编辑器
& 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe' --path .\001 -e

# 直接运行
& 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe' --path .\001
```

启动即为 1920×1080 窗口，**F11** 切全屏。主菜单 →「开始游戏」进闯关模式（先播三页可跳过的序章），
「选择关卡」进选关界面。

### 1.4 导出可分发包

`001/export_presets.cfg` 已配置好 Windows Desktop / x86_64 / `embed_pck=true`。
需要先安装 4.6.3.stable 的官方导出模板到 `%APPDATA%\Godot\export_templates\4.6.3.stable\`：

```powershell
& 'E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' `
    --headless --path .\001 --export-release "Windows Desktop" .\builds\nezha.exe
```

`builds/` 是导出产物目录，已被 `.gitignore` 排除。

### 1.5 目录结构

```
.
├─ 001/                      Godot 工程根（用编辑器打开这一层）
│  ├─ project.godot          引擎配置（1920×1080 / Forward+ / Jolt / D3D12）
│  ├─ export_presets.cfg     Windows 导出预设
│  ├─ autoload/game.gd       全局单例 Game（输入注册 / 音频 / 转场 / 材质与特效工厂 / 进度）
│  ├─ scenes/                8 个场景，全部是「根节点 + 脚本」，内容由代码构建
│  ├─ scripts/               43 个玩法脚本（关卡 / 玩家 / 敌人 / Boss / HUD / 特效 / 音频）
│  ├─ shaders/               19 个 .gdshader
│  ├─ audio/                 30 个离线烘焙的 .res 音效
│  ├─ theme/ui_theme.tres    UI 主题
│  ├─ art/                   进引擎的美术资产（models / raw / ref / sprites / textures / vfx）
│  └─ tools/                 开发工具脚本（截图 / 性能 / 回归测试 / 探查）
├─ tools/                    工程外工具（Python 25 个 + Blender 约 75 个 + PowerShell）
├─ art_refs/                 章节参考图与出图脚本（APIMart）
├─ art_assets/               单体资产参考图与清单（不入库 PNG）
├─ _review/                  验证证据（JSON / 日志 / 文本，871 个文件；大图已清理）
├─ art_source/               Blender 真源（1.89 GB，**不入库**，见第 9 节）
├─ README.md
└─ .gitignore
```

---

## 2. 四章内容

四章**场景风格刻意做开**：只共 明度阶梯、语义色、构图规范，不共用色相。

| 章 | 名称 | 主色（60/30/10） | 长度 | 新增机制 | Boss |
|---|---|---|---|---|---|
| 一 | 东海 · 碎潮回廊 | 青蓝龙宫外廊 | 约 170 m（实测 164） | 三连击 / 下砸 / 三段灵力技能 | 归墟之喉 · 渊狱兽（480 HP） |
| 二 | 龙宫深狱 | 铁灰暗红 | 174 m | 狱火喷口、举盾重甲、固定炮台 | 棘狱守卫（520 HP） |
| 三 | 归墟虚空 · 海眼 | 虚空黑紫 `#06040D` / 冷紫石 `#241A35` / 珍珠青 `#7FF0E0` | 172 m | **F 混天绫**（摆荡 + 缚敌）、引力井 | 归墟海眼（三核 3×180 + 巨瞳 180） |
| 四 | 龙骨沉殿 · 潮心 | 玉青 `#2E6B5B` / 骨白 `#E8E2CF` / 朽金 `#B8912F` | 176 m | **G 定潮**（卸 / 架 / 引潮）、潮纹、潮脉、潮纹碑 | 潮心 · 螭吻（300 HP = 100×3） |

每章都有一条**专属纵向剖面**，拒绝「y 恒定」的同构地图：

- 一：断桥水廊——四段桥面 + 三道 1.5 m 断口 + 桥下浅水（落水扣 4 血并推回，冷却 2 s）
- 二：熔炉竖井——炉底从 −2.3 降到 −4.1，双喷口交替点火
- 三：坠空石板——五块高度 0.6 / −0.4 / 1.2 / 0.2 / 0.6 的悬浮板
- 四：潮汐沟——潮脉把玩家推入深渊或抬上高台

### 2.1 第三章「归墟虚空 · 海眼」

没有天空、水面、宫殿、石柱、海草。只有黑色虚空、漂浮的封印石板、残骸、垂直光柱与缓慢旋转的海眼巨涡。
几乎无环境光，靠光柱 + 边缘光 + 符文环发光建立层次。

**混天绫（F / R）一键两用：**

- **摆荡**：身前 10 m、−20°~70° 扇形内找铜环锚点（全章 11 个，绳长 3.5~8 m，单次最长 4 s）。
  脱手速度 = 切向速度 ×1.25 + 向上 2.0，冷却 0.4 s；松手 0.35 s 内再按 F 可连抓下一个环。
- **缚敌**：6 m 内小怪拉近 2 m + 定身 0.8 s（耗灵 20）；大型/Boss 改为自身位移 5 m + 15 伤害（耗灵 15），CD 2 s。

**引力井**：半径 7 m、强度 6 m/s² 线性衰减，全章 3 处，**只做位移干扰、不做持续伤害**。

**Boss 归墟海眼**：三枚「封印之瞳」各 180 HP（总 540），公转半径 3.5、0.5 rad/s，
每破一核提速 +40%，招式水弹扇 3~5 发 / 潮涌环 / 引力井，预警 0.6~0.9 s。
三核全灭 → 巨瞳 180 HP 二阶段（约 40 s）：潮涌环每 4 s、海眼脉冲每 6 s（1.2 s 预警）。
**正解是用场地两端的锚点把角色甩上高空**——摆荡不是装饰，是 Boss 战的必需动作。

节奏数据：A~I 九段、检查点 4 处（x = −4 / 63 / 86 / 149）、敌人 13、龙魂 3、回春莲 2、灵珠 6~8、
可跳断口 ≤2.2 m、锚点间距 ≤9 m、坠落 −8 HP。

### 2.2 第四章「龙骨沉殿 · 潮心」

鲸骨拱顶 + 天顶破口冷白光柱（教堂式）+ 玉青侧补。新装饰：龙肋骨、潮纹碑、沉钟。
A~H 八段、莲台 5、潮脉 4、敌人 14（含潮生 3）、潮纹碑 3、龙魂 3、灵珠 7。
设计约束：每段最多引入 2 个新要素，敌人不加速、不提高接触伤害——难度对齐第一章。

**定潮（G / T）三形态：**

| 形态 | 操作 | 对象 | 效果 |
|---|---|---|---|
| 卸 | 点按 | 投射物 | 身前 2.6 m、正面 120~150° 水膜，免伤并弹回 20（完美 ×1.5 = 30），命中返还潮纹 |
| 架 | 点按 | 带起手的近战 | 免伤 + 打断僵直 0.8 s + 反震 30 + 击退 3.5 m；玩家 0.1 s 无敌且**不进硬直**；完美的「破绽」2.0 s，受伤 ×1.6 |
| 引潮 | 按住 ≥0.2 s | 弹幕 | 8 m / 120° 吸入，1.2 s 内最多 6 枚悬停（移速 ×0.55），松手 ±12° 扇射、每枚 14，耗灵 20 + 1 格潮纹 |

参数：判定窗口 0.30 s、完美提前量 0.10 s、空挥 CD 0.40 s、收招 0.16 s。接触式 `touch_damage` 不可弹。

**潮纹**：3 格上限，**唯一收入是命中**（轻 0.15 / 重 0.35 / 下砸 0.30 / 技能 0.20，单挥 ≤0.30、单次施法 ≤0.60），
没有自然回复。1 格 ≈ 2 组三连击 ≈ 4 s，满格 ≈ 8~10 s 输出窗口。完美弹反返还 1 格，普通「架」净亏 1 格，
0 格时三形态全部失效——设计意图是「先打，才有资格弹」。

**潮脉水流**：推力 6 m/s²，顺流移速 +35%、逆流 −35%，4 处（推入深渊 2、向上抬升 3~4 m 1、竞技场内 1），纯力场不改跳跃。
**潮纹碑**：只吃「卸回来的潮弹」，三碑依次点亮开了浮空台，掉落灵力。

**Boss 潮心 · 螭吻**：300 HP（100×3），宽 6 m 长 9 m。P1 吞潮（潮珠扇 9 枚、吸潮 3 s、尾扫）→
P2 腾潮（潮柱 4 处 + 红外环 1.0 s 预警、逆鳞露出 2.5 s 可弹 ×1.5、潮涌浪）→
P3 潮心（每 4 s 环形弹幕 + 召唤 2 只潮生）。尾扫/扑咬起手 0.6~0.7 s 可「架」；浊潮不可弹不可吸。
**不弹也能通关**（P2 近战仅 0.4×）——弹反是更快解，不是唯一解。

---

## 3. 玩法系统

### 3.1 两种模式

- **闯关模式**（主菜单「开始游戏」）：四章连续。初始只有 **Q 三昧真火**；
  每集满一章的 3 枚龙魂残片解锁一个新技能——第一章 → **E 乾坤圈**，第二章 → **V 风火轮**（最多两个）。
  章节奖励每章只发一次（重打同一章不会刷技能）。
  **死亡后弹出「命陨潮渊」→「重新挑战本章」= 本章整章重来**：进度/残片/临时战斗状态清零，
  已解锁技能保留，不会退回第一章。
- **选关模式**（主菜单「选择关卡」）：全部技能解锁，四章独立任选；**死亡后在当前关莲台复活**，
  已激活的莲台与当前灵力保留。

通关记录写在 `user://progress.cfg`：记录「哪章已通关 + 每章最快时间」，选关界面显示
「✓ 已通关 · 最快 MM:SS」。**检查点、残片、死亡计数仍只在内存**（见第 10 节）。

### 3.2 操作

| 操作 | 键位 |
|---|---|
| 移动 | A / D 或 ← / → |
| 跳跃（可二段跳） | 空格 / W / ↑ |
| 冲刺（瞬身无敌） | Shift / L |
| 三连击 | J / 鼠标左键 |
| 重击 / 空中下砸 | K / 鼠标右键 |
| 三昧真火（50 灵力） | Q / U |
| 乾坤圈（25 灵力） | E / I —— 按住蓄力 1 s：射程 8.5→16.5 m、伤害 16→25，命中定身 0.5 s（Boss 免疫） |
| 风火轮（60 灵力） | V / C —— 向上腾空；腾空期间按 K 下砸，伤害 24→48 |
| 混天绫（第三章） | F / R —— 摆荡 / 连抓（0.35 s 内再按）/ 缚敌 |
| 定潮（第四章） | G / T —— 点按卸·架，按住引潮 |
| 暂停 | Esc |
| 全屏 | F11 |

**键位没有写进 `project.godot`**：InputMap 在 `001/autoload/game.gd:352-363` 运行时注册，
F11 全屏在 `game.gd:339`（见第 10 节 A-06）。

### 3.3 角色数值（`001/scripts/player.gd`）

| 项 | 值 |
|---|---|
| 生命 | `MAX_HP = 100.0` |
| 灵力 | `MAX_ENERGY = 100.0` |
| 移速 | `SPEED = 7.2` m/s |
| 冲刺 | `DASH_SPEED = 17.0`、`DASH_TIME = 0.18 s`、`DASH_CD = 0.75 s`，无敌 = 冲刺时长 + 0.06 s |
| 技能消耗 | Q `50` / E `25` / V `60` / 引潮 `20` |
| 混天绫消耗 | 大型目标 `15` / 小怪 `20` |
| 乾坤圈齐射速度 | `VOLLEY_SPEED = 22.0` |

**灵力恢复**：脱战 3 s 后开始，每秒恢复上限的 5%（5 点/秒）。受击、攻击、施法立刻重置这 3 s 延迟；
暂停与死亡期间不恢复。莲台/检查点复活**保留当前灵力**（不回满），只清除临时战斗状态。

### 3.4 敌人（8 种，`001/scripts/enemy_*.gd`）

| 脚本 | 名称 | 章 | 行为要点 |
|---|---|---|---|
| `enemy_crawler.gd` | 潮汐爬行者 | 一/四 | 地面巡逻，近距离扑咬 |
| `enemy_shooter.gd` | 渊喉浮母 | 一/二/四 | 悬浮射击，保持高度差 |
| `enemy_divider.gd` | 分潮 | 一/三/四 | 死亡后裂成两只子体 |
| `enemy_guard.gd` | 狱卒 | 二 | 举盾重甲，正面普攻免伤 65%，重击或背后才有效 |
| `enemy_turret.gd` | 囚晶 | 二/四 | 固定炮台，预警后三连发 |
| `enemy_wraith.gd` | 潮魇 | 三/四 | 悬浮突进，预警后高速冲刺 |
| `enemy_bomber.gd` | 渊爆水母 | 三/四 | 贴身后引爆 |
| `enemy_spawnling.gd` | 潮生 | 四 | 扑咬有 0.4 s 起手，**可被「架」** |

基类 `enemy_base.gd` 统一处理生命/受击/击退/灼烧/束缚/坠渊判定/轮廓光。

### 3.5 Boss

| 脚本 | Boss | HP | 阶段 |
|---|---|---|---|
| `boss_maw.gd:37` | 归墟之喉 · 渊狱兽 | 480 | 50% 进二阶段，70%/35% 各召唤一次 |
| `boss_warden.gd:80` | 棘狱守卫 | 520 | 50% 进二阶段，68%/30% 召唤 |
| `boss_sea_eye.gd` | 归墟海眼 | 3×180 + 180 | 三核 → 巨瞳 |
| `boss_chiwen.gd` | 潮心 · 螭吻 | 3×100 | 吞潮 / 腾潮 / 潮心 |

**危险物统一用红外环预警**（`style_warning_ring()`），预警窗口 0.6~1.2 s，与全章一致——
这是弹反/卸架「可读」的前提：起手动作 + 红闪 + 吸气音三通道同时给。

---

## 4. 技术架构

### 4.1 引擎配置（`001/project.godot`）

```ini
config/name="哪吒·轮回海域"          config/version="0.2.0"
run/main_scene="res://scenes/main_menu.tscn"
config/features=("4.6", "Forward Plus")
viewport 1920×1080 · stretch=canvas_items / expand · theme=ui_theme.tres
3d/physics_engine="Jolt Physics"      rendering_device/driver.windows="d3d12"
msaa_3d=1(2×) · debanding=true · aniso=3 · clear_color=(0.008,0.025,0.045,1)
autoload: Game="*res://autoload/game.gd"
```

### 4.2 全局单例 `Game`（`001/autoload/game.gd`，878 行）

输入映射注册、音频播放池、场景转场与加载屏、材质工厂、特效工厂/prewarm、进度读写、
命中反馈（顿帧/闪白/震屏）、全局工具函数。被 15 个脚本引用 305 处——方便，也是最大的耦合点（A-05）。

### 4.3 关卡是「代码构建」的

`scenes/level_1..4.tscn` 都只有一个根节点挂脚本，`_ready()` 里顺序建立：
环境（天空/雾/云/远景三层视差）→ 地形积木（地面/断口/平台）→ 装饰（柱/藻/骨/碑/灯笼）→
检查点/莲台 → 敌人遭遇 → 竞技场 → Boss 战流程 → 生死循环。

- `level_base.gd`（2159 行）：全部可复用的构建函数与流程状态机
- `level_1.gd`~`level_4.gd`：各章的具体编排与专属机关（喷口/锚点/引力井/潮脉/潮纹碑）
- 好处：改一个数值就是改一行，没有 `.tscn` 二进制 diff；代价：无法在编辑器里所见即所得（A-03/A-11）

### 4.4 玩家与动画

`player.gd`（2254 行）用 `act: String` + 一组散落计时变量驱动状态（A-07），
动画由 `nezha_motion.gd`（150 行）重定向 14 个 ARP 剪辑：
`Idle / FightIdle / Run / Jump / Fall / Plunge / Land / Roll / Stab / Slash / ThrustSlash / UpwardThrust / Hit / Death`。
映射：atk1→Stab、atk2→Slash、atk3→ThrustSlash、重击→UpwardThrust、受击→Hit、死亡→Death；
Idle/FightIdle/Run/Fall 循环，其余按 `DURATIONS`（0.30~1.0 s）覆盖。
**移动、命中窗口、无敌帧全部仍由逻辑控制**，动画只负责表现；武器挂点用逐帧 GRIP/GRIP_FRAMES 校姿。

敌人/Boss 没有外部剪辑，用 `enemy_motion.gd` / `boss_motion.gd` 程序化骨骼摆动。

### 4.5 特效与音效

特效是三级分工，没有一层用「整张 AI 图当动画」：

1. **APIMart gpt-image-2** 出单张灰度素材（火舌/流纹/浪花/冲击/烟雾/符文遮罩）——灰度便于运行时染色；
2. **Blender** 出几何（弧形刀光带、环带、锥壳/半球壳、碎片），必要时导序列帧；
3. **Godot** 负责 `GPUParticles3D`、shader（UV 流动/溶解/边缘发光/少量屏幕扭曲）与时序。

接入一律挂在**真实判定事件**上（命中/受击/弹反/落地/死亡）沿用 `Game.burst()`、`_slash_fx()`，
不靠动画进度猜时序。预算口径看**同屏透明覆盖面积与帧时间**，不数粒子个数。

- `combat_vfx.gd`（201 行）+ `vfx_instance.gd`：临时网格上限 **96**，**不参与碰撞、不加灯、不投影**，
  随暂停与时间缩放（避免暂停后特效继续跑）；启动时做一次预热，消除首次出现的 94 ms 管线编译卡顿。
- 音效 30 个 `.res`，由 `audio_synth.gd` 逐采样合成、`001/tools/bake_audio.gd` 离线烘焙进库。
  早期版本每次启动花 0.43~0.45 s 现场合成 21 条 22050 Hz 音效，现已消除。

### 4.6 着色器（19 个）

`sky` `water` `ch1_water` `caustics` `vignette` `grade` `light_shaft` `backdrop_layer`
`ch1_far_matte` `silhouette_key` `blob_shadow` `rim_overlay` `outline` `char_body`
`combat_vfx` `combat_smoke` `fx_sprite_fade` `menu_bg` `menu_fx`

全部手写 `.gdshader`，无 ShaderGraph、无外部 shader 依赖。

---

## 5. 美术与音效管线

### 5.1 六步流水线

```
① 概念图（APIMart gpt-image-2, 1k, 约 $0.0085/张）
        ↓  统一前缀：single isolated 3D game asset, centered, three-quarter front view ...
② 单体资产参考图（T01–T17，浅暖灰底，正/侧/背/顶四视角更佳）
        ↓  按建议面数导出 Quad
③ 图生 3D（Tripo）：LOD0 60k~90k，装饰件 3k~25k
        ↓
④ Blender 修模：重展 UV、按 60/30/10 重贴色、修壁厚/栏杆、拆分物件、加锚点
        ↓  降面：gltfpack -i <src> -o <dst> -si 0.03 -noq -kn
⑤ glTF 导出（Y 向上、面向 +Z；单文件 <100 MB，GitHub 单文件硬限）
        ↓
⑥ Godot 导入：size_limit=2048 / compress/mode=2 / normal map 压缩（改 .import 参数，不动源 PNG）
```

**三级兜底**：任何角色都按 GLB → 立绘 Sprite3D → 程序化网格 逐级降级，任意一级缺失都能跑（A-09）。

**什么交给 Tripo、什么留给 Blender**（这是流水线里最省工的一条经验）：

| 类型 | 归属 | 例 |
|---|---|---|
| 有机 / 不规则 / 雕刻感 | **Tripo 出母版** | 怪物、珊瑚、骨骸、雕像、鲸骨拱、玩家 |
| 硬表面 / 建筑 / 需拼接 / 需精确米数 / 薄结构 | **Blender 手搓** | 柱、平台、栏杆、链条、铁笼、铜环、碑、钟 |
| 水雾、光柱、粒子 | **Shader** | 海面、雾、光柱、尘埃 |
| 布料摆动 | Blender（布料 + 骨骼） | 混天绫、幡 |

Tripo 的**六条红线**：链网栅、玩法件（平台/踏板）、建筑模块、透明折射、布料、文字符文。
它的输出必须过一遍 Blender——三角面拓扑、UV 乱、无 LOD、比例随机，直进引擎必然返工。

**契约参数**（`tools/check_model_contract.py` 校验）：

- pivot 在底面中心、+Z 朝镜头、AABB `min.y = 0`
- 减面预算：敌人 15–25k、装饰 ≤5k、贴图 1024→512 + mipmap
- 材质固定 4 槽；2.5D 角色屏高约 17%，5–10k 三角面 + 平涂就够
- kit 命名 `kit_ch1_platform_float_a_w4.glb`，目录 `art/kits/ch1/{geo,trim,atlas}`

### 5.2 哪吒角色案例（`art_source/nezha/`，源文件不入库）

- Blender 5.1.2 + Auto-Rig Pro 3.78.26，通过 BlenderMCP 的本地 TCP 接口脚本化执行
- 焊接 UV 接缝重合顶点：**54,217 → 27,438** 网格顶点；统一 1.6 m 高、脚底 Z=0
- ARP 人形参考骨对齐 + Heat Map 绑定；修掉 3,225 个未加权顶点 → **0 个**；每顶点 ≤4 骨骼
- 导出 **67 根变形骨骼 + 14 个动作**，53,418 三角面，8K 颜色/法线贴图
- 13 个 Mixamo FBX（30 FPS、65 骨、缩放 0.829538）经 ARP Remap 烘焙到 67 根变形骨
- 颜色偏黑 → sRGB 中间调提亮，曲线指数 **0.72**，产出 `Nezha_Albedo_Bright.png`（8192×8192）
- 验收：7 个 QA 姿势重导入最大顶点误差 0.033 mm；14 动作抽查 56 姿势最大蒙皮误差 **0.0401 mm**；
  Godot 实机 **80 项检查**全通过；极端姿势边长比极值 7.43（肩甲/裙甲仍有局部压缩，属已知限制）

### 5.3 美术规范（四章共用）

- 画风定名「**深海青铜 × 霓虹符文**」：半写实 3D 材质 + Toon 2~3 阶 + 冷色轮廓光
- **光比**：环境光 ≤ 主光 1/3
- **60/30/10**：主色 60%、辅色 30%、点缀 10%（每章只换色相）
- **明度四层**：远景剪影 8~18% → 中景 25~40% → 玩法面 45~65% → 关键物 75~90%；
  背景永远比前景更暗、更灰、更冷；雾色 = 远景同色相提亮 10~15%
  实测平均明度：ch1 24.5% / ch2 10.6% / ch3 12.0% / ch4 19.9%
- **语义色**：危险红 `#FF4A32`、奖励金 `#F2C14E`、可交互青 `#4FE8FF`、治疗绿 `#5FE08C`
- **发光语义**：装饰 emission ≤0.35，同屏发光色 ≤3 种；发光只标记「可交互 / 危险 / 奖励」
- **构图**：纯侧视 16:9；玩法带 y 62~82%、玩家区 x 5~31% 必须空、Boss 压右下三分点；
  断口落在中三分线 ±12%；UI 安全区 5% inset
- **三秒一景**：每 8~12 m 一个视觉锚点
- **明确否掉**：整屏 AI 背景贴图（改用雾 + 三层视差 + 剪影）、涨潮水位机制、TAA（平涂横版拖影，改用 MSAA）、
  全屏连续自发光 trim、无意义悬浮石块、Boss 悬停过高致站地攻击全空、用 FOV 做弹反镜头
- **性能红线**：draw < 120、三角形 < 30 万、显存 < 700 MB

### 5.4 资产规模

| 目录 | 文件 | 大小 | 入库 |
|---|---|---|---|
| `001/art/models` | 675 | 917.4 MB | 是（glb_game 324.5 / enemies_arp 203.3 / bosses_arp 122.5 / props 43.4 / ch1_ruins 25.3 / 角色 198.4） |
| `001/art/{raw,ref,sprites,textures,vfx}` | 109 | 41.2 MB | 是 |
| `art_source/` | — | 1892.3 MB | **否**（Blender 真源，单文件 143 MB 超 GitHub 100 MB 硬限） |
| `art_assets/*.png` | 17 | 60.3 MB | 否（1k 参考图，可由脚本重出） |

命名契约由 `tools/check_model_contract.py` 强制：`*_arp.glb`（ARP 绑定角色）、
`glb_game/T##_*.glb`（Tripo 单体件）、`enemies_arp/`、`bosses_arp/`、`props/`、`ch1_ruins/`。

**早期资产的教训**：第一代 GLB 是 Tripo 直出直进——哪吒 24k、爬行者 159k、浮母 261k、Boss 196k 三角面，
全部 1024² 贴图、平均 8 MB，8 个敌人同屏就是**约 123 万面**。性能评审把它列为 draw call 的第一大来源，
后来的做法是「先减面、再进 Blender、最后 gltfpack」，并把阴影/LOD 纳入验收。

### 5.5 明确没有采用的路线

- **写实 3A**：单角色 200–800 人时，场景要全重建。与「一个人 + AI」的产能不匹配。
- **二次元写实**：脸部雕刻 20–30 人日，且有恐怖谷 + 程序化动画僵硬的双重风险。
- **直接拿 Tripo / Auto-Rig 的骨架进游戏**：等于重写 `player.gd` 的动作层。
- **照搬「ARP 从零绑骨 + Mixamo 重定向」两道转换**：`rib.L.1` 这类非标骨保不住；正确做法是复用现役 22 骨 + Data Transfer 传权重。
- **硬表面交给 Tripo，或 Tripo 输出直进引擎**：铁笼、平台、栏杆全部返工过一遍。
- **SSAO**（实测 +3.4 ms）、**TAA**（平涂横版有鬼影）、**LightmapGI / SDFGI / VoxelGI**（程序化关卡不适用）。
- **为体积雾牺牲画面**：实测它不是瓶颈。
- **把 AI 多格图当动画**、**用 `save_render` 存 `.hdr`**：前者时序不可控，后者会烧掉高光。

---

## 6. 工具链

### 6.1 `001/tools/`（GDScript，在引擎内跑）

| 脚本 | 用途 |
|---|---|
| `bake_audio.gd` | 离线烘焙 30 个音效到 `audio/*.res` |
| `capture.gd` | 真实渲染器截图（场景 / 输出路径 / 传送 x / 等待帧数 / normal\|boss） |
| `capture_combat_vfx.gd` | 战斗特效截图与像素校验 |
| `perf_probe.gd` | 旧探针：构建耗时 / draw / 三角形 / 显存 / 帧时间 |
| `perf_slice.gd` | 时间轴采样 4–10 s，输出 avg/p50/p95/p99/1% low/max + BUILD_MS + draw/prim/VRAM |
| `test_gameplay_states.gd` | 玩法回归（75 条断言：落水/死亡菜单/灵力恢复/输入教学/存档字段…） |
| `test_combat_vfx.gd` / `test_huojianqiang.gd` / `test_enemy_levels.gd` | 特效 13 项 / 火尖枪 34 项 / 敌人分关 |
| `probe_ch4.tscn` | 第四章自动走查（分段落地 / 竞技场 / 潮纹碑 / 敌人数 / Boss 三阶段 / 弹反 / 死亡重置） |
| `validate_nezha_arp.gd` | Godot 侧 80 项 ARP 资产检查 |
| `preview_{boss,enemy,nezha}_motion.gd` | 动作预览与截图 |
| `dump_*`（12 个）/ `probe_*`（4 个）/ `find_blob` / `inspect_env` / `verify_props` | 一次性探查工具，保留作回归对照 |

### 6.2 `tools/`（Python 25 个，引擎外）

`check_model_contract.py`（命名/体积契约）、`glb_basecolor.py`、`glb_textures.py`、`inspect_glb.py`、
`compare_scene.py`、`write_tscn.py`、`prepare_ch1_matte.py`、`generate_vfx_texture_library.py`、
`prepare_vfx_texture_library.py`、`preview_sheet.py`、`tex_sheet.py`、`fix_hide_block.py`，
以及 13 个 `patch_*.py`（历史一次性补丁，保留作变更记录）。

### 6.3 `tools/blender/`（约 75 个 Python）

按前缀分组：`build_*`（建模）、`prepare_*`（源文件准备）、`inspect_*` / `probe_*`（诊断）、
`validate_*`（导出验证）、`review_*` / `contact_sheet*`（联系表）、`retarget_*` / `bake_*` / `finalize_*`（动作与权重）、
`blender_ctl.py` / `launch_blender.py`（后台驱动）。
**这些脚本只针对本工程源模型的拓扑与姿态，不是通用自动绑定器。**

### 6.4 常用命令

```powershell
$G='E:\GODOT\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
$P='E:\godot_game_by_fable\001'

# 重新烘焙音效
& $G --headless --path $P --script res://tools/bake_audio.gd

# 截图（注意：必须用真实渲染器，不能 --headless）
& $G --path $P --script res://tools/capture.gd -- res://scenes/level_1.tscn E:\tmp\shot.png 30 260 normal

# 性能采样（标签里可加 vfxoff 关粒子对照）
& $G --path $P --resolution 1920x1080 --position 0,0 --script res://tools/perf_slice.gd -- res://scenes/level_1.tscn 140 ch1_boss_active

# 玩法回归
& $G --headless --path $P --script res://tools/test_gameplay_states.gd

# 第四章自动走查
& $G --headless --path $P res://tools/probe_ch4.tscn
```

---

## 7. 性能基线

**口径**：`tools/perf_slice.gd` 时间轴采样 4–10 s（物理 60 Hz，渲染不锁帧）；
下表是 **CPU 主线程帧时间与上限 fps**。`GPU_TIME_API=unavailable`——Godot 4.6 没有公开的 GPU pass 计时 API，
所以**不能**把下表当 GPU 耗时，也不能据此判断瓶颈在 CPU 还是 GPU。
「1% low」= 最差 1% 帧的平均帧时间（ms），括号内为等价 fps；「加载」= `BUILD_MS`（启动到可操作，本机热缓存）。

环境：RTX 5070 Laptop · D3D12 Forward+ · 1920×1080 · VSync 关 · 2026-10-22 实测。

| 场景 | avg | p50 | p95 | p99 | 1% low (ms / fps) | max | 上限 fps | draw | 三角形 | 显存 |
|---|---|---|---|---|---|---|---|---|---|---|
| 第一章出生点 | 2.56 ms | 2.50 | 2.78 | 2.78 | 2.84 / 352 | 3.31 | 390 | 108 | 39.8 万 | 772 MB |
| 第二章出生点 | 1.82 ms | 1.85 | 1.85 | 2.13 | 2.87 / 348 | 14.42 | 550 | 110 | 31.5 万 | 718 MB |
| 第三章出生点 | 1.55 ms | 1.52 | 1.67 | 1.85 | 2.10 / 476 | 5.88 | 643 | 107 | 53.7 万 | 686 MB |
| 第四章出生点 | 1.56 ms | 1.52 | 1.67 | 1.67 | 1.69 / 592 | 2.17 | 641 | 89 | 45.5 万 | 686 MB |
| 第一章 Boss 激活（x=140） | 2.69 ms | 2.78 | 2.78 | 3.03 | 3.60 / 278 | 6.99 | 372 | 121 | 87.7 万 | 772 MB |
| 第一章 Boss · 粒子节点关 | 2.65 ms | 2.78 | 2.78 | 3.03 | 3.21 / 312 | 4.78 | 377 | 117 | 87.2 万 | 772 MB |
| 第一章竞技场（x=60，刷怪） | 2.52 ms | 2.38 | 2.78 | 2.78 | 3.27 / 306 | 6.85 | 396 | 139 | 106.5 万 | 772 MB |
| 第一章竞技场 · 粒子节点关 | 2.08 ms | 2.08 | 2.24 | — | — | 9.35 | 481 | 136 | 108.8 万 | 772 MB |
| 第一章断桥水面（x=105） | 2.62 ms | 2.78 | 2.78 | 3.03 | 3.25 / 308 | 7.55 | 382 | 151 | 115.1 万 | 772 MB |

- 加载：`BUILD_MS` 111–165 ms（第一章 165 ms，第四章 128 ms），这是脚本化建关时间，不含引擎/着色器预热。
- 粒子对照（`vfxoff` 只把 13 个 `GPUParticles3D`/`CPUParticles3D` 的 `emitting`/`visible` 置 false，
  **不是 CombatVFX 全关**）：Boss 场景 372 → 377 fps（+1.3%，噪声量级）；竞技场 396 → 481 fps（**+21.5%**）。
  结论只能是「这两个场景对 13 个粒子节点开关的敏感度不同」，不能推广成「粒子不是瓶颈」。
- 单帧尖峰：第二章 14.4 ms、竞技场粒子关 9.35 ms，属首次资源/着色器上载，稳定后回落；
  1% low 最差为 Boss 3.60 ms（278 fps）。
- **覆盖缺口**：四章只实测出生点；Boss 激活 / 竞技场刷怪 / 断桥水面只有第一章，第二至四章的同类负载**未实测**，不得外推。
- 历史表格（≈88/92/75/82 draw、21/14/29/33 万三角形、610/546/610/788 MB）来自旧探针口径，**不可与上表直接对比**。

### 7.1 早期基线（评审口径，2560×1494，优化之前）

| 指标 | 值 |
|---|---|
| 场景规模 | 413 个 MeshInstance / 27 盏 OmniLight / 12–13 个粒子节点 |
| draw call | 375–384（其中 **304 属平行光阴影 pass**） |
| 三角形 | 806k（其中 **703k = 87% 在阴影 pass**） |
| 3D 实际渲染分辨率 | 3414×1993 = 6.8 MP（1.33× **隐性超采样**） |
| 显存 | 799 MB（关 MSAA 后 652 MB） |
| 帧时间 | avg 14.0 ms / p95 14.6 ms，Boss 区 **max 94.4 ms** |
| 启动 | 引擎 1.22 s + 关卡构建 519–563 ms + 音频现场合成 431–455 ms |

### 7.2 已实施并验证的优化

| 措施 | 效果 |
|---|---|
| 关闭平行光阴影 pass | draw call −81%、三角形 −87%（弱卡省 3–5 ms） |
| 修正 1.33× 隐性超采样 | 像素 −69%（4–6 ms） |
| trim 自发光 1.3→0.5、宽度 0.08→0.02、glow 0.9→1.25、MSAA 2×→0 | 合计省 3.8 ms |
| 特效预热（首次出现的材质/粒子） | 消除 94 ms 单帧卡顿 |
| 131 个独立材质 → MultiMesh / 共享材质 | 柱 26 个、海草约 90 个实例合批 |
| 音频离线烘焙 | 消除每次启动 431–455 ms |
| 统一采样口径 + `perf_slice.gd` | 才有本页第 7 节可对比的表 |

**瓶颈定位**：阴影 pass 与隐性超采样；**体积雾不是瓶颈**（开关实测 13.91 vs 14.04 ms）——
真正要改的是「27 盏灯全往雾里注入」，应设 VFE=0 + 距离淡化，只给玩家 0.25 / Boss 0.4 留雾。

### 7.3 评审提出的画面问题（部分仍存在）

- 27 盏 OmniLight 全部注入体积雾且无距离淡化
- 自发光 trim 过曝成 **26 px 宽的全屏青线**
- 敌人与背景的明度差只有 **15–20%**（对策：轮廓光 + 自发光 + 色相分离）
- Boss 战场地 33 m，而视野只有 16.6 m → Boss 经常出画（现已用双目标取景缓解）
- 平台前脸占下半屏 **35–40%**，压缩了玩法视野

---

## 8. 验证与证据

自动化检查都在 `001/tools/`，全部可 headless 跑。当前通过情况：

| 检查 | 内容 | 结果 |
|---|---|---|
| `test_gameplay_states.gd` | 落水 / 死亡菜单 / 灵力恢复 / 输入教学 / 存档字段等 75 条断言 | 全通过 |
| `test_combat_vfx.gd` | 六类纹理与战斗特效接入 | 13 项通过 |
| `test_huojianqiang.gd` | 火尖枪挂点与动作 | 34 项通过 |
| `test_enemy_levels.gd` | 敌人分关与出生配置 | 全通过 |
| `test_ch1_hybrid.gd` | 第一章混合废墟地形 | 全通过 |
| `validate_nezha_arp.gd` | ARP 资产：网格/骨骼/绑定/贴图/动作 | 80 项通过 |
| `probe_ch4.tscn` | 第四章分段/竞技场/潮纹碑/Boss 三阶段/弹反/死亡重置 | 全通过 |

`_review/` 保留 **871 个文字证据文件**（大图与大二进制已于 2026-10-25 清理）：
各模型的 `*_rig.json` / `*_motion.json` / `export_validation.json` / `level_tests.json`、
Blender 与 Godot 的完整日志、性能原始日志 `perf_t6_*.txt`、导入参数差异 `baseline-t6/imports/diffs`、
以及 `playable_slice/verify_t7/launch_capture.py`（客户区精确尺寸 + 真实点击的 HUD 截图脚本）。

---

## 9. 仓库、忽略规则与备份

### 9.1 仓库状态

- 远端：`https://github.com/Sunrise010203/nezha-lunhui-haiyu.git`（私有）
- 跟踪 **1941 个文件**；工作区约 2.99 GB，含 `.git` 约 4.04 GB
- 单文件最大 `001/art/models/nezha_arp.glb` 81.3 MB（GitHub 提醒线 50 MB，硬限 100 MB）
- 历史：`d26d3bc` 之后是 2026-10-25 的清理、补推与文档收敛共 8 个提交（`52a5574` … `888abb0`）

### 9.2 为什么 `art_source/` 不入库

`art_source/` 是 1.89 GB 的 Blender 真源（`.blend` + FBX + 8K 贴图）。其中
`bosses/06_canonical.blend` 单文件 **143.3 MB**，超过 GitHub 100 MB 硬限，无法普通推送；
用 Git LFS 又会把仓库成本推高一个量级。因此策略是：**真源本地保留、仓库只放导出后的 glTF**。
克隆者拿到的是「能直接跑、能改参数、能重新导出」的工程，但不含重新生成模型的能力——
需要改模型时应在有 `art_source/` 的机器上工作。

`.gitignore` 的关键规则：

```gitignore
.godot/                     # Godot 导入缓存，可 --import 重建
/builds/                    # 导出产物
*.pck  *.exe
_shots/  _baseline/  shots_ch4/  shot_*.png
_review/**/*.{png,jpg,pck,exe,npy,cache}
/art_source/                # 1.89 GB 真源
/game_assets/               # 与 001/art/models/glb_game 重复的中间件
/art_assets/*.{png,jpg}
/art_tmp/  _tmp_*/  /tools/appdata/  /tools/gltfpack/
__pycache__/  *.pyc  *.tmp  *.log  *.bak  *.blend1  .vscode/
```

### 9.3 2026-10-25 清理记录

工程从 **9.35 GB 降到 3.20 GB**（随后补推新资产到 4.04 GB 含 .git），删除约 **6.3 GB** 可再生成物：

| 类别 | 路径 | 回收 |
|---|---|---|
| Godot 导入缓存 | `001/.godot` | 1582 MB |
| 试玩包导出 | `builds/`（含 3 个 530 MB exe） | 1067 MB |
| 审阅大二进制/截图 | `_review` 下 png/jpg/pck/exe/npy/cache | 2481 MB |
| 重复中间件 | `game_assets/` | 366 MB |
| 迭代/基线截图 | `_shots/`、`_baseline/`、`shots_ch4/` | 554 MB |
| 概念图与临时素材 | `art_assets/*.png`、`art_tmp/`、`_tmp_*`、`tools/appdata/` | 240 MB |
| 其余 | `_acl_reports`、0 字节空脚本、备份 GLB、`__pycache__` | 5 MB |

**没有删任何源文件**：`art_source/`、`001/art/`、`001/scripts/`、`_review` 的文字证据、`tools/` 全部保留。

### 9.4 克隆后如果要重新生成

- 导入缓存：`godot --path 001 --import`
- 音效：`bake_audio.gd`（源码级合成，无外部音频）
- 模型：需要 `art_source/`（不在仓库）→ Blender 脚本在 `tools/blender/`
- 参考图：`art_refs/gen_assets2.py`（需 APIMart key）重新生成 T01–T17

---

## 10. 已知技术债与未完成项

### 10.1 未完成功能

- **关卡内进度存档**：只保存「哪章已通关 + 最快时间」，检查点/残片/死亡计数仍在内存（A-14）
- **设置页**：音量总线、分辨率、画质、按键改绑全部没有（A-15）
- **手柄支持**：无
- **战斗数值平衡**：灵力经济、攻击缓冲、Boss 血量仍按当前数值，未做系统性调参
- 键位提示贴左缘的裁切：早期 1920×1080 截图的历史观察；`verify_t7/` 在 1920×1080 / 1600×900 / 1280×720 三档均未复现，暂不列为现存缺陷

### 10.2 架构债务（来自 2026-10 架构评审，编号保留）

| 编号 | 问题 | 现状 |
|---|---|---|
| A-01 | 没有版本控制 | **已解决**（本仓库） |
| A-02 | 没有导出预设 | **已解决**（`export_presets.cfg`） |
| A-03 | 场景全是空壳，代码建关 | 有意设计，代价是无法所见即所得 |
| A-05 | `Game` 单例承担 9 类职责、被 15 个脚本引用 305 处（player 87 / level_1 75），还有反向依赖：`player.gd:1048` 直接写 `Game.death_count` | 未拆 |
| A-06 | InputMap 在 `_init` 运行时注册、不进 `project.godot` | 未改（键位标签也硬编码在 HUD） |
| A-07 | 玩家状态机 = `act: String` + 散落计时变量 | 未重构 |
| A-08 | 跨类直接访问「私有」字段 | 未收敛 |
| A-09 | GLB→精灵→程序化网格 三级兜底复制了 4 份 | 未抽公共层 |
| A-10 | 伤害/速度/坐标/颜色/物理层号硬编码分散 | 部分集中在 `player.gd` 顶部常量 |
| A-11 | `player.gd`(2254) / `level_base.gd`(2159) 体量超单文件合理规模 | 未拆 |
| A-12 | 全库 **0 个 `preload()`、0 个 `@export`**，运行期 `load()` + `ResourceLoader.exists` 探测、缺资产静默降级；已因此丢失过 `nezha_jump.png`、`crawler_lunge.png` | 有意（三级兜底），代价是失败不报错 |
| A-13 | `await`/场景切换与 Tween/`queue_free` 竞争 | 已知风险点，未系统性整改 |
| A-14 | 无存档 | 见 10.1 |
| A-15 | 无设置 | 见 10.1 |
| A-16 | 无 CI | 有 9 个 headless 测试脚本，但没有流水线 |

### 10.3 美术遗留

- 哪吒 53,418 三角面，高于旧模型的 12,000 面预算；肩甲/裙甲在极端姿势下仍有局部压缩拉伸（边长比极值 7.43）
- 源模型有 1,731 条非流形边，不含布料碰撞与重拓扑
- 敌人/Boss 动画是程序化骨骼摆动，没有手工 K 帧

---

## 11. 踩坑记录

- **`capture.gd` 不能加 `--headless`**：没有渲染器会截出黑图。
- **导出过滤只排除开发资源**（`tools/*`、`*.py`、showcase、`art/models/glb_game/*`、`art/tmp/*`、`art_source/*`、`_artgen/*`），
  不删除源资产。第一章远景贴图 `res://art/ref/ch1_palace_far.png` 若被误排除，`ch1_ruins.gd` 会 `push_error`
  并退化成水下雾色渐变（不会出现白块）。
- **`.import` 参数改动是 106 个状态项**（97 个已跟踪修改 + 9 个新增资源）：只改 `size_limit=2048` /
  `compress/mode=2` / normal map 压缩，源 PNG/GLB 不动。要取回旧设置用 `git show HEAD:<path>`。
- **GitHub 单文件 100 MB 硬限**：`GH001 Large files detected` 只是 >50 MB 的提醒，81.3 MB 仍可推；
  143 MB 的 `.blend` 直接被拒 → 这是 `art_source/` 不入库的根本原因。
- **大批量推送要分批**：单批 324 MB 可以过，但一次推 GB 级会被代理节点重置（`Connection was reset`）。
  仓库 `.git/config` 已设 `http.https://github.com/.proxy`、`http.postBuffer=524288000`。
- **PowerShell 会把 git 的 stderr 当 `NativeCommandError`**：命令返回码 1 但 push 可能已成功，
  必须用 `git ls-remote --heads origin main` 与 `git rev-parse HEAD` 对比确认。
- **`builds/` 里的 exe 曾是 530 MB**，且每次导出都留一份 → 已加入忽略并清理。

---

## 12. 许可

个人项目，未附加开源许可。仓库中的 Godot 引擎相关文件、第三方字体（如涉及）遵循其各自许可。
AI 生成的美术资产（`art_assets/`、经 Tripo/ARP 处理的模型）版权状态按所使用平台的服务条款处理。
