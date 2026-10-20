# Blender 远程操控工具包

实测环境（2026-10-19 验证通过）

| 项 | 值 |
|---|---|
| Blender | 5.1.2 便携版 `E:\blender\app\blender.exe`（build 2026-05-19；2026-10-20 已从 `E:\blender.exe` 迁到 `E:\blender\app\`） |
| 内置 Python | 3.13.9 |
| CPU | Intel Core Ultra 9 275HX，24 核 |
| 内存 | 31.4 GB |
| GPU | NVIDIA RTX 5070 Laptop（OptiX 可用）+ Intel 核显 |
| 控制插件 | BlenderMCP v1.2，`%APPDATA%\Blender Foundation\Blender\5.1\scripts\addons\addon.py` |
| 插件状态 | **已启用并写入用户偏好**，GUI 启动即自动监听 `127.0.0.1:9876` |

---

## 两种操控方式

### 1) 无头模式：最适合批量生成资产

不需要任何插件，也不需要开窗口。

```powershell
& E:\blender\app\blender.exe --background --factory-startup --python "tools\blender\example_build_prop.py"
```

- 退出码 0 表示成功；脚本里的 `print(...)` 直接出现在 stdout。
- `--factory-startup` 跳过用户偏好（插件不会加载，但无头模式本来也用不到插件）。
- 适合：批量建模、批量渲染、导出 glTF/FBX、跑参数扫描。

### 2) 实时模式：操控已打开的 Blender 窗口

可以把 Blender 当成一个"活的远程对象"：改场景、抓视口截图、看用户当前在做什么。

```powershell
# 启动并等待控制端口就绪（已开 Blender 的话会直接复用）
python tools\blender\launch_blender.py
python tools\blender\launch_blender.py --file tools\blender\out\crystal_prop.blend

# 让 Blender 执行一段代码
python tools\blender\blender_ctl.py --file build_scene.py

# 查询场景 / 抓视口截图
python tools\blender\blender_ctl.py --type get_scene_info
python tools\blender\blender_ctl.py --screenshot C:\tmp\view.png
```

**协议**：裸 TCP，端口 9876，一条 JSON 进、一条 JSON 出，无长度前缀、无换行分隔。
支持的命令类型：`get_scene_info`、`get_object_info`、`get_viewport_screenshot`、
`execute_code`（可执行任意 bpy 代码）、以及可选的 PolyHaven / Hyper3D / Sketchfab 资产接口。

> 插件**拒绝在 `blender -b` 下启动**（源码里显式判断 `bpy.app.background`），
> 因为无头模式没有事件循环，定时器回调不会执行。实时控制必须有 GUI。

---

## 已实测通过的能力

| 能力 | 结果 |
|---|---|
| 后台执行 Python / bpy | ✅ exit 0 |
| 程序化建模（球/立方体/圆环/圆锥 + 材质） | ✅ |
| 保存 `.blend` | ✅ |
| 导出 `.glb`（Godot 可直接导入） | ✅ 91 KB / 1244 三角面 |
| Workbench 渲染 640×480 | ✅ 4 s |
| EEVEE 渲染 640×480 | ✅ 13 s |
| EEVEE 渲染 1280×720 | ✅ ~15 s（含建场景） |
| Cycles GPU（OptiX, RTX 5070） | ✅ 320×240 @16 采样 **2.1 s** |
| 实时 TCP 改场景 | ✅ 见 `proof/live_viewport_tcp_controlled.png` |
| 实时 TCP 渲染 + 导出 | ✅ 见 `proof/live_eevee_render.png`、`proof/live_scene.glb` |

---

## 踩过的坑（都已在脚本里绕开）

1. **Blender 界面是中文** → 节点名被本地化成"原理化 BSDF"。
   找节点必须用 `bl_idname == "ShaderNodeBsdfPrincipled"`，不能用 `nodes.get("Principled BSDF")`。
   同理，材质插槽名也可能本地化，`set_input()` 里做了多名字兜底。
2. **PowerShell 会吃掉 `--code` 里的引号** → 代码一律写进 `.py` 文件再用 `--file` 传。
3. **PowerShell `Out-File -Encoding utf8` 会写 BOM** → Blender 报
   `invalid non-printable character U+FEFF`。用编辑工具写文件，或 `utf8NoBOM`。
4. **5.1 的 render engine 枚举只暴露 `BLENDER_EEVEE`**，
   `CYCLES` / `BLENDER_WORKBENCH` 不在枚举里但可以直接赋值使用。
5. **Cycles 的 `HIPEW initialization failed` 警告无害** —— 那是 AMD HIP 库，N 卡走 OptiX。
6. **`bpy.ops.view3d.*` 需要 area + region 的完整 context override**，
   在 addon 的定时器回调里 `poll()` 会失败；截图用 `get_viewport_screenshot` 就没这问题。
7. **启动 splash 会挡住截图** —— 自动化截图前先给 Blender 窗口发一次 `ESC`。
8. **这台机器的 shell 是 Windows PowerShell 5.1（`pwsh` 不在 PATH），且
   ExecutionPolicy 禁止运行未签名的 `.ps1`** → 所以启动器用 Python 写，不用 ps1。
9. **addon 已写入用户偏好并持久启用**：直接双击/命令行开 Blender 就会自动监听 9876，
   不需要再传 `--python boot.py`。但如果传了 `--factory-startup`，用户偏好被跳过，
   服务就不会起来（无头模式本来也不需要它）。

---

## Poly Haven 免费资产库（已配通并实测）

不需要 API Key，只要联网 + Blender GUI 开着。资源规模：**997 个 HDRI、521 个模型、
大量可平铺 PBR 贴图**，全部 CC0 可商用。

```powershell
python tools\blender\polyhaven.py enable                 # 打开当前会话的开关
python tools\blender\polyhaven.py status
python tools\blender\polyhaven.py categories hdris       # 分类 + 数量
python tools\blender\polyhaven.py search models --category props
python tools\blender\polyhaven.py hdri brown_photostudio_02 --res 1k
python tools\blender\polyhaven.py download Lantern_01 models --res 1k
python tools\blender\polyhaven.py library                # 已下载到本地的 HDRI
```

实测结果：

| 动作 | 结果 |
|---|---|
| 搜索 HDRI / 模型 | ✅ 返回分类与 id |
| 下载 HDRI 1k 并设为世界环境 | ✅ 1.57 MB Radiance HDR，已打包进 .blend |
| 下载模型并导入场景 | ✅ `Lantern_01` + 玻璃部件，4 张 1k 贴图全部打包 |
| 模型导出 GLB 给 Godot | ✅ 2.5 MB（贴图内嵌），33,902 三角面 |
| Cycles GPU + HDRI 布光渲染 | ✅ 见 `proof/hdri_lit_render.png`、`out/lantern_preview.png` |

**三个必须知道的坑：**

1. **开关不持久**：`blendermcp_use_polyhaven` 是 scene 级属性，每次新建场景都会回到
   `False`，插件命令会直接不可用（报 handler 不存在）。→ 先跑 `polyhaven.py enable`。
2. **插件原生下载的 HDRI 存不住**：它把 `.hdr` 读到临时文件、不打包、重启即失效，
   而且它没有"另存为 HDR"的可靠路径（`save_render()` 会写成 PNG 却挂着 `.hdr` 后缀，
   动态范围直接丢光 —— 我实测踩到了）。
   → `polyhaven.py hdri` 改为**直接从 api.polyhaven.com 下载原始 HDR** 到
   `library/hdri/`，再重连世界节点并 `pack()`，永久可用、可复用、可进版本库。
3. **模型是真实世界尺寸**：`Lantern_01` 只有 0.122 × 0.097 × 0.294 米；导入后要按
   游戏单位缩放。同时三角面数偏高（灯笼 3.4 万面），2.5D 项目建议先减面再导出。

---

## 文件说明

| 文件 | 作用 |
|---|---|
| `blender_ctl.py` | 远程控制客户端（TCP，无第三方依赖） |
| `launch_blender.py` | 启动 Blender 并等待 9876 就绪（Python 版，绕开 ps1 执行策略） |
| `polyhaven.py` | Poly Haven 搜索 / 下载 / 持久化 HDRI 库（纯标准库 HTTP） |
| `example_build_prop.py` | 无头示例：建一个水晶道具 → 渲染预览 → 导出 GLB |
| `library/hdri/` | 本地 HDRI 库（原始 HDR，可复用、可提交） |
| `library/models/` | 从 Poly Haven 导入后导出的 GLB |
| `out/` | 示例产物（png / glb / blend） |
| `proof/` | 验证证据图与导出文件 |

---

## 还需要准备什么？

**基本不用了。** 已具备完整闭环：建模 → 材质 → 渲染 → 导出 glTF → 丢进 Godot。
连免费 HDRI / 贴图 / 模型素材库也已打通。

可选项（只有想要才需要）：

- **AI 生成 3D 模型**（Hyper3D Rodin / Sketchfab / 腾讯混元）：
  需要各自 API Key，在 Blender 侧栏 `BlenderMCP` 面板里填入并勾选启用。
  Sketchfab 的搜索/下载不需要付费，但下载需要账号 API Key。
- **渲染提速**：Cycles 已可用 OptiX；降噪 OIDN 已内置。
- **MCP 客户端方式**：工作区已有 `.mcp.json` 指向 `uvx blender-mcp`，
  若想用标准 MCP 工具接口而非本工具包的 TCP 直连，需要 DSH 侧启用 MCP。
