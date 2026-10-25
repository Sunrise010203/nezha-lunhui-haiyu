# 001/art/**/*.import 变更归档与分类（t6，只读 git，无回滚）

- 变更文件：106（tracked 修改 97 / 未跟踪新增 9）
- 变更键总数：756；分类计数：{'auto': 573, 'intentional': 156, 'auto-format-add': 27}
- HEAD 可用作基线：t1 的 git-state.txt（13:44）中这些 tracked .import 均未修改；未跟踪新增文件无 HEAD 版本，仅记录当前字节。
- 逐文件 diff：`imports/diffs/`；逐键 old→new：`imports/keychanges.tsv`。

## 分类说明

| 分类 | 含义 | 处置 |
| --- | --- | --- |
| intentional | t3 有意导入优化（size_limit=2048 / compress=VRAM 等） | 保留，画面按本轮截图复核 |
| auto | Godot 4.6 重导入自动写入的 remap/deps/格式键 | 保留；可由 HEAD 字节单项恢复 |
| auto-format-add/remove | HEAD 旧格式缺失或新增的键（版本升级导致） | 保留；同上 |
| unclassified | 不属于以上两类 | 人工确认，本轮不回退 |

## 有意优化键的实际值（抽样统计）

- `params.compress/channel_pack` -> `0` × 7
- `params.compress/high_quality` -> `false` × 7
- `params.compress/lossy_quality` -> `0.7` × 7
- `params.compress/mode` -> `2` × 98
- `params.compress/rdo_quality_loss` -> `0.0` × 7
- `params.mipmaps/generate` -> `true` × 7
- `params.process/size_limit` -> `2048` × 23

## 恢复方式（单文件，需确认；本轮未执行任何回滚）

```bash
git show HEAD:<path> > <path>
# 或（仅在确认该文件无用户改动时）git checkout -- <单个 path>
```
