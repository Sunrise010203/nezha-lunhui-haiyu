#!/usr/bin/env python3
"""t6: 归档 001/art/**/*.import —— 当前字节 vs git HEAD 原字节，逐文件逐键区分。

只读 git（git show / git status），不回滚、不 checkout。
为何 HEAD 可作基线：t1 基线快照（_review/playable_slice/baseline/git-state.txt）记录
2026-10-22T13:44 时这 97 个 .import 均不在 git status 中，即当时等于 HEAD；
本轮（t3 的 size_limit/压缩、随后 Godot 重导入）才产生修改。

输出：
  imports/current/**            当前字节副本
  imports/head/**               tracked 文件 HEAD 原字节副本（恢复证据）
  imports/diffs/**.diff         逐文件统一 diff
  imports/manifest.tsv          逐文件摘要
  imports/keychanges.tsv        逐文件逐键：old -> new 分类
  imports/classification.md     汇总
"""
from __future__ import annotations
import difflib
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
CUR = OUT / "imports" / "current"
HEAD = OUT / "imports" / "head"
DIFF = OUT / "imports" / "diffs"

# 本轮 t3 有意的导入优化键（值由导出体积实验决定，画面已在 t3/t6 截图复核）
INTENTIONAL = {
    "params.process/size_limit": "2048",
    "params.compress/mode": "2",
    "params.compress/normal_map": "true",
    "params.compress/high_quality": "false",
    "params.compress/channel_pack": "0",
    "params.compress/lossy_quality": "0.7",
    "params.compress/rdo_quality_loss": "0.0",
    "params.mipmaps/generate": "true",
}
# Godot 4.6 重导入时自动写入/改写的元数据与格式键（非手工设置）
AUTO_PREFIX = ("remap.", "deps.", "params.uid", "params._subresources", "params.detect_3d/",
               "params.gltf/", "params.animation/", "params.meshes/", "params.nodes/",
               "params.skins/", "params.roughness/", "params.mipmaps/limit",
               "params.process/channel_remap/", "params.process/fix_alpha_border",
               "params.process/hdr_", "params.process/normal_map_invert_y",
               "params.process/premult_alpha", "params.import_script/")


def run(*args: str) -> str:
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                          errors="replace").stdout


def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def keys(text: str) -> dict[str, str]:
    d: dict[str, str] = {}
    section = ""
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1]
            continue
        if "=" in s and not s.startswith(";"):
            k, v = s.split("=", 1)
            d[f"{section}.{k.strip()}"] = v.strip()
    return d


def classify(key: str, new: str | None, old: str | None) -> str:
    if key in INTENTIONAL and new == INTENTIONAL[key] and new != old:
        return "intentional"
    if key.startswith(AUTO_PREFIX):
        return "auto"
    if old is None:
        return "auto-format-add"
    if new is None:
        return "auto-format-remove"
    return "unclassified"


def main() -> int:
    for d in (CUR, HEAD, DIFF):
        d.mkdir(parents=True, exist_ok=True)
    status = run("git", "status", "--porcelain", "--", "001/art")
    rows = []
    key_rows = []
    summary: dict[str, int] = {}
    for line in status.splitlines():
        st, path = line[:2].strip(), line[3:]
        if not path.endswith(".import"):
            continue
        cur = (ROOT / path).read_bytes() if (ROOT / path).exists() else b""
        (CUR / path).parent.mkdir(parents=True, exist_ok=True)
        (CUR / path).write_bytes(cur)
        tracked = st != "??"
        head = b""
        if tracked:
            head = run("git", "show", f"HEAD:{path}").encode("utf-8", "replace")
            (HEAD / path).parent.mkdir(parents=True, exist_ok=True)
            (HEAD / path).write_bytes(head)
        old_text = head.decode("utf-8", "replace")
        new_text = cur.decode("utf-8", "replace")
        d = "".join(difflib.unified_diff(old_text.splitlines(True), new_text.splitlines(True),
                                         fromfile=f"HEAD:{path}", tofile=f"worktree:{path}"))
        (DIFF / path).parent.mkdir(parents=True, exist_ok=True)
        (DIFF / (path + ".diff")).write_text(d, encoding="utf-8")
        hk, ck = keys(old_text), keys(new_text)
        diff_keys = []
        for k in sorted(set(hk) | set(ck)):
            if hk.get(k) != ck.get(k):
                diff_keys.append(k)
                c = classify(k, ck.get(k), hk.get(k))
                summary[c] = summary.get(c, 0) + 1
                key_rows.append((path, k, hk.get(k, "<absent>"), ck.get(k, "<absent>"), c))
        rows.append((path, st, sha(head) if tracked else "-", sha(cur), diff_keys))

    with (OUT / "imports" / "manifest.tsv").open("w", encoding="utf-8", newline="\n") as f:
        f.write("path\tgit\thead_sha256\tcur_sha256\tchanged_keys\n")
        for path, st, hs, cs, dk in rows:
            f.write(f"{path}\t{st}\t{hs}\t{cs}\t{','.join(dk)}\n")
    with (OUT / "imports" / "keychanges.tsv").open("w", encoding="utf-8", newline="\n") as f:
        f.write("path\tkey\thead_value\tcur_value\tclass\n")
        for r in key_rows:
            f.write("\t".join(r) + "\n")

    lines = ["# 001/art/**/*.import 变更归档与分类（t6，只读 git，无回滚）", "",
             f"- 变更文件：{len(rows)}（tracked 修改 {sum(1 for r in rows if r[1] != '??')} / "
             f"未跟踪新增 {sum(1 for r in rows if r[1] == '??')}）",
             f"- 变更键总数：{len(key_rows)}；分类计数：{summary}",
             "- HEAD 可用作基线：t1 的 git-state.txt（13:44）中这些 tracked .import 均未修改；"
             "未跟踪新增文件无 HEAD 版本，仅记录当前字节。",
             "- 逐文件 diff：`imports/diffs/`；逐键 old→new：`imports/keychanges.tsv`。", "",
             "## 分类说明", "",
             "| 分类 | 含义 | 处置 |", "| --- | --- | --- |",
             "| intentional | t3 有意导入优化（size_limit=2048 / compress=VRAM 等） | 保留，画面按本轮截图复核 |",
             "| auto | Godot 4.6 重导入自动写入的 remap/deps/格式键 | 保留；可由 HEAD 字节单项恢复 |",
             "| auto-format-add/remove | HEAD 旧格式缺失或新增的键（版本升级导致） | 保留；同上 |",
             "| unclassified | 不属于以上两类 | 人工确认，本轮不回退 |", ""]
    cur_sizes = [int(r[3][:8], 16) for r in rows if False]
    lines += ["## 有意优化键的实际值（抽样统计）", ""]
    intent_vals: dict[tuple[str, str], int] = {}
    for path, k, old, new, c in key_rows:
        if c == "intentional":
            intent_vals[(k, new)] = intent_vals.get((k, new), 0) + 1
    for (k, v), n in sorted(intent_vals.items()):
        lines.append(f"- `{k}` -> `{v}` × {n}")
    lines += ["", "## 恢复方式（单文件，需确认；本轮未执行任何回滚）", "",
              "```bash", "git show HEAD:<path> > <path>", "# 或（仅在确认该文件无用户改动时）git checkout -- <单个 path>", "```", ""]
    (OUT / "imports" / "classification.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"files={len(rows)} keychanges={len(key_rows)} summary={summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
