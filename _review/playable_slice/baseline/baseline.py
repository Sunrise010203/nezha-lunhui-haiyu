#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""可玩性样板轮（2026-10-22）的安全基线工具。

背景：本仓库存在大量未提交的美术与代码改动（HEAD=d26d3bc 只覆盖其中一部分），
因此 HEAD 不能当作"改动前状态"。本目录保存的是**工作区当前字节**的副本 + sha256
清单，误改后可以精确回滚；不依赖、也不改写 git 历史。

用法（在仓库根目录执行）：

    python _review/playable_slice/baseline/baseline.py check     # 只读：工作区 vs 基线
    python _review/playable_slice/baseline/baseline.py restore   # 用基线覆盖回工作区
    python _review/playable_slice/baseline/baseline.py make      # 重新采集一次基线

`restore` 会先把工作区当前版本复制到 files.before-restore/<UTC 时间戳>/ 再覆盖，
所以回滚本身也可以再回滚。`check` 是默认动作，退出码 0=一致，1=有差异，2=缺文件。
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent          # _review/playable_slice/baseline
ROOT = HERE.parents[2]                          # 仓库根目录
FILES_DIR = HERE / "files"
MANIFEST = HERE / "MANIFEST.json"
MANIFEST_TXT = HERE / "MANIFEST.txt"
GIT_STATE = HERE / "git-state.txt"

# 本轮（可玩性样板切片）计划改动的文件；改动超出这些文件时同样会记入清单，
# 因为清单是按"当前工作区"整体采集的。
TRACKED_FILES = [
    "001/scripts/player.gd",
    "001/scripts/level_base.gd",
    "001/scripts/level_1.gd",
    "001/scripts/hud.gd",
    "001/autoload/game.gd",
    "001/project.godot",
    "001/.gitignore",
    ".gitignore",
    "tools/backup.ps1",
]
# 允许"新增/可不存在"的文件：存在就一起备份（如导出配置）。
OPTIONAL_FILES = [
    "001/export_presets.cfg",
    "export_presets.cfg",
    "docs/plans/2026-10-22-playable-slice.md",
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def run_git(*args: str) -> str:
    try:
        out = subprocess.run(
            ["git", *args], cwd=ROOT, capture_output=True, text=True,
            encoding="utf-8", errors="replace", check=False,
        )
        return (out.stdout or "").strip()
    except OSError as exc:  # git 不在 PATH 时也要能跑 check
        return f"<git unavailable: {exc}>"


def head_blob(rel: str) -> str:
    """HEAD 中该路径的 blob id；未跟踪/不在 HEAD 时返回空串（仅作参考）。"""
    ret = subprocess.run(
        ["git", "rev-parse", f"HEAD:{rel}"], cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    return ret.stdout.strip() if ret.returncode == 0 else ""


def collect() -> tuple[list[dict], list[str]]:
    rows: list[dict] = []
    missing: list[str] = []
    seen: set[str] = set()
    for rel in TRACKED_FILES + OPTIONAL_FILES:
        src = ROOT / rel
        if rel in seen:
            continue
        seen.add(rel)
        if not src.is_file():
            missing.append(rel)
            continue
        st = src.stat()
        rows.append({
            "path": rel,
            "size": st.st_size,
            "mtime": datetime.fromtimestamp(st.st_mtime, timezone.utc).isoformat(),
            "sha256": sha256(src),
            "head_blob": head_blob(rel),
        })
    return rows, missing


def write_git_state() -> None:
    status = run_git("status", "--porcelain")
    lines = status.splitlines() if status else []
    modified = sum(1 for ln in lines if ln[:2].strip() in ("M", "MM", "AM"))
    deleted = sum(1 for ln in lines if ln[:2].strip() == "D")
    untracked = sum(1 for ln in lines if ln.startswith("??"))
    body = [
        "# 基线采集时刻的 git 状态（不是提交，仅记录）",
        f"sampled_at: {datetime.now(timezone.utc).isoformat()}",
        f"head: {run_git('rev-parse', 'HEAD')}",
        f"head_short: {run_git('rev-parse', '--short', 'HEAD')}",
        f"branch: {run_git('rev-parse', '--abbrev-ref', 'HEAD')}",
        f"remote_origin: {run_git('remote', 'get-url', 'origin')}",
        f"worktree_changes: {len(lines)} (modified={modified}, deleted={deleted}, untracked={untracked})",
        f"last_commit: {run_git('log', '-1', '--oneline')}",
        "",
        "## git status --porcelain（全量）",
        *lines,
        "",
    ]
    GIT_STATE.write_text("\n".join(body), encoding="utf-8")


def cmd_make() -> int:
    if FILES_DIR.exists():
        shutil.rmtree(FILES_DIR)
    FILES_DIR.mkdir(parents=True)
    rows, missing = collect()
    for row in rows:
        dst = FILES_DIR / row["path"]
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / row["path"], dst)
        if sha256(dst) != row["sha256"]:
            print(f"FAIL copy mismatch: {row['path']}", file=sys.stderr)
            return 1
    data = {
        "purpose": "playable-slice 2026-10-22 安全基线：工作区字节副本，不依赖 HEAD",
        "sampled_at": datetime.now(timezone.utc).isoformat(),
        "repo_root": str(ROOT),
        "head": run_git("rev-parse", "HEAD"),
        "branch": run_git("rev-parse", "--abbrev-ref", "HEAD"),
        "files": rows,
        "missing_at_sampling": missing,
    }
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8")
    txt = [f"# 安全基线 {data['sampled_at']}  HEAD={data['head'][:8]} "
           f"branch={data['branch']}",
           "# sha256  size  path"]
    for row in rows:
        txt.append(f"{row['sha256']}  {row['size']:>9}  {row['path']}")
    if missing:
        txt += ["", "# 采集时不存在（跳过）: " + ", ".join(missing)]
    MANIFEST_TXT.write_text("\n".join(txt) + "\n", encoding="utf-8")
    write_git_state()
    print(f"baseline written: {len(rows)} files, {len(missing)} missing")
    return 0


def cmd_check() -> int:
    if not MANIFEST.is_file():
        print("FAIL: MANIFEST.json 不存在，请先执行 make", file=sys.stderr)
        return 2
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    drift = 0
    print(f"{'state':<10}{'sha256':<12}path")
    for row in data["files"]:
        cur = ROOT / row["path"]
        base = FILES_DIR / row["path"]
        if not base.is_file():
            print(f"{'NO-BASE':<10}{'':<12}{row['path']}")
            drift += 1
            continue
        if sha256(base) != row["sha256"]:
            print(f"{'BASE-BAD':<10}{'':<12}{row['path']}")
            drift += 1
            continue
        if not cur.is_file():
            print(f"{'MISSING':<10}{'':<12}{row['path']}")
            drift += 1
            continue
        now = sha256(cur)
        if now == row["sha256"]:
            print(f"{'same':<10}{now[:10]:<12}{row['path']}")
        else:
            print(f"{'CHANGED':<10}{now[:10]:<12}{row['path']}  (baseline {row['sha256'][:10]})")
            drift += 1
    print(f"\n{len(data['files'])} files checked, {drift} changed")
    return 0 if drift == 0 else 1


def cmd_restore() -> int:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = HERE / "files.before-restore" / stamp
    restored = 0
    for row in data["files"]:
        base = FILES_DIR / row["path"]
        if not base.is_file():
            print(f"SKIP (no baseline copy): {row['path']}", file=sys.stderr)
            continue
        cur = ROOT / row["path"]
        if cur.is_file():
            dst = backup / row["path"]
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(cur, dst)
        cur.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(base, cur)
        ok = sha256(cur) == row["sha256"]
        restored += 1
        print(f"{'ok' if ok else 'MISMATCH'}  {row['path']}")
    print(f"restore done: {restored} files; previous copies in {backup}")
    return 0


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "make":
        return cmd_make()
    if cmd == "check":
        return cmd_check()
    if cmd == "restore":
        return cmd_restore()
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
