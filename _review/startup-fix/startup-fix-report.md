# 启动修复报告 —— 说明收敛与环境改动审计

任务：t3（收敛启动说明与安全边界记录）· 成员 startup-engineer · 日期 2026-10-22
本报告只记录**已经发生的事实**、**证据**、**推断**与**未恢复项**；本任务不启动游戏进程、不改游戏/启动器。

---

## 1. 结论摘要

| 项 | 内容 |
| --- | --- |
| 故障现象 | 双击 `builds/playable-slice/nezha_ch1_playable_r2.exe` 无窗口，进程数秒内退出 |
| 崩溃签名 | `c0000005`，`fault offset 0x2d985a7`，`READ @ 0x50`（Windows 事件日志 / WER 与自建调试器一致） |
| 直接原因（证据级） | 进程在 `E:\godot_game_by_fable\` 内被以 Low Integrity（`S-1-16-4096`）运行 → 无法写 `%APPDATA%` → Godot 建不了 `user://` → 引擎初始化阶段空指针崩溃 |
| 交付方案 | `builds/playable-slice/nezha_ch1_playable_r2_launcher.exe`（153,745 B，SHA-256 `fba7da39d6a3649fca6a61f1157d2734d1e3b2b792e6feee658360f168609bca`）：**不改变任何权限/完整性**，只把子进程的 `APPDATA`/`TEMP`/`TMP` 指向包内 `userdata\`，再拉起游戏本体 |
| 游戏本体 | `nezha_ch1_playable_r2.exe` 557,508,232 B，SHA-256 `5551152b922f7dd02dde168eaf93b0730439f2ee7305608257c07e10c371ca35`（未改动） |
| 未闭合项 | **真实 Explorer 双击未验证**（本任务禁止启动进程，判定权在 verifier）；另有 U1–U5 见第 6 节 |

---

## 2. 证据与推断的区分

| 观察项 | 记录 | 归类 |
| --- | --- | --- |
| 受控目录内启动的进程完整性为 Low | 游戏进程采样恒为 `S-1-16-4096`（`spawn_probe*.py`、`probe_token.py`、任务计划外的 `ilprobe2.json`） | **证据** |
| 同一可执行文件在别处启动为 Medium | 同一 exe / `notepad.exe` 拷贝到受控树外为 `S-1-16-8192`；留在树内则 `S-1-16-4096` | **证据** |
| 限制与路径相关、与文件内容无关 | 上述拷贝对照；`notepad.exe` 亦复现 | **证据** |
| 项目目录带显式 Low 完整性标签 | `icacls "E:\godot_game_by_fable"` → `Mandatory Label\Low Mandatory Level:(OI)(CI)(NW)`；子项同名 ACE 带 `(I)` 继承标记；`E:\` 根无该标签（故非自上层继承） | **证据**（本次只读复核） |
| 该标签由 `CodexSandboxService.OpenAI.Codex` 放置 | 服务存在且 RUNNING（LocalSystem，二进制在 `C:\Program Files\WindowsApps\OpenAI.Codex_26.1016.6573.0_x64__2p2nqsd0c76g0\app\resources\codex-windows-sandbox-service.exe`），行为与现象吻合；**未抓取该服务的实时加标签动作**，也不能排除其它机器级策略共同作用 | **推断** |
| Low 进程写不进 `%APPDATA%`，且 DACL 不是原因 | `%APPDATA%\Godot\app_userdata\哪吒·轮回海域` 内 `Everyone:完全控制` 仍失败；`CreateProcess` 前该目录 DACL 原本就有 `Sunrise:(F)`；错误为 `Could not create directory` / `Failed to open 'user://logs/...'` | **证据** |
| 本会话无法修改完整性标签 | `whoami /priv` 无 `SeSecurityPrivilege`，`BUILTIN\Administrators` 组仅为 deny-only（UAC 过滤）；对同类临时目录执行 `icacls /setintegritylevel` 被拒（Access is denied） | **证据** |
| 崩溃发生在引擎初始化早期 | `--verbose` 只输出 `WorkerThreadPool: 24 threads, 7 max low-priority.` 一行，崩在版本横幅之前；崩溃时已加载 43 个模块但**无 `d3d12.dll`/`nvwgf2umx`/`vulkan-1`** | **证据** |
| 与游戏/导出内容无关 | 崩溃偏移在旧包与新包完全相同（`0x2d985a7`）；受控树外同一 exe 默认 `%APPDATA%` 启动正常 | **证据** |

> 对外表述口径：**“本机受控目录会把其中的进程强制降为低完整性”**。不宣称具体是哪个组件、以何种方式实现（那仍是推断）。

---

## 3. 启动器边界（做了什么 / 没做什么）

**做：**

1. 以自身所在目录为根：游戏 = `<dir>\nezha_ch1_playable_r2.exe`，用户数据 = `<dir>\userdata\`；
2. 为**子进程**设置 `APPDATA=<dir>\userdata`、`TEMP/TMP=<dir>\userdata\temp`，`cwd=<dir>`；
3. 需要时**只复制**（`CopyFileW`，不移动、不删除）`%APPDATA%\Godot\app_userdata\哪吒·轮回海域\progress.cfg` 到便携目录（目标已存在则跳过）；
4. 启动游戏、等待其退出、把启动信息写 `userdata\launcher.log`（UTF-16LE）。

**没做：**

- 不提升权限、不调整自身或子进程的完整性级别、不调用 `AdjustTokenPrivileges` 降/提权；
- 不改 ACL/完整性标签、不写注册表、不装/改服务与计划任务；
- 不尝试绕过本机的运行限制（不改系统安全设置、不关 Defender、不动服务）；
- 不写 `%APPDATA%`、不删除或移动用户原有存档/日志。

即：**启动器权限与普通程序一致，只把“子进程写数据的位置”落到已允许的游戏目录内**。

---

## 4. 验证现状与缺口

| 批次 | 启动链 | 结果 | 证据 |
| --- | --- | --- | --- |
| A | Medium 完整性父进程 `CreateProcessW`（`cwd=游戏目录`）拉起启动器 | 0.81 s 出 `class=Engine` 可见窗口；游戏进程 `S-1-16-4096`；1600×900 客户区三张截图非黑；选关读到四章已通关 | `_review/startup-fix/cap/capture.json`、`cap/menu.png`、`cap/select.png`、`cap/ch1.png` |
| B | Windows 任务计划（DSH 之外，用户自身令牌）跑整条链 | 1.21 s 出窗口；`EXIT=0`；同样的三张截图 | `_review/startup-fix/cap_outside/capture.json`、`cap_outside/*.png` |
| C | `cmd /c start "" <launcher>`（shell 启动链） | exit 0；可见 `class=Engine` 窗口（1295×757）；主菜单截图可见 | `_review/startup-fix/cap_shellstart_menu.png` |

**必须说清楚的两点：**

1. A/B/C **都不是**“在资源管理器里双击启动器”。任务计划以用户令牌运行、`cmd start` 走 shell 启动链，二者与 Explorer 双击**接近但不等价**（父进程、令牌、启动信息都可能不同）。
2. 本会话直接调用 `shell32.ShellExecuteW` 会**无限阻塞**（两次 240 s 无任何输出、连结果文件都没写），因此不能用它取证；这不是环境正常的证据，也不能替代 Explorer 双击。

→ **真实 Explorer 双击验证仍缺失**，由 verifier 承担；在它通过之前，不能对外宣称“默认双击已可用”。

---

## 5. 环境改动审计（原值 / 操作 / 恢复证据）

> 本任务（t3）期间**未做任何新的安全配置改动**；下列“操作”均发生在 t1 诊断阶段，本任务仅做只读复核。

| # | 项目 | 操作前原值 | 本会话操作 | 恢复方式 | 现状证据 | 结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `HKCU\Software\Microsoft\Windows\Windows Error Reporting\LocalDumps` | **未做操作前快照（缺陷，见 U1）**；默认 Windows 不创建该键 | `reg add` 建 `LocalDumps\nezha_ch1_playable_r2.exe`（DumpFolder=`_review/startup-fix/dumps`、DumpType=2、DumpCount=3） | `reg delete ...\LocalDumps /f` 整键删除 | `reg query` → “系统找不到指定的注册表值” | **已删除**；原值不可考 → U1 |
| 2 | Windows 计划任务 `Nezha*`（10 个：NezhaCapOutside、NezhaDefaultProbe、NezhaEveryone、NezhaIL、NezhaIL2、NezhaLogFile、NezhaMatrix、NezhaPyProbe、NezhaSimple、NezhaWriteProbe） | 无（名称由本会话新造） | `schtasks /create` + `/run` 若干次 | `schtasks /delete /tn <name> /f` 逐个删除 | `schtasks /query` 过滤 `Nezha` 计数 **0** | **已全部删除** |
| 3 | 项目目录 `E:\godot_game_by_fable` 的 ACL / 完整性标签 | 本会话前该目录已被以受限方式使用（见“反证”）；标签内容未能取得操作前快照（缺口，见 U5） | 曾尝试 `icacls ... /setintegritylevel`（同类命令在 `E:\_expLbl` 明确报 Access is denied） | 无需恢复 | ①令牌为 Medium 且无 `SeSecurityPrivilege`（`whoami /priv` 无该项；Administrators 仅 deny-only）→ **物理上无法写 SACL**；②时间反证：用户 16:56、以及 14:47 旧包的崩溃早于本会话任何 `icacls` 尝试，且同目录同偏移；③当前复核：`Mandatory Label\Low Mandatory Level:(OI)(CI)(NW)` 在子项全为 `(I)` 继承、`E:\` 根无该标签 | **未改动**（能力排除 + 时间反证）；标签“由谁放置”仍为推断（见第 2 节） |
| 4 | 临时目录 DACL（`E:\_expD5` 上 `icacls /grant Everyone:(OI)(CI)F`） | 临时目录，本会话新建 | 授予 Everyone 完全控制（用于验证 DACL 不是根因） | `rm -rf /e/_expD5` 删除整个临时目录 | `ls -d /e/_exp*` 无结果 | **随目录删除**，未触及全局/项目 ACL |
| 5 | 服务配置（`CodexSandboxService.OpenAI.Codex` 等） | AUTO_START / LocalSystem / WIN32_PACKAGED_PROCESS | 只读查询：`sc query`、`sc qc`、`fltmc filters`（被拒）、`fsutil`（被拒） | 无操作需恢复 | `sc qc` 复核同上，未变 | **未改动**（无 `sc config/start/stop`） |
| 6 | 全局环境变量 | `HKCU\Environment` 中无 `APPDATA`/`TEMP`/`TMP` 覆盖项 | 未使用 `setx`；`APPDATA` 仅在**子进程环境块**内设置（harness `env=` / 启动器 `SetEnvironmentVariableW`） | 无 | `reg query HKCU\Environment` 复核：无 `APPDATA`/`TEMP`/`TMP` | **未改动** |
| 7 | 用户存档 `%APPDATA%\Godot\app_userdata\哪吒·轮回海域\progress.cfg` | 196 B，SHA-256 `313e8cb3bd1357bc20277685a69cd5b66b7a35fa70cbb40285c9ff0a3624dbf8` | 只被读取复制到便携目录 | 无需 | 便携副本哈希相同；原文件仍在 | **未改动** |
| 8 | 默认 userdata 的日志 | `logs/godot.log`（原内容为编辑器探针输出） | 一次崩溃实验触发引擎日志轮转，原内容移到 `godot2026-10-22T17.45.41.log` | 轮转前内容另存 `_review/startup-fix/backup/godot.log.default_pre_rotate_test`（此前已用它还原过一次） | 轮转文件仍在 logs/ 下，内容未丢 | **内容保全**；未回滚文件名 → U4 |
| 9 | Git 仓库 | 最后提交 `d26d3bc`（2026-10-20 20:44，art 相关） | 无 `git add/commit/push` | 无 | `git log -1` 仍为 `d26d3bc`；工作区脏文件为本会话前既存 | **无提交/推送** |
| 10 | 崩溃转储目录 `_review/startup-fix/dumps` | 本会话新建（未产生任何 dmp，因 WER 服务停止） | 创建目录、写注册表指向它 | `rm -rf` | 目录已不存在 | **已清理** |
| 11 | 用户数据备份 | — | `cp -a` 默认 userdata（349 文件 / 75,172,426 B） | 保留 | `_review/startup-fix/backup/userdata_哪吒_pre`、`userdata_哪吒_20261022_pre`、`godot.log.default_pre_rotate_test` | **保留** |

---

## 6. 未恢复 / 无法核实项

| ID | 项 | 说明 | 建议 |
| --- | --- | --- | --- |
| U1 | `HKCU\...\Windows Error Reporting\LocalDumps` 原值未快照 | 操作前没记录该键是否存在、是否已有其它应用子键；我建了子键后又**删除整个 LocalDumps 键**。若此前存在其它应用的 HKCU 转储配置，可能被一并删除（默认 Windows 不创建该项；HKLM 下 NVIDIA/Bambu 等厂商条目未受影响） | 若你曾为本机其它程序配置过 HKCU 转储，请告知；否则无需处理 |
| U2 | 真实 Explorer 双击未验证 | 本任务禁止启动进程；A/B/C 三条链均为等价而非等价于 Explorer | 交由 verifier 执行并回填结论 |
| U3 | 崩溃进程的残留条目 | `nezha_ch1_playable_r2.exe` PID 39144 / 47868：32 K 工作集、无窗口、无 CPU 增长；`taskkill` 返回拒绝访问 | 属系统残留/无窗口占位，不主动处理，避免误杀 |
| U4 | 默认日志的轮转未回滚 | 原 `godot.log` 内容被引擎轮转为 `godot2026-10-22T17.45.41.log`；内容已另存备份 | 如需恢复原始文件名，可在确认无进程占用后手工 rename |
| U5 | SACL/完整性标签无法读取复核 | 无管理员权限，`icacls` 的 SACL 读取与 `Get-Acl -Audit` 均受限；且操作前**未对项目目录标签做快照**。“未改动”由 `SeSecurityPrivilege` 缺失（写不进去）+ 16:56/14:47 崩溃早于本会话（限制先于我的操作）反证得出，而非读回比对 | 管理员可在提权 shell 里用 `icacls` + 安全审计日志复核 |

---

## 7. 证据索引（本目录）

| 文件 | 说明 |
| --- | --- |
| `launcher/nezha_launcher.c` | 启动器源码（ASCII-only，`gcc -O2 -municode -mwindows`） |
| `cap/capture.json`、`cap/{menu,select,ch1}.png` | 批次 A：CreateProcessW 链；0.81 s 出窗；`S-1-16-4096`；1600×900 客户区 |
| `cap_outside/capture.json`、`cap_outside/*.png` | 批次 B：任务计划在 DSH 之外；1.21 s 出窗；`EXIT=0` |
| `cap_shellstart_menu.png`、`cap_shellstart.log` | 批次 C：`cmd /c start` 链；窗口 1295×757 |
| `capture_launcher.py`、`run_exe.py`、`spawn_probe*.py`、`probe_token.py`、`dbg_capture.py` | 取证脚本（启动/令牌/调试器） |
| `wer_97b0cbad.txt` | 16:56 崩溃的 WER 报告转存（UTF-16LE→UTF-8） |
| `dbg_default.dbg.json` | 自建调试器抓到的 `c0000005 @ exe+0x2d985a7`、`READ 0x50`、43 个已加载模块 |
| `outside/` | 在 DSH 之外用任务计划跑的脚本与结果（`ilprobe2.json`、`m/*.rc` 等） |
| `backup/` | 用户数据备份（349 文件）+ 日志原样副本 |

### 只读复核命令（不含启动进程）

```bash
export MSYS2_ARG_CONV_EXCL="*"
/c/Windows/System32/icacls.exe "E:/godot_game_by_fable" | grep -i mandatory
/c/Windows/System32/reg.exe query "HKCU\Software\Microsoft\Windows\Windows Error Reporting\LocalDumps"
/c/Windows/System32/schtasks.exe /query /fo LIST | grep -ci Nezha
/c/Windows/System32/sc.exe qc CodexSandboxService.OpenAI.Codex
/c/Windows/System32/whoami.exe /priv | grep -i SeSecurity
git log -1 --format="%h %cd %s" --date=iso
```

---

## 8. 本任务改动范围（仅文档）

- `builds/playable-slice/README-试玩包.md`：删除“移出受控目录即可恢复原生双击”的建议；启动/验证说明拆成“证据 / 推断”；明确启动器不改权限、只把子进程数据写入包内 `userdata\`；明确 A/B/C 三条链 ≠ Explorer 双击；用户应打开 launcher 而非原 r2。
- 本文件 `_review/startup-fix/startup-fix-report.md`：新增（审计 + 未恢复项）。
- 未改：游戏 exe、启动器 exe/源码、任何安全配置、注册表、服务、计划任务、用户存档。
